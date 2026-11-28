import gleam/list
import gleam/result
import gleam/string
import gleeunit
import toylang/lexer.{
  EOF, FloatNum, IntNum, LParen, Minus, Newline, Percent, Plus, RParen, Slash,
  SlashSlash, Star, StarStar,
}

pub fn main() -> Nil {
  gleeunit.main()
}

// read_number tests

pub fn read_number_base_inputs_test() {
  let test_cases = [
    #(["1"], lexer.Token(kind: lexer.IntNum(1), line: 1, col: 1)),
    #(["1", ".", "2"], lexer.Token(kind: lexer.FloatNum(1.2), col: 1, line: 1)),
    #(["1", "1"], lexer.Token(kind: lexer.IntNum(11), line: 1, col: 1)),
    #(
      ["2", "1", ".", "2"],
      lexer.Token(kind: lexer.FloatNum(21.2), col: 1, line: 1),
    ),
  ]
  test_cases
  |> list.each(fn(x) {
    let res = lexer.read_number(x.0, 1, 1)
    case res {
      Error(e) -> {
        echo e.message
        panic
      }
      Ok(#(t, _, _)) -> {
        assert x.1 == t
      }
    }
  })
}

pub fn read_number_errors_on_empty_digits_test() {
  let res = lexer.read_number([], 1, 1)
  assert result.unwrap_error(
      res,
      lexer.LexError(message: "expecting an error", line: 1, col: 1),
    ).message
    == "Could not parse digits as integer"
}

pub fn read_number_errors_on_point_after_integer_test() {
  let res = lexer.read_number(["5", "3", "."], 1, 1)
  let err =
    result.unwrap_error(
      res,
      lexer.LexError(message: "expecting an error", line: 1, col: 1),
    )
  assert err.message
    == "Integer number cannot be followed by a dot with no digits after it"
  assert err.line == 1
  assert err.col == 3
}

pub fn read_number_reads_trailing_zeros_test() {
  let res = lexer.read_number(["0", "0", "7"], 1, 1)
  case res {
    Error(err) -> {
      echo err.message
      panic
    }
    Ok(#(t, _, c)) -> {
      assert t == lexer.Token(kind: lexer.IntNum(7), line: 1, col: 1)
      assert c == 3
    }
  }
}

pub fn read_number_returns_correct_rest_on_int_test() {
  let res = lexer.read_number(["7", "4", "1", "+", "5", "1", "8"], 1, 1)
  case res {
    Error(err) -> {
      echo err.message
      panic
    }
    Ok(#(t, rest, c)) -> {
      assert t == lexer.Token(kind: lexer.IntNum(741), line: 1, col: 1)
      assert c == 3
      assert rest == ["+", "5", "1", "8"]
    }
  }
}

pub fn read_number_returns_correct_rest_on_float_test() {
  let res = lexer.read_number(["7", ".", "1", "3", "*", "5", ".", "8"], 1, 1)
  case res {
    Error(err) -> {
      echo err.message
      panic
    }
    Ok(#(t, rest, c)) -> {
      assert t == lexer.Token(kind: lexer.FloatNum(7.13), line: 1, col: 1)
      assert c == 4
      assert rest == ["*", "5", ".", "8"]
    }
  }
}

// ---------- is_valid_variable_name ----------

pub fn valid_variable_names_test() {
  let cases = [
    "_hello" |> string.to_graphemes,
    "s_1omething3" |> string.to_graphemes,
    "onlyletters" |> string.to_graphemes,
    ["_"],
    ["_", "_"],
    "_123" |> string.to_graphemes,
  ]

  assert cases |> list.all(lexer.is_valid_variable_name)
}

pub fn invalid_variable_names_test() {
  let cases = [
    "1_hello" |> string.to_graphemes,
    "-something" |> string.to_graphemes,
    "with space" |> string.to_graphemes,
    ["#"],
    ["玩", "具"],
    "_12\t3" |> string.to_graphemes,
    "with\rp" |> string.to_graphemes,
  ]

  assert cases |> list.all(fn(x) { !lexer.is_valid_variable_name(x) })
}

// ---------- helpers ----------

// Lex and keep only the token kinds (ignores line/col).
fn kinds(source: String) -> List(lexer.TokenKind) {
  let assert Ok(tokens) = lexer.lex(source)
  list.map(tokens, fn(token) { token.kind })
}

