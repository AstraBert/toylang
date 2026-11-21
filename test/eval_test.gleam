import gleam/float
import toylang/interpreter.{FloatValue, IntValue}
import toylang/lexer
import toylang/parser

// ---------- helpers (the only place that knows your function names) ----------

// Lex + parse + eval a whole program, expecting success.
fn run(source: String) -> List(interpreter.RunValue) {
  let assert Ok(tokens) = lexer.lex(source)
  let assert Ok(exprs) = parser.parse_program(tokens, [])
  let assert Ok(values) = interpreter.eval_program(exprs)
  values
}

// Run a program that must contain exactly one expression.
fn value(source: String) -> interpreter.RunValue {
  let assert [v] = run(source)
  v
}

// True when evaluating the program fails (lexing and parsing must succeed).
fn is_error(source: String) -> Bool {
  let assert Ok(tokens) = lexer.lex(source)
  let assert Ok(exprs) = parser.parse_program(tokens, [])
  case interpreter.eval_program(exprs) {
    Ok(_) -> False
    Error(_) -> True
  }
}

// For floats that can't be compared exactly.
fn assert_close(source: String, expected: Float) -> Nil {
  let assert FloatValue(actual) = value(source)
  assert float.absolute_value(actual -. expected) <. 0.000001
}

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

// ---------- whole programs ----------

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
  // the error must bubble up from the inner division
  assert is_error("1 + 1 / 0")
}

pub fn error_stops_the_program_test() {
  assert is_error("1\n2 / 0\n3")
}
