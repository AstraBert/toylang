import gleam/dict
import gleam/result
import toylang/parser
import toylang/types

pub type CheckerError {
  AlreadyDefined(String, Int, Int)
  UnboundVariable(String, Int, Int)
}

pub type Env =
  dict.Dict(String, types.ToyType)

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

pub fn check_expr(
  expr: parser.Expr,
  env: Env,
) -> Result(types.ToyType, CheckerError) {
  case expr {
    parser.IntLit(_) -> Ok(types.IntType)
    parser.FloatLit(_) -> Ok(types.FloatType)
    parser.Neg(e) -> check_expr(e, env)
    parser.BinOp(op, l, r) -> {
      use lt <- result.try(check_expr(l, env))
      use rt <- result.try(check_expr(r, env))
      Ok(work_type(op, lt, rt))
    }
    parser.Var(name, line, col) -> {
      case dict.get(env, name) {
        Ok(t) -> Ok(t)
        Error(_) ->
          Error(UnboundVariable("Unbound variable " <> name, line, col))
      }
    }
  }
}

pub fn check_stmt(stmt: parser.Stmt, env: Env) -> Result(Env, CheckerError) {
  case stmt {
    parser.ExprStmt(e) -> {
      use _ <- result.try(check_expr(e, env))
      Ok(env)
    }
    parser.Let(name, e, line, col) -> {
      case dict.get(env, name) {
        Ok(_) ->
          Error(AlreadyDefined(
            "Variable "
              <> name
              <> " has already been defined (variables are immutable, re-assignment is illegal)",
            line,
            col,
          ))
        Error(_) -> {
          use t <- result.try(check_expr(e, env))
          let env = env |> dict.insert(name, t)
          Ok(env)
        }
      }
    }
  }
}

pub fn check_program(
  stmts: List(parser.Stmt),
  env: Env,
) -> Result(Nil, CheckerError) {
  case stmts {
    [] -> Ok(Nil)
    [first, ..rest] -> {
      use env <- result.try(check_stmt(first, env))
      check_program(rest, env)
    }
  }
}
