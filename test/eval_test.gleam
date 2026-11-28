import gleam/dict
import gleam/float
import toylang/checker
import toylang/interpreter.{FloatValue, IntValue}
import toylang/lexer
import toylang/parser

// ---------- helpers (the only place that knows your function names) ----------

// Lex + parse + check + eval a whole program, expecting success.
// (The checker runs first, as it will in the real pipeline, so every test
// program is also known to be valid. Delete that line if you prefer.)
fn run(source: String) -> List(interpreter.RunValue) {
  let assert Ok(tokens) = lexer.lex(source)
  let assert Ok(stmts) = parser.parse_program(tokens, [])
  let env: checker.Env = dict.new()
  let assert Ok(_) = checker.check_program(stmts, env)
  let var_env: interpreter.Env = dict.new()
  let vals: List(interpreter.RunValue) = []
  let assert Ok(values) = interpreter.eval_program(stmts, var_env, vals)
  values
}

// Run a program that must produce exactly one value.
fn value(source: String) -> interpreter.RunValue {
  let assert [v] = run(source)
  v
}

// True when evaluating the program fails (lexing, parsing and checking must succeed).
fn is_error(source: String) -> Bool {
  let assert Ok(tokens) = lexer.lex(source)
  let assert Ok(stmts) = parser.parse_program(tokens, [])
  let env: checker.Env = dict.new()
  let assert Ok(_) = checker.check_program(stmts, env)
  let var_env: interpreter.Env = dict.new()
  let vals: List(interpreter.RunValue) = []
  case interpreter.eval_program(stmts, var_env, vals) {
    Ok(_) -> False
    Error(_) -> True
  }
}

// For floats that can't be compared exactly.
fn assert_close(source: String, expected: Float) -> Nil {
  let assert FloatValue(actual) = value(source)
  assert float.absolute_value(actual -. expected) <. 0.000001
}

// ======================= v0: programs without variables =======================

// ---------- literals and negation ----------

pub fn int_literal_test() {
  assert value("42") == IntValue(42)
}

pub fn float_literal_test() {
  assert value("3.5") == FloatValue(3.5)
}

pub fn negative_int_test() {
  assert value("-3") == IntValue(-3)
}

pub fn negative_float_test() {
  assert value("-2.5") == FloatValue(-2.5)
}

pub fn double_negation_test() {
  assert value("--3") == IntValue(3)
}

pub fn negated_group_test() {
  assert value("-(3)") == IntValue(-3)
}

// ---------- int arithmetic ----------

pub fn precedence_test() {
  assert value("1 + 2 * 3") == IntValue(7)
}

pub fn parentheses_test() {
  assert value("(1 + 2) * 3") == IntValue(9)
}

pub fn subtraction_is_left_associative_test() {
  assert value("10 - 4 - 3") == IntValue(3)
}

pub fn chained_multiplication_test() {
  assert value("2 * 3 * 4") == IntValue(24)
}

// ---------- mixing ints and floats ----------

pub fn int_plus_float_test() {
  assert value("1 + 2.5") == FloatValue(3.5)
}

pub fn float_times_int_test() {
  assert value("2.5 * 2") == FloatValue(5.0)
}

pub fn int_minus_float_test() {
  assert value("3 - 0.5") == FloatValue(2.5)
}

// ---------- true division ----------

pub fn division_gives_float_test() {
  assert value("7 / 2") == FloatValue(3.5)
}

pub fn exact_division_is_still_float_test() {
  assert value("8 / 4") == FloatValue(2.0)
}

pub fn fractional_division_test() {
  assert value("1 / 4") == FloatValue(0.25)
}

// ---------- floor division ----------

pub fn floor_division_test() {
  assert value("7 // 2") == IntValue(3)
}

pub fn floor_division_rounds_down_test() {
  assert value("-7 // 2") == IntValue(-4)
}

pub fn floor_division_negative_divisor_test() {
  assert value("7 // -2") == IntValue(-4)
}

