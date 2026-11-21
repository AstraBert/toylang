import gleam/float
import gleam/int
import gleam/list
import gleam/string

/// Token kind for ToyLang.
pub type TokenKind {
  /// integer
  IntNum(Int)
  /// float
  FloatNum(Float)
  /// + (sum)
  Plus
  /// - (subtraction and negative numbers)
  Minus
  /// * (for multiplications)
  Star
  /// / (for float divisions)
  Slash
  /// % (modulo)
  Percent
  /// ** (power)
  StarStar
  /// // (floor division)
  SlashSlash
  /// )
  RParen
  /// (
  LParen
  /// \\n
  Newline
  /// End of input
  EOF
}

pub fn to_string(kind: TokenKind) -> String {
  case kind {
    EOF -> "eof"
    Percent -> "%"
    Plus -> "+"
    Minus -> "-"
    LParen -> "("
    RParen -> ")"
    Newline -> "\\n"
    Slash -> "/"
    SlashSlash -> "//"
    Star -> "*"
    StarStar -> "**"
    IntNum(n) -> int.to_string(n)
    FloatNum(n) -> float.to_string(n)
  }
}

pub fn get_line(token: Token) -> Int {
  token.line
}

pub fn get_col(token: Token) -> Int {
  token.col
}

/// A ToyLang token,
/// defined by its kind
/// and position in the program
pub type Token {
  Token(kind: TokenKind, line: Int, col: Int)
}

/// Error that might occurr
/// while lexing a program
pub type LexError {
  LexError(message: String, line: Int, col: Int)
}

pub fn lex(source: String) -> Result(List(Token), LexError) {
  let chars = string.to_graphemes(source)
  scan(chars, 1, 1, [])
}

fn is_digit(s: String) -> Bool {
  case s {
    "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" -> True
    _ -> False
  }
}

pub fn scan(
  chars: List(String),
  line: Int,
  col: Int,
  tokens: List(Token),
) -> Result(List(Token), LexError) {
  case chars {
    [] -> {
      let tokens = [Token(kind: EOF, line: line, col: col), ..tokens]
      Ok(list.reverse(tokens))
    }
    [first, ..rest] -> {
      case first {
        " " | "\t" | "\r" -> {
          scan(rest, line, col + 1, tokens)
        }
        "\n" | "\r\n" -> {
          let tokens = [Token(kind: Newline, col: col, line: line), ..tokens]
          scan(rest, line + 1, 1, tokens)
        }
        "#" -> {
          let remaining =
            rest
            |> list.index_map(fn(x, i) { #(i, x) })
            |> list.drop_while(fn(x) { x.1 != "\n" })
          case remaining {
            [] -> scan(list.map(remaining, fn(x) { x.1 }), line + 1, 1, tokens)
            [first, ..] ->
              scan(list.map(remaining, fn(x) { x.1 }), line, first.0, tokens)
          }
        }
        "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" -> {
          let res = read_number(chars, line, col)
          case res {
            Error(e) -> Error(e)
            Ok(#(t, remaining, count)) -> {
              let tokens = [t, ..tokens]
              scan(remaining, line, col + count, tokens)
            }
          }
        }
        "*" -> {
          case rest {
            ["*", ..remaining] -> {
              let tokens = [
                Token(kind: StarStar, col: col, line: line),
                ..tokens
              ]
              scan(remaining, line, col + 2, tokens)
            }
            _ -> {
              let tokens = [Token(kind: Star, col: col, line: line), ..tokens]
              scan(rest, line, col + 1, tokens)
            }
          }
        }
        "/" -> {
          case rest {
            ["/", ..remaining] -> {
              let tokens = [
                Token(kind: SlashSlash, col: col, line: line),
                ..tokens
              ]
              scan(remaining, line, col + 2, tokens)
            }
            _ -> {
              let tokens = [Token(kind: Slash, col: col, line: line), ..tokens]
              scan(rest, line, col + 1, tokens)
            }
          }
        }
        "+" | "-" | "%" | "(" | ")" -> {
          let token = case first {
            "+" -> Token(kind: Plus, line: line, col: col)
            "-" -> Token(kind: Minus, line: line, col: col)
            "%" -> Token(kind: Percent, line: line, col: col)
            "(" -> Token(kind: LParen, line: line, col: col)
            _ -> Token(kind: RParen, line: line, col: col)
          }
          let tokens = [token, ..tokens]
          scan(rest, line, col + 1, tokens)
        }
        _ -> {
          Error(LexError(
            message: "Unexpected character: " <> first,
            line: line,
            col: col,
          ))
        }
      }
    }
  }
}

pub fn read_number(
  chars: List(String),
  line: Int,
  col: Int,
) -> Result(#(Token, List(String), Int), LexError) {
  let #(digits, rest) = chars |> list.split_while(is_digit)
  case rest {
    [".", ..other] -> {
      let #(other_digits, remainder) = other |> list.split_while(is_digit)
      case other_digits {
        [] ->
          Error(LexError(
            message: "Integer number cannot be followed by a dot with no digits after it",
            line: line,
            col: col + list.length(digits),
          ))
        _ -> {
          let full = string.concat(digits) <> "." <> string.concat(other_digits)
          let f = float.parse(full)
          case f {
            Ok(num) ->
              Ok(#(
                Token(kind: FloatNum(num), line: line, col: col),
                remainder,
                string.length(full),
              ))
            Error(Nil) ->
              Error(LexError(
                message: "Could not parse digits as float",
                line: line,
                col: col,
              ))
          }
        }
      }
    }

    _ -> {
      let i = int.parse(string.concat(digits))
      case i {
        Ok(num) ->
          Ok(#(
            Token(kind: IntNum(num), line: line, col: col),
            rest,
            list.length(digits),
          ))
        Error(Nil) ->
          Error(LexError(
            message: "Could not parse digits as integer",
            line: line,
            col: col,
          ))
      }
    }
  }
}
