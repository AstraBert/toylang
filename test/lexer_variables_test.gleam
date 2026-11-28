import gleam/list
import toylang/lexer.{EOF, Eq, Ident, IntNum, Let, Newline, Plus, Star, StarStar}

// ---------- helpers (the only place that knows your function names) ----------

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

// ---------- the basic statement ----------

pub fn let_statement_test() {
  assert kinds("let x = 5") == [Let, Ident("x"), Eq, IntNum(5), EOF]
}

pub fn let_without_spaces_around_equals_test() {
  assert kinds("let x=5") == [Let, Ident("x"), Eq, IntNum(5), EOF]
}

pub fn let_on_two_lines_test() {
  assert kinds("let x = 5\nx")
    == [Let, Ident("x"), Eq, IntNum(5), Newline, Ident("x"), EOF]
}

pub fn lone_equals_test() {
  assert kinds("=") == [Eq, EOF]
}

// ---------- keywords ----------

pub fn let_alone_test() {
  assert kinds("let") == [Let, EOF]
}

pub fn keyword_prefix_is_an_identifier_test() {
  assert kinds("letter") == [Ident("letter"), EOF]
}

pub fn keyword_with_extra_letter_test() {
  assert kinds("lets") == [Ident("lets"), EOF]
}

pub fn fn_prefix_is_an_identifier_test() {
  assert kinds("fnord") == [Ident("fnord"), EOF]
}

pub fn keyword_with_underscore_is_an_identifier_test() {
  assert kinds("fn_") == [Ident("fn_"), EOF]
}

pub fn keywords_are_case_sensitive_test() {
  assert kinds("Let FN") == [Ident("Let"), Ident("FN"), EOF]
}

pub fn type_names_are_plain_identifiers_test() {
  assert kinds("Int Float") == [Ident("Int"), Ident("Float"), EOF]
}

// ---------- what a name can look like ----------

pub fn single_letter_test() {
  assert kinds("x") == [Ident("x"), EOF]
}

pub fn name_with_digits_test() {
  assert kinds("x1") == [Ident("x1"), EOF]
}

pub fn name_with_underscores_test() {
  assert kinds("my_var_2") == [Ident("my_var_2"), EOF]
}

pub fn leading_underscore_test() {
  assert kinds("_x") == [Ident("_x"), EOF]
}

pub fn lone_underscore_test() {
  assert kinds("_") == [Ident("_"), EOF]
}

pub fn letters_digits_letters_are_one_name_test() {
  assert kinds("x2y") == [Ident("x2y"), EOF]
}

pub fn uppercase_letters_test() {
  assert kinds("Total") == [Ident("Total"), EOF]
}

pub fn name_cannot_start_with_a_digit_test() {
  // lexes as a number followed by a name; the parser will reject it later
  assert kinds("1x") == [IntNum(1), Ident("x"), EOF]
}

// ---------- names next to operators ----------

pub fn names_in_an_expression_test() {
  assert kinds("x + y2 * 3")
    == [Ident("x"), Plus, Ident("y2"), Star, IntNum(3), EOF]
}

pub fn names_without_spaces_test() {
  assert kinds("x**2") == [Ident("x"), StarStar, IntNum(2), EOF]
}

// ---------- comments and v0 behaviour still work ----------

pub fn comment_after_let_test() {
  assert kinds("let x = 5 # five") == [Let, Ident("x"), Eq, IntNum(5), EOF]
}

pub fn names_inside_comments_are_ignored_test() {
  assert kinds("# let x = 5") == [EOF]
}

pub fn v0_expression_still_lexes_test() {
  assert kinds("1 + 2") == [IntNum(1), Plus, IntNum(2), EOF]
}

// ---------- positions ----------

pub fn columns_in_a_let_test() {
  // let=1, x=5, "="=7, 5=9, EOF=10
  assert positions("let x = 5")
    == [#(1, 1), #(1, 5), #(1, 7), #(1, 9), #(1, 10)]
}

pub fn long_names_advance_the_column_test() {
  // abc=1, +=5, d=7, EOF=8
  assert positions("abc + d") == [#(1, 1), #(1, 5), #(1, 7), #(1, 8)]
}

pub fn name_at_the_very_end_test() {
  assert positions("abc") == [#(1, 1), #(1, 4)]
}

pub fn positions_on_two_lines_test() {
  assert positions("let a = 1\nlet b = 2")
    == [
      #(1, 1),
      #(1, 5),
      #(1, 7),
      #(1, 9),
      #(1, 10),
      #(2, 1),
      #(2, 5),
      #(2, 7),
      #(2, 9),
      #(2, 10),
    ]
}

// ---------- errors ----------

pub fn unknown_character_after_a_name_test() {
  assert error_position("x $ y") == #(1, 3)
}

pub fn unknown_character_in_a_let_test() {
  assert error_position("let x = @") == #(1, 9)
}

pub fn non_ascii_letter_is_rejected_test() {
  // names are ASCII only, so the e with an accent at col 5 is unexpected
  assert error_position("let é = 1") == #(1, 5)
}

pub fn dot_after_a_name_is_an_error_test() {
  // "x.5": the name is fine, the dot at col 2 is unexpected
  assert error_position("x.5") == #(1, 2)
}