pub fn floor_division_both_negative_test() {
  assert value("-7 // -2") == IntValue(3)
}

pub fn floor_division_float_test() {
  assert value("7.0 // 2") == FloatValue(3.0)
}

pub fn floor_division_float_fraction_test() {
  assert value("7.5 // 2") == FloatValue(3.0)
}

// ---------- modulo ----------

pub fn modulo_test() {
  assert value("7 % 3") == IntValue(1)
}

pub fn modulo_negative_dividend_test() {
  assert value("-7 % 3") == IntValue(2)
}

pub fn modulo_negative_divisor_test() {
  assert value("7 % -3") == IntValue(-2)
}

pub fn modulo_both_negative_test() {
  assert value("-7 % -3") == IntValue(-1)
}

pub fn modulo_float_test() {
  assert value("7.5 % 2") == FloatValue(1.5)
}

pub fn modulo_negative_float_test() {
  assert value("-7.5 % 2") == FloatValue(0.5)
}

// ---------- power ----------

pub fn power_test() {
  assert value("2 ** 10") == IntValue(1024)
}

pub fn negative_exponent_gives_float_test() {
  assert value("2 ** -1") == FloatValue(0.5)
}

pub fn fractional_exponent_test() {
  assert_close("2 ** 0.5", 1.4142135623730951)
}

pub fn float_base_test() {
  assert value("2.0 ** 3") == FloatValue(8.0)
}

pub fn zero_to_the_zero_test() {
  assert value("0 ** 0") == IntValue(1)
}

pub fn zero_to_positive_power_test() {
  assert value("0 ** 5") == IntValue(0)
}

pub fn anything_to_the_zero_test() {
  assert value("5 ** 0") == IntValue(1)
}

pub fn power_is_right_associative_test() {
  assert value("2 ** 3 ** 2") == IntValue(512)
}

pub fn unary_minus_applies_after_power_test() {
  assert value("-2 ** 2") == IntValue(-4)
}

pub fn negative_base_in_parentheses_test() {
  assert value("(-2) ** 2") == IntValue(4)
  assert value("(-2) ** 3") == IntValue(-8)
}

pub fn big_power_stays_exact_test() {
  // Needs the Erlang target (the default), where ints don't overflow.
  assert value("2 ** 100")
    == IntValue(1_267_650_600_228_229_401_496_703_205_376)
}

// ---------- whole programs of expressions ----------

pub fn empty_program_test() {
  assert run("") == []
}

pub fn three_lines_test() {
  assert run("1\n2\n3") == [IntValue(1), IntValue(2), IntValue(3)]
}

pub fn blank_lines_are_skipped_test() {
  assert run("1 + 1\n\n2 * 2") == [IntValue(2), IntValue(4)]
}

// ---------- runtime errors ----------

pub fn divide_by_zero_test() {
  assert is_error("1 / 0")
}

pub fn divide_by_float_zero_test() {
  assert is_error("1 / 0.0")
}

pub fn floor_divide_by_zero_test() {
  assert is_error("1 // 0")
}

pub fn floor_divide_by_float_zero_test() {
  assert is_error("1 // 0.0")
}

pub fn modulo_by_zero_test() {
  assert is_error("1 % 0")
}

pub fn modulo_by_float_zero_test() {
  assert is_error("1 % 0.0")
}

pub fn zero_to_negative_power_test() {
  assert is_error("0 ** -1")
}

pub fn error_inside_larger_expression_test() {
  assert is_error("1 + 1 / 0")
}

pub fn error_stops_the_program_test() {
  assert is_error("1\n2 / 0\n3")
}

// ======================= slice A: variables =======================

// ---------- let prints nothing ----------

pub fn let_alone_prints_nothing_test() {
  assert run("let x = 5") == []
}

pub fn two_lets_print_nothing_test() {
  assert run("let a = 1\nlet b = 2") == []
}

