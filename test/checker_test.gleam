import gleam/dict
import gleam/string
import toylang/checker
import toylang/lexer
import toylang/parser

// ---------- helpers (the only place that knows your function names) ----------

// Lex + parse + check a whole program.
fn check(source: String) -> Result(Nil, checker.CheckerError) {
  let assert Ok(tokens) = lexer.lex(source)
  let assert Ok(stmts) = parser.parse_program(tokens, [])
  let env: checker.Env = dict.new()
  checker.check_program(stmts, env)
}

fn is_ok(source: String) -> Bool {
  case check(source) {
    Ok(_) -> True
    Error(_) -> False
  }
}

// Check something that must fail, and return where the error is.
fn error_position(source: String) -> #(Int, Int) {
  let assert Error(error) = check(source)
  case error {
    checker.AlreadyDefined(_, line, col) -> #(line, col)
    checker.UnboundVariable(_, line, col) -> #(line, col)
  }
}

// Check something that must fail, and return its message in lower case.
fn error_message(source: String) -> String {
  let assert Error(error) = check(source)
  case error {
    checker.AlreadyDefined(message, _, _) -> string.lowercase(message)
    checker.UnboundVariable(message, _, _) -> string.lowercase(message)
  }
}

// ---------- v0 programs (no variables) must still pass ----------

pub fn empty_program_test() {
  assert is_ok("")
}

pub fn blank_lines_test() {
  assert is_ok("\n\n")
}

pub fn precedence_expression_test() {
  assert is_ok("1 + 2 * 3")
}

pub fn parentheses_and_division_test() {
  assert is_ok("(10 - 4) / 2")
}

pub fn power_chain_with_comment_test() {
  assert is_ok("2 ** 3 ** 2   # 512")
}

pub fn mixed_ints_and_floats_test() {
  assert is_ok("-5 + 3.5")
}

pub fn several_expression_lines_test() {
  assert is_ok("1\n2.5\n3 // 2\n7 % 3")
}

pub fn runtime_errors_are_not_the_checkers_job_test() {
  // these only fail when the program runs
  assert is_ok("1 / 0")
  assert is_ok("0 ** -1")
}

// ---------- valid programs with variables ----------

pub fn single_let_test() {
  assert is_ok("let x = 5")
}

pub fn let_then_use_test() {
  assert is_ok("let x = 5\nx * 2")
}

pub fn float_let_test() {
  assert is_ok("let pi = 3.5\npi * 2")
}

pub fn let_using_an_earlier_let_test() {
  assert is_ok("let x = 5\nlet y = x * 2.5\nx + y")
}

pub fn chain_of_lets_test() {
  assert is_ok("let a = 1\nlet b = a + 1\nlet c = b + a\nc")
}

pub fn same_variable_used_many_times_test() {
  assert is_ok("let x = 3\nx * x + x - x")
}

pub fn variable_inside_parentheses_and_negation_test() {
  assert is_ok("let x = 3\n-(x + 1) ** 2")
}

pub fn let_with_comment_and_blank_lines_test() {
  assert is_ok("let x = 5 # five\n\n\nx")
}

pub fn expressions_between_lets_test() {
  assert is_ok("1\nlet x = 2\nx\n3")
}

pub fn names_that_look_alike_are_different_names_test() {
  assert is_ok("let x = 1\nlet x1 = 2\nlet _x = 3\nlet X = 4\nx + x1 + _x + X")
}

// ---------- unknown names ----------

pub fn unknown_name_alone_test() {
  assert error_position("x") == #(1, 1)
}

pub fn unknown_name_on_the_right_test() {
  assert error_position("1 + x") == #(1, 5)
}

pub fn unknown_name_on_the_left_test() {
  assert error_position("x + 1") == #(1, 1)
}

pub fn unknown_name_inside_parentheses_test() {
  assert error_position("(1 + z) * 2") == #(1, 6)
}

pub fn unknown_name_in_a_let_test() {
  // "let y = x": x at col 9
  assert error_position("let y = x") == #(1, 9)
}

pub fn unknown_name_on_a_later_line_test() {
  assert error_position("let x = 1\ny") == #(2, 1)
}

pub fn unknown_name_in_the_second_let_test() {
  // "let b = c + a" on line 2: c at col 9
  assert error_position("let a = 1\nlet b = c + a") == #(2, 9)
}

pub fn use_before_definition_test() {
  assert error_position("x\nlet x = 1") == #(1, 1)
}

pub fn let_cannot_use_its_own_name_test() {
  // "let x = x + 1": the x at col 9 doesn't exist yet
  assert error_position("let x = x + 1") == #(1, 9)
}

pub fn failed_let_does_not_define_its_name_test() {
  // the error is the unknown y at col 9, not an unknown x on line 2
  assert error_position("let x = y\nx") == #(1, 9)
}

pub fn first_error_wins_test() {
  assert error_position("y\nz") == #(1, 1)
}

pub fn unknown_name_message_mentions_the_name_test() {
  let message = error_message("weight + 1")
  assert string.contains(message, "unbound")
  assert string.contains(message, "weight")
}

// ---------- redefinition ----------

pub fn redefinition_test() {
  // the error points at the name in the second let: col 5 of line 2
  assert error_position("let x = 1\nlet x = 2") == #(2, 5)
}

pub fn redefinition_with_a_different_type_test() {
  assert error_position("let x = 1\nlet x = 2.5") == #(2, 5)
}

pub fn redefinition_using_the_old_value_test() {
  assert error_position("let x = 1\nlet x = x + 1") == #(2, 5)
}

pub fn redefinition_after_other_statements_test() {
  assert error_position("let x = 1\nx\nlet x = 3") == #(3, 5)
}

pub fn redefinition_message_test() {
  let message = error_message("let total = 1\nlet total = 2")
  assert string.contains(message, "already")
  assert string.contains(message, "defined")
  assert string.contains(message, "total")
}
