import gleam/float
import gleam/int
import gleam/list
import gleam/result
import gleam/string

const letters: List(String) = [
  "a",
  "b",
  "c",
  "d",
  "e",
  "f",
  "g",
  "h",
  "i",
  "j",
  "k",
  "l",
  "m",
  "n",
  "o",
  "p",
  "q",
  "r",
  "s",
  "t",
  "u",
  "v",
  "w",
  "x",
  "y",
  "z",
  "A",
  "B",
  "C",
  "D",
  "E",
  "F",
  "G",
  "H",
  "I",
  "J",
  "K",
  "L",
  "M",
  "N",
  "O",
  "P",
  "Q",
  "R",
  "S",
  "T",
  "U",
  "V",
  "W",
  "X",
  "Y",
  "Z",
]

const digits: List(String) = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]

/// Token kind for ToyLang.
pub type TokenKind {
  /// `let` keyword for immutable
  /// variable assignment
  Let
  /// Identifier for a variable
  Ident(String)
  /// = (assignment operator)
  Eq
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
    Eq -> "="
    Let -> "'let'"
    Ident(x) -> "variable '" <> x <> "'"
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
  digits |> list.contains(s)
}

fn is_letter_or_underscore(s: String) -> Bool {
  letters |> list.contains(s) || s == "_"
}

pub fn is_valid_variable_name(chars: List(String)) -> Bool {
  case chars {
    [first, ..rest] -> {
      case is_letter_or_underscore(first) {
        True -> {
          rest |> list.all(fn(x) { is_digit(x) || is_letter_or_underscore(x) })
        }
        False -> False
      }
    }
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
          let #(skipped, remaining) =
            rest |> list.split_while(fn(x) { x != "\n" && x != "\r\n" })
          scan(remaining, line, col + list.length(skipped) + 1, tokens)
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
        "+" | "-" | "%" | "(" | ")" | "=" -> {
          let token = case first {
            "+" -> Token(kind: Plus, line: line, col: col)
            "-" -> Token(kind: Minus, line: line, col: col)
            "%" -> Token(kind: Percent, line: line, col: col)
            "(" -> Token(kind: LParen, line: line, col: col)
            "=" -> Token(kind: Eq, line: line, col: col)
            _ -> Token(kind: RParen, line: line, col: col)
          }
          let tokens = [token, ..tokens]
          scan(rest, line, col + 1, tokens)
        }
        _ -> {
          // variables can only start with letter
          // or underscore
          case is_letter_or_underscore(first) {
            False ->
              Error(LexError(
                message: "Unexpected character: " <> first,
                line: line,
                col: col,
              ))
            True -> {
              use #(tok, other, col_diff) <- result.try(read_word(
                chars,
                line,
                col,
              ))
              let tokens = [tok, ..tokens]
              scan(other, line, col + col_diff, tokens)
            }
          }
        }
      }
    }
  }
}

pub fn read_word(
  chars: List(String),
  line: Int,
  col: Int,
) -> Result(#(Token, List(String), Int), LexError) {
  let #(word, rest) =
    chars
    |> list.split_while(fn(x) { is_digit(x) || is_letter_or_underscore(x) })
  case is_valid_variable_name(word) {
    True -> {
      case word == ["l", "e", "t"] {
        False ->
          Ok(#(
            Token(kind: Ident(word |> string.concat), line: line, col: col),
            rest,
            list.length(word),
          ))
        True ->
          Ok(#(Token(kind: Let, line: line, col: col), rest, list.length(word)))
      }
    }
    False ->
      Error(LexError(
        message: "Invalid variable name: " <> word |> string.concat,
        line: line,
        col: col,
      ))
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
