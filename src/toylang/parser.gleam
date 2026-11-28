import gleam/list
import gleam/result
import toylang/lexer

/// Supported binary operation
/// for ToyLang
pub type BinaryOp {
  Add
  Sub
  Mul
  Div
  FloorDiv
  Pow
  Mod
}

/// AST for ToyLang
pub type Expr {
  /// Integer Literal
  IntLit(Int)
  /// Float Literal
  FloatLit(Float)
  /// Negated expression (uses unary '-')
  Neg(Expr)
  /// Binary operation
  BinOp(BinaryOp, Expr, Expr)
  /// Variable declaration (name, line, col)
  Var(String, Int, Int)
}

pub type Stmt {
  /// An expression statement
  ExprStmt(Expr)
  /// A variable assignment statement (name, expression, line, column)
  Let(String, Expr, Int, Int)
}

/// Parsing error
pub type ParseError {
  Parsing(message: String, line: Int, col: Int)
  Empty
}

pub fn parse_power(
  tokens: List(lexer.Token),
) -> Result(#(Expr, List(lexer.Token)), ParseError) {
  use #(base, rest) <- result.try(parse_atom(tokens))
  case rest {
    [lexer.Token(kind: lexer.StarStar, line: _, col: _), ..other] -> {
      use #(exponent, other_rest) <- result.try(parse_unary(other))
      Ok(#(BinOp(Pow, base, exponent), other_rest))
    }
    _ -> Ok(#(base, rest))
  }
}

pub fn parse_unary(
  tokens: List(lexer.Token),
) -> Result(#(Expr, List(lexer.Token)), ParseError) {
  case tokens {
    [lexer.Token(kind: lexer.Minus, col: _, line: _), ..rest] -> {
      use #(operand, other) <- result.try(parse_unary(rest))
      Ok(#(Neg(operand), other))
    }
    _ -> parse_power(tokens)
  }
}

pub fn parse_atom(
  tokens: List(lexer.Token),
) -> Result(#(Expr, List(lexer.Token)), ParseError) {
  case tokens {
    [] -> Error(Empty)
    [first, ..rest] -> {
      case first.kind {
        lexer.Ident(n) -> Ok(#(Var(n, first.line, first.col), rest))
        lexer.IntNum(n) -> Ok(#(IntLit(n), rest))
        lexer.FloatNum(n) -> Ok(#(FloatLit(n), rest))
        lexer.LParen -> {
          use #(inner, rest) <- result.try(parse_expr(rest))
          case rest {
            [lexer.Token(kind: lexer.RParen, line: _, col: _), ..other_rest] ->
              Ok(#(inner, other_rest))
            _ -> {
              let first = rest |> list.first
              case first {
                Ok(l) ->
                  Error(Parsing(
                    message: "Expected ')'",
                    line: l.line,
                    col: l.col,
                  ))
                Error(Nil) -> Error(Empty)
              }
            }
          }
        }
        _ ->
          Error(Parsing(
            message: "Expected a number or a '(', found "
              <> lexer.to_string(first.kind),
            col: first.col,
            line: first.line,
          ))
      }
    }
  }
}

fn expect_ident(
  tokens: List(lexer.Token),
) -> Result(#(String, Int, Int, List(lexer.Token)), ParseError) {
  case tokens {
    [lexer.Token(kind: lexer.Ident(x), line: l, col: c), ..rest] -> {
      Ok(#(x, l, c, rest))
    }
    [other, ..] ->
      Error(Parsing(
        message: "Unexpected token after 'let' (expecting variable declaration): "
          <> other.kind |> lexer.to_string,
        col: other.col,
        line: other.line,
      ))
    [] -> Error(Empty)
  }
}

fn expect_eq(
  tokens: List(lexer.Token),
) -> Result(List(lexer.Token), ParseError) {
  case tokens {
    [lexer.Token(kind: lexer.Eq, line: _, col: _), ..rest] -> {
      Ok(rest)
    }
    [other, ..] ->
      Error(Parsing(
        message: "Unexpected token after 'let' and variable declaration (expecting '='): "
          <> other.kind |> lexer.to_string,
        col: other.col,
        line: other.line,
      ))
    [] -> Error(Empty)
  }
}

pub fn parse_stmt(
  tokens: List(lexer.Token),
) -> Result(#(Stmt, List(lexer.Token)), ParseError) {
  case tokens {
    [] -> Error(Empty)
    [first, ..rest] -> {
      case first.kind {
        lexer.Let -> {
          use #(name, line, col, other) <- result.try(expect_ident(rest))
          use more_rest <- result.try(expect_eq(other))
          use #(expr, final_rest) <- result.try(parse_expr(more_rest))
          Ok(#(Let(name, expr, line, col), final_rest))
        }
        _ -> {
          use #(expr, more) <- result.try(parse_expr(tokens))
          Ok(#(ExprStmt(expr), more))
        }
      }
    }
  }
}

pub fn parse_term(
  tokens: List(lexer.Token),
) -> Result(#(Expr, List(lexer.Token)), ParseError) {
  use #(left, rest) <- result.try(parse_unary(tokens))
  term_loop(left, rest)
}

pub fn term_loop(
  left: Expr,
  tokens: List(lexer.Token),
) -> Result(#(Expr, List(lexer.Token)), ParseError) {
  case tokens {
    [lexer.Token(kind: lexer.Star, line: _, col: _), ..rest] -> {
      let op = Mul
      use #(right, other_rest) <- result.try(parse_unary(rest))
      term_loop(BinOp(op, left, right), other_rest)
    }
    [lexer.Token(kind: lexer.Slash, line: _, col: _), ..rest] -> {
      let op = Div
      use #(right, other_rest) <- result.try(parse_unary(rest))
      term_loop(BinOp(op, left, right), other_rest)
    }
    [lexer.Token(kind: lexer.SlashSlash, line: _, col: _), ..rest] -> {
      let op = FloorDiv
      use #(right, other_rest) <- result.try(parse_unary(rest))
      term_loop(BinOp(op, left, right), other_rest)
    }
    [lexer.Token(kind: lexer.Percent, line: _, col: _), ..rest] -> {
      let op = Mod
      use #(right, other_rest) <- result.try(parse_unary(rest))
      term_loop(BinOp(op, left, right), other_rest)
      // the new tree becomes now left
    }
    _ -> Ok(#(left, tokens))
    // nothing more to do at this level
  }
}

pub fn parse_expr(
  tokens: List(lexer.Token),
) -> Result(#(Expr, List(lexer.Token)), ParseError) {
  use #(left, rest) <- result.try(parse_term(tokens))
  expr_loop(left, rest)
}

pub fn expr_loop(
  left: Expr,
  tokens: List(lexer.Token),
) -> Result(#(Expr, List(lexer.Token)), ParseError) {
  case tokens {
    [lexer.Token(kind: lexer.Plus, line: _, col: _), ..rest] -> {
      let op = Add
      use #(right, other_rest) <- result.try(parse_term(rest))
      expr_loop(BinOp(op, left, right), other_rest)
    }
    [lexer.Token(kind: lexer.Minus, line: _, col: _), ..rest] -> {
      let op = Sub
      use #(right, other_rest) <- result.try(parse_term(rest))
      expr_loop(BinOp(op, left, right), other_rest)
    }
    _ -> Ok(#(left, tokens))
    // nothing more to do at this level
  }
}

pub fn parse_program(
  tokens: List(lexer.Token),
  stmts: List(Stmt),
) -> Result(List(Stmt), ParseError) {
  case tokens {
    [lexer.Token(kind: lexer.EOF, col: _, line: _), ..] ->
      Ok(list.reverse(stmts))
    [lexer.Token(kind: lexer.Newline, col: _, line: _), ..rest] ->
      parse_program(rest, stmts)
    _ -> {
      use #(stmt, rest) <- result.try(parse_stmt(tokens))
      case rest {
        [lexer.Token(kind: lexer.Newline, col: _, line: _), ..]
        | [lexer.Token(kind: lexer.EOF, col: _, line: _), ..] -> {
          let stmts = [stmt, ..stmts]
          parse_program(rest, stmts)
        }
        _ -> {
          let first = rest |> list.first
          case first {
            Ok(l) ->
              Error(Parsing(
                message: "Unexpected " <> lexer.to_string(l.kind),
                line: l.line,
                col: l.col,
              ))
            Error(Nil) -> Error(Empty)
          }
        }
      }
    }
  }
}