// ---------- using variables ----------

pub fn let_then_use_test() {
  assert run("let x = 5\nx * 2") == [IntValue(10)]
}

pub fn variable_alone_test() {
  assert run("let x = 5\nx") == [IntValue(5)]
}

pub fn float_variable_test() {
  assert run("let pi = 3.5\npi * 2") == [FloatValue(7.0)]
}

pub fn int_and_float_variables_test() {
  assert run("let x = 5\nlet y = x * 2.5\nx + y") == [FloatValue(17.5)]
}

pub fn variable_used_many_times_test() {
  assert run("let x = 3\nx * x + x") == [IntValue(12)]
}

pub fn chain_of_lets_test() {
  assert run("let a = 1\nlet b = a + 1\nlet c = b * 3\nc") == [IntValue(6)]
}

pub fn alias_test() {
  assert run("let a = 5\nlet b = a\nb") == [IntValue(5)]
}

pub fn left_associativity_with_a_variable_test() {
  assert run("let x = 10\nx - 4 - 3") == [IntValue(3)]
}

pub fn two_variables_test() {
  assert run("let a = 2\nlet b = 3\na ** b") == [IntValue(8)]
  assert run("let a = 2\nlet b = 3\n(a + b) * (a - b)") == [IntValue(-5)]
}

// ---------- types of variables follow their expression ----------

pub fn division_makes_a_float_variable_test() {
  assert run("let h = 7 / 2\nh") == [FloatValue(3.5)]
}

pub fn floor_division_keeps_an_int_variable_test() {
  assert run("let q = 7 // 2\nq") == [IntValue(3)]
}

pub fn power_variable_test() {
  assert run("let p = 2 ** 10\np") == [IntValue(1024)]
}

pub fn int_variable_in_true_division_test() {
  assert run("let x = 5\nx / 2") == [FloatValue(2.5)]
}

pub fn negative_variable_floor_and_modulo_test() {
  assert run("let m = -7\nm // 2") == [IntValue(-4)]
  assert run("let m = -7\nm % 3") == [IntValue(2)]
}

pub fn power_chain_with_a_variable_test() {
  assert run("let x = 2\nx ** 3 ** 2") == [IntValue(512)]
}

// ---------- negation of variables ----------

pub fn negating_a_negative_variable_test() {
  assert run("let n = -5\n-n") == [IntValue(5)]
}

pub fn negating_a_positive_variable_test() {
  assert run("let n = 5\n-n") == [IntValue(-5)]
}

pub fn double_negation_of_a_variable_test() {
  assert run("let a = 2\n--a") == [IntValue(2)]
}

// ---------- mixing statements ----------

pub fn expressions_and_lets_interleaved_test() {
  assert run("1\nlet x = 2\nx\n3") == [IntValue(1), IntValue(2), IntValue(3)]
}

pub fn several_outputs_after_lets_test() {
  assert run("let x = 5\nlet y = x * 2.5\nx + y\ny - x")
    == [FloatValue(17.5), FloatValue(7.5)]
}

pub fn comments_and_blank_lines_test() {
  assert run("let x = 5 # five\n\nx") == [IntValue(5)]
}

// ---------- runtime errors with variables ----------

pub fn let_expression_is_evaluated_immediately_test() {
  // the division fails even though x is never used
  assert is_error("let x = 1 / 0\n5")
}

pub fn division_by_a_zero_variable_test() {
  assert is_error("let z = 0\n1 / z")
}

pub fn floor_division_by_a_zero_variable_test() {
  assert is_error("let z = 0\n1 // z")
}

pub fn modulo_by_a_zero_float_variable_test() {
  assert is_error("let z = 0.0\n1 % z")
}

pub fn error_after_a_let_stops_the_program_test() {
  assert is_error("let x = 1\n2 / 0\nx")
}

pub fn error_inside_an_expression_with_a_variable_test() {
  assert is_error("let a = 1\na + 1 / 0")
}