// Lex and keep only the (line, col) of every token.
fn positions(source: String) -> List(#(Int, Int)) {
  let assert Ok(tokens) = lexer.lex(source)
  list.map(tokens, fn(token) { #(token.line, token.col) })
}

// Lex something that must fail, and return where the error is.
fn error_position(source: String) -> #(Int, Int) {
  let assert Error(error) = lexer.lex(source)
  #(error.line, error.col)
}

// ---------- basic tokens ----------

pub fn empty_input_test() {
  assert kinds("") == [EOF]
}

pub fn single_int_test() {
  assert kinds("1") == [IntNum(1), EOF]
}

pub fn addition_test() {
  assert kinds("1+2") == [IntNum(1), Plus, IntNum(2), EOF]
}

pub fn all_single_char_tokens_test() {
  assert kinds("+ - * / % ( )")
    == [Plus, Minus, Star, Slash, Percent, LParen, RParen, EOF]
}

// ---------- two-character operators ----------

pub fn power_test() {
  assert kinds("2**3") == [IntNum(2), StarStar, IntNum(3), EOF]
}

pub fn floor_division_test() {
  assert kinds("7//2") == [IntNum(7), SlashSlash, IntNum(2), EOF]
}

pub fn longest_match_test() {
  assert kinds("* ** / //") == [Star, StarStar, Slash, SlashSlash, EOF]
}

// ---------- numbers ----------

pub fn float_test() {
  assert kinds("3.14") == [FloatNum(3.14), EOF]
}

pub fn leading_zeros_test() {
  assert kinds("007") == [IntNum(7), EOF]
}

pub fn multi_digit_numbers_test() {
  assert kinds("12 3.5") == [IntNum(12), FloatNum(3.5), EOF]
}

pub fn whole_expression_test() {
  assert kinds("1 + 2.5 * (3 ** 2)")
    == [
      IntNum(1),
      Plus,
      FloatNum(2.5),
      Star,
      LParen,
      IntNum(3),
      StarStar,
      IntNum(2),
      RParen,
      EOF,
    ]
}

// ---------- whitespace, newlines, comments ----------

pub fn spaces_and_tabs_are_ignored_test() {
  assert kinds("1 \t +   2") == [IntNum(1), Plus, IntNum(2), EOF]
}

pub fn newline_test() {
  assert kinds("1\n\n2") == [IntNum(1), Newline, Newline, IntNum(2), EOF]
}

pub fn windows_line_endings_test() {
  assert kinds("1\r\n2") == [IntNum(1), Newline, IntNum(2), EOF]
}

pub fn r_and_tab_test() {
  assert kinds("1\r\t2") == [IntNum(1), IntNum(2), EOF]
}

pub fn only_comment_test() {
  assert kinds("# only comment") == [EOF]
}

pub fn comment_keeps_newline_test() {
  assert kinds("1 # hi\n2") == [IntNum(1), Newline, IntNum(2), EOF]
}

pub fn comment_before_unix_line_ending_test() {
  // 1=col 1, newline=col 7, then the 2 on line 2 (not line 3)
  assert positions("1 # hi\n2") == [#(1, 1), #(1, 7), #(2, 1), #(2, 2)]
}

pub fn comment_before_windows_line_ending_test() {
  // "\r\n" is one grapheme and must also end the comment
  assert kinds("1 # hi\r\n2") == [IntNum(1), Newline, IntNum(2), EOF]
}

pub fn comment_before_windows_line_ending_positions_test() {
  assert positions("1 # hi\r\n2") == [#(1, 1), #(1, 7), #(2, 1), #(2, 2)]
}

pub fn comment_at_end_of_input_test() {
  // EOF stays on the same line, right after the comment
  assert positions("1 # hi") == [#(1, 1), #(1, 7)]
}

// ---------- positions ----------

pub fn columns_on_one_line_test() {
  // "12 + 3": 12 starts at col 1, + at col 4, 3 at col 6, EOF at col 7
  assert positions("12 + 3") == [#(1, 1), #(1, 4), #(1, 6), #(1, 7)]
}

pub fn line_numbers_test() {
  // "+\n-": + at (1,1), newline at (1,2), - at (2,1), EOF at (2,2)
  assert positions("+\n-") == [#(1, 1), #(1, 2), #(2, 1), #(2, 2)]
}

// ---------- errors ----------

pub fn unknown_character_test() {
  assert error_position("1 @ 2") == #(1, 3)
}

pub fn unknown_character_on_second_line_test() {
  assert error_position("1\n 2 $") == #(2, 4)
}

pub fn trailing_dot_is_error_test() {
  // "5." : the error points at the dot
  assert error_position("5.") == #(1, 2)
}

pub fn trailing_dot_before_operator_test() {
  assert error_position("5.+3") == #(1, 2)
}

pub fn leading_dot_is_error_test() {
  assert error_position(".5") == #(1, 1)
}

pub fn second_dot_is_error_test() {
  // "1.2.3": 1.2 is fine, the second dot is unexpected at col 4
  assert error_position("1.2.3") == #(1, 4)
}
