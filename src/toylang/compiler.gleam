import gleam/dict
import gleam/float
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import toylang/parser
import toylang/types

/// Variable Name -> (Temporary Name, Type)
pub type VarEnv =
  dict.Dict(String, #(String, types.ToyType))

pub fn to_qbe_type(ct: types.ToyType) -> String {
  case ct {
    types.IntType -> "l"
    types.FloatType -> "d"
  }
}

pub type CompileError {
  CompileError(message: String)
}

pub fn work_type(
  op: parser.BinaryOp,
  left_type: types.ToyType,
  right_type: types.ToyType,
) -> types.ToyType {
  case op {
    parser.Div -> types.FloatType
    _ -> {
      case left_type, right_type {
        types.IntType, types.IntType -> types.IntType
        _, _ -> types.FloatType
      }
    }
  }
}

pub fn convert(
  t: String,
  from_type: types.ToyType,
  to_type: types.ToyType,
  n: Int,
) -> #(List(String), String, Int) {
  case from_type, to_type {
    types.IntType, types.IntType -> #([], t, n)
    types.FloatType, types.FloatType -> #([], t, n)
    _, _ -> {
      let n1 = n + 1
      let r = "%t" <> int.to_string(n1)
      // Conversion can only happen one way (Int -> Float),
      // hence the default use of 'd' here
      let line = r <> " =d sltof " <> t
      #([line], r, n1)
    }
  }
}

pub fn emit_op(
  op: parser.BinaryOp,
  wtype: types.ToyType,
  result: String,
  a: String,
  b: String,
) -> String {
  let q = to_qbe_type(wtype)
  case op {
    parser.Add -> {
      result <> " =" <> q <> " add " <> a <> ", " <> b
    }
    parser.Mul -> {
      result <> " =" <> q <> " mul " <> a <> ", " <> b
    }
    parser.Sub -> {
      result <> " =" <> q <> " sub " <> a <> ", " <> b
    }
    parser.Div -> {
      result <> " =d call $tl_div(d " <> a <> ", d " <> b <> ")"
    }
    parser.FloorDiv -> {
      let floor_div_tp = case wtype {
        types.IntType -> "int"
        types.FloatType -> "float"
      }
      result
      <> " ="
      <> q
      <> " call $tl_floordiv_"
      <> floor_div_tp
      <> "("
      <> q
      <> " "
      <> a
      <> ", "
      <> q
      <> " "
      <> b
      <> ")"
    }
    parser.Mod -> {
      let mod_tp = case wtype {
        types.IntType -> "int"
        types.FloatType -> "float"
      }
      result
      <> " ="
      <> q
      <> " call $tl_mod_"
      <> mod_tp
      <> "("
      <> q
      <> " "
      <> a
      <> ", "
      <> q
      <> " "
      <> b
      <> ")"
    }
    parser.Pow -> {
      let pow_tp = case wtype {
        types.IntType -> "int"
        types.FloatType -> "float"
      }
      result
      <> " ="
      <> q
      <> " call $tl_pow_"
      <> pow_tp
      <> "("
      <> q
      <> " "
      <> a
      <> ", "
      <> q
      <> " "
      <> b
      <> ")"
    }
  }
}

pub fn compile_expr(
  expr: parser.Expr,
  n: Int,
  var_env: VarEnv,
) -> Result(#(List(String), String, types.ToyType, Int), CompileError) {
  case expr {
    parser.Var(name, line, col) -> {
      case dict.get(var_env, name) {
        Ok(#(temp, tp)) -> {
          Ok(#([], temp, tp, n))
        }
        Error(_) ->
          Error(CompileError(
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
    parser.IntLit(k) -> {
      let n1 = n + 1
      let t = "%t" <> int.to_string(n1)
      let lines = [t <> " =l copy " <> int.to_string(k)]
      Ok(#(lines, t, types.IntType, n1))
    }
    parser.FloatLit(k) -> {
      let n1 = n + 1
      let t = "%t" <> int.to_string(n1)
      let lines = [t <> " =d copy d_" <> float.to_string(k)]
      Ok(#(lines, t, types.FloatType, n1))
    }
    parser.Neg(inner) -> {
      use #(lines, t, ty, n1) <- result.try(compile_expr(inner, n, var_env))
      let n2 = n1 + 1
      let t1 = "%t" <> int.to_string(n2)
      let line = t1 <> " =" <> to_qbe_type(ty) <> " neg " <> t
      Ok(#(lines |> list.append([line]), t1, ty, n2))
    }
    parser.BinOp(op, left, right) -> {
      use #(l_lines, lt, lty, n1) <- result.try(compile_expr(left, n, var_env))
      use #(r_lines, rt, rty, n2) <- result.try(compile_expr(right, n1, var_env))
      let wt = work_type(op, lty, rty)
      let #(l_conv, lt2, n3) = convert(lt, lty, wt, n2)
      let #(r_conv, rt2, n4) = convert(rt, rty, wt, n3)
      let n5 = n4 + 1
      let r = "%t" <> int.to_string(n5)
      let op_line = emit_op(op, wt, r, lt2, rt2)
      let lines =
        l_lines
        |> list.append(r_lines)
        |> list.append(l_conv)
        |> list.append(r_conv)
        |> list.append([op_line])
      Ok(#(lines, r, wt, n5))
    }
  }
}

fn compile_program_to_lines(
  exprs: List(parser.Stmt),
  lines: List(String),
  n: Int,
  var_env: VarEnv,
) -> Result(List(String), CompileError) {
  case exprs {
    [] -> {
      Ok(lines |> list.append(["ret 0", "}", "\n"]))
    }
    [first, ..rest] -> {
      case first {
        parser.ExprStmt(e) -> {
          use #(expr_lines, t, ty, n1) <- result.try(compile_expr(e, n, var_env))
          let print_tp = case ty {
            types.IntType -> "int"
            types.FloatType -> "float"
          }
          let print_line =
            "call $tl_print_"
            <> print_tp
            <> "("
            <> to_qbe_type(ty)
            <> " "
            <> t
            <> ")"
          let lines =
            lines |> list.append(expr_lines) |> list.append([print_line])
          compile_program_to_lines(rest, lines, n1, var_env)
        }
        parser.Let(name, e, _, _) -> {
          // no print line for variable declarations
          use #(expr_lines, t, ty, n1) <- result.try(compile_expr(e, n, var_env))
          let lines = lines |> list.append(expr_lines)
          let var_env = dict.insert(var_env, name, #(t, ty))
          compile_program_to_lines(rest, lines, n1, var_env)
        }
      }
    }
  }
}

pub fn compile_program(
  stmts: List(parser.Stmt),
) -> Result(String, CompileError) {
  let var_env: VarEnv = dict.new()
  use lines <- result.try(compile_program_to_lines(
    stmts,
    ["export function w $main() {", "@start"],
    0,
    var_env,
  ))
  Ok(lines |> string.join("\n"))
}
