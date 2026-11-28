import gleam/dict
import gleam/float
import gleam/int
import gleam/list
import gleam/result
import toylang/parser

/// Value of a ToyLang expression,
/// determined at runtime
pub type RunValue {
  IntValue(Int)
  FloatValue(Float)
}

pub type Env =
  dict.Dict(String, RunValue)

pub type EvalError {
  EvalError(message: String)
}

pub fn to_string(val: RunValue) -> String {
  case val {
    IntValue(v) -> int.to_string(v)
    FloatValue(f) -> float.to_string(f)
  }
}

fn to_float(val: RunValue) -> Float {
  case val {
    IntValue(v) -> int.to_float(v)
    FloatValue(f) -> f
  }
}

fn cast_to_float(val: RunValue) -> RunValue {
  case val {
    IntValue(v) -> FloatValue(int.to_float(v))
    _ -> val
  }
}

fn arithmetic(
  l: RunValue,
  r: RunValue,
  int_fn: fn(Int, Int) -> Result(Int, EvalError),
  float_fn: fn(Float, Float) -> Result(Float, EvalError),
) -> Result(RunValue, EvalError) {
  case l, r {
    IntValue(a), IntValue(b) -> {
      use num <- result.try(int_fn(a, b))
      Ok(IntValue(num))
    }
    _, _ -> {
      let fl = to_float(l)
      let fr = to_float(r)
      use num <- result.try(float_fn(fl, fr))
      Ok(FloatValue(num))
    }
  }
}

// assumes exp >= 0
fn integer_power(base: Int, exp: Int) -> Int {
  case exp == 0 {
    True -> 1
    False -> base * integer_power(base, exp - 1)
  }
}

pub fn apply(
  op: parser.BinaryOp,
  left: RunValue,
  right: RunValue,
) -> Result(RunValue, EvalError) {
  case op {
    parser.Add ->
      arithmetic(left, right, fn(a, b) { Ok(a + b) }, fn(a, b) {
        Ok(float.add(a, b))
      })
    parser.Sub ->
      arithmetic(left, right, fn(a, b) { Ok(a - b) }, fn(a, b) {
        Ok(float.subtract(a, b))
      })
    parser.Mul ->
      arithmetic(left, right, fn(a, b) { Ok(a * b) }, fn(a, b) {
        Ok(float.multiply(a, b))
      })
    parser.Div ->
      arithmetic(
        cast_to_float(left),
        cast_to_float(right),
        fn(a, b) {
          int.divide(a, b)
          |> result.replace_error(EvalError("Division by zero error"))
        },
        fn(a, b) {
          float.divide(a, b)
          |> result.replace_error(EvalError("Division by zero error"))
        },
      )
    parser.FloorDiv ->
      arithmetic(
        left,
        right,
        fn(a, b) {
          int.floor_divide(a, b)
          |> result.replace_error(EvalError("Floor division by zero error"))
        },
        fn(a, b) {
          use res <- result.try(
            float.divide(a, b)
            |> result.replace_error(EvalError("Floor division by zero error")),
          )
          Ok(float.floor(res))
        },
      )
    parser.Mod ->
      arithmetic(
        left,
        right,
        fn(a, b) {
          int.modulo(a, b)
          |> result.replace_error(EvalError("Modulo by zero error"))
        },
        fn(a, b) {
          float.modulo(a, b)
          |> result.replace_error(EvalError("Modulo by zero error"))
        },
      )
    parser.Pow -> {
      case left, right {
        IntValue(base), IntValue(exp) -> {
          case exp >= 0 {
            True -> Ok(IntValue(integer_power(base, exp)))
            False -> {
              use res <- result.try(
                float.power(int.to_float(base), int.to_float(exp))
                |> result.replace_error(EvalError(
                  "Attempted to use negative exponent with base 0",
                )),
              )
              Ok(FloatValue(res))
            }
          }
        }
        _, _ -> {
          let fl = to_float(left)
          let fr = to_float(right)
          use res <- result.try(
            float.power(fl, fr)
            |> result.replace_error(EvalError(
              "Attempted to use negative exponent with base 0",
            )),
          )
          Ok(FloatValue(res))
        }
      }
    }
  }
}

pub fn eval(expr: parser.Expr, env: Env) -> Result(RunValue, EvalError) {
  case expr {
    parser.Var(name, line, col) -> {
      case dict.get(env, name) {
        Ok(v) -> Ok(v)
        Error(_) ->
          Error(EvalError(
            "Undefined variable "
            <> name
            <> " at line "
            <> int.to_string(line)
            <> " (col "
            <> int.to_string(col)
            <> ")",
          ))
      }
    }
    parser.IntLit(i) -> Ok(IntValue(i))
    parser.FloatLit(f) -> Ok(FloatValue(f))
    parser.Neg(inner) -> {
      use v <- result.try(eval(inner, env))
      case v {
        IntValue(n) -> Ok(IntValue(-n))
        FloatValue(f) -> Ok(FloatValue(float.negate(f)))
      }
    }
    parser.BinOp(op, left, right) -> {
      use l <- result.try(eval(left, env))
      use r <- result.try(eval(right, env))
      apply(op, l, r)
    }
  }
}

pub fn eval_program(
  exprs: List(parser.Stmt),
  env: Env,
  values: List(RunValue),
) -> Result(List(RunValue), EvalError) {
  case exprs {
    [] -> Ok(list.reverse(values))
    [first, ..rest] -> {
      case first {
        parser.ExprStmt(e) -> {
          use val <- result.try(eval(e, env))
          let values = [val, ..values]
          eval_program(rest, env, values)
        }
        parser.Let(name, e, _, _) -> {
          use val <- result.try(eval(e, env))
          let env = dict.insert(env, name, val)
          eval_program(rest, env, values)
        }
      }
    }
  }
}
