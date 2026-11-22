import gleam/list
import gleam/string
import toylang/compiler
import toylang/lexer
import toylang/parser

// ---------- helpers (the only place that knows your function names) ----------

// Lex + parse + compile a whole program to QBE text.
fn compile(source: String) -> String {
  let assert Ok(tokens) = lexer.lex(source)
  let assert Ok(exprs) = parser.parse_program(tokens, [])
  compiler.compile_program(exprs)
}

// Split into lines, trim each one and drop blank lines, so the tests don't
// care about indentation or a trailing newline.
fn lines(source: String) -> List(String) {
  compile(source)
  |> string.split("\n")
  |> list.map(string.trim)
  |> list.filter(fn(line) { line != "" })
}

// Only the instructions between "@start" and "ret 0".
// This also checks the frame (header, label, ret, closing brace) on every call.
fn body(source: String) -> List(String) {
  let assert ["export function w $main() {", "@start", ..rest] = lines(source)
  let assert ["}", "ret 0", ..reversed_body] = list.reverse(rest)
  list.reverse(reversed_body)
}

// The name of every temporary that gets defined (the part before " =").
fn defined_temps(source: String) -> List(String) {
  body(source)
  |> list.filter_map(fn(line) {
    case string.split_once(line, " =") {
      Ok(#(name, _)) -> Ok(name)
      Error(Nil) -> Error(Nil)
    }
  })
}

// ---------- program frame ----------

pub fn empty_program_test() {
  assert body("") == []
}

// ---------- literals ----------

pub fn int_literal_test() {
  assert body("1")
    == [
      "%t1 =l copy 1",
      "call $tl_print_int(l %t1)",
    ]
}

pub fn float_literal_test() {
  assert body("2.5")
    == [
      "%t1 =d copy d_2.5",
      "call $tl_print_float(d %t1)",
    ]
}

// ---------- negation ----------

pub fn negated_int_test() {
  assert body("-5")
    == [
      "%t1 =l copy 5",
      "%t2 =l neg %t1",
      "call $tl_print_int(l %t2)",
    ]
}

pub fn double_negation_test() {
  assert body("--5")
    == [
      "%t1 =l copy 5",
      "%t2 =l neg %t1",
      "%t3 =l neg %t2",
      "call $tl_print_int(l %t3)",
    ]
}

pub fn negated_float_test() {
  assert body("-2.5")
    == [
      "%t1 =d copy d_2.5",
      "%t2 =d neg %t1",
      "call $tl_print_float(d %t2)",
    ]
}

// ---------- int arithmetic ----------

pub fn precedence_test() {
  assert body("1 + 2 * 3")
    == [
      "%t1 =l copy 1",
      "%t2 =l copy 2",
      "%t3 =l copy 3",
      "%t4 =l mul %t2, %t3",
      "%t5 =l add %t1, %t4",
      "call $tl_print_int(l %t5)",
    ]
}

pub fn subtraction_test() {
  assert body("5 - 3")
    == [
      "%t1 =l copy 5",
      "%t2 =l copy 3",
      "%t3 =l sub %t1, %t2",
      "call $tl_print_int(l %t3)",
    ]
}

pub fn parentheses_test() {
  assert body("(1 + 2) * 3")
    == [
      "%t1 =l copy 1",
      "%t2 =l copy 2",
      "%t3 =l add %t1, %t2",
      "%t4 =l copy 3",
      "%t5 =l mul %t3, %t4",
      "call $tl_print_int(l %t5)",
    ]
}

// ---------- float arithmetic and conversions ----------

pub fn two_floats_need_no_conversion_test() {
  assert body("1.5 + 2.5")
    == [
      "%t1 =d copy d_1.5",
      "%t2 =d copy d_2.5",
      "%t3 =d add %t1, %t2",
      "call $tl_print_float(d %t3)",
    ]
}

pub fn int_on_the_left_is_converted_test() {
  assert body("1 + 2.5")
    == [
      "%t1 =l copy 1",
      "%t2 =d copy d_2.5",
      "%t3 =d sltof %t1",
      "%t4 =d add %t3, %t2",
      "call $tl_print_float(d %t4)",
    ]
}

pub fn int_on_the_right_is_converted_test() {
  assert body("2.5 * 2")
    == [
      "%t1 =d copy d_2.5",
      "%t2 =l copy 2",
      "%t3 =d sltof %t2",
      "%t4 =d mul %t1, %t3",
      "call $tl_print_float(d %t4)",
    ]
}

pub fn negated_int_plus_float_test() {
  assert body("-5 + 3.5")
    == [
      "%t1 =l copy 5",
      "%t2 =l neg %t1",
      "%t3 =d copy d_3.5",
      "%t4 =d sltof %t2",
      "%t5 =d add %t4, %t3",
      "call $tl_print_float(d %t5)",
    ]
}

// ---------- true division ----------

pub fn int_division_converts_both_sides_test() {
  assert body("7 / 2")
    == [
      "%t1 =l copy 7",
      "%t2 =l copy 2",
      "%t3 =d sltof %t1",
      "%t4 =d sltof %t2",
      "%t5 =d call $tl_div(d %t3, d %t4)",
      "call $tl_print_float(d %t5)",
    ]
}

pub fn float_division_test() {
  assert body("7.0 / 2.0")
    == [
      "%t1 =d copy d_7.0",
      "%t2 =d copy d_2.0",
      "%t3 =d call $tl_div(d %t1, d %t2)",
      "call $tl_print_float(d %t3)",
    ]
}

// ---------- floor division and modulo ----------

pub fn int_floor_division_test() {
  assert body("7 // 2")
    == [
      "%t1 =l copy 7",
      "%t2 =l copy 2",
      "%t3 =l call $tl_floordiv_int(l %t1, l %t2)",
      "call $tl_print_int(l %t3)",
    ]
}

pub fn mixed_floor_division_test() {
  assert body("7.0 // 2")
    == [
      "%t1 =d copy d_7.0",
      "%t2 =l copy 2",
      "%t3 =d sltof %t2",
      "%t4 =d call $tl_floordiv_float(d %t1, d %t3)",
      "call $tl_print_float(d %t4)",
    ]
}

pub fn int_modulo_test() {
  assert body("7 % 2")
    == [
      "%t1 =l copy 7",
      "%t2 =l copy 2",
      "%t3 =l call $tl_mod_int(l %t1, l %t2)",
      "call $tl_print_int(l %t3)",
    ]
}

pub fn mixed_modulo_test() {
  assert body("7.5 % 2")
    == [
      "%t1 =d copy d_7.5",
      "%t2 =l copy 2",
      "%t3 =d sltof %t2",
      "%t4 =d call $tl_mod_float(d %t1, d %t3)",
      "call $tl_print_float(d %t4)",
    ]
}

// ---------- power ----------

pub fn int_power_test() {
  assert body("2 ** 10")
    == [
      "%t1 =l copy 2",
      "%t2 =l copy 10",
      "%t3 =l call $tl_pow_int(l %t1, l %t2)",
      "call $tl_print_int(l %t3)",
    ]
}

pub fn mixed_power_test() {
  assert body("2 ** 0.5")
    == [
      "%t1 =l copy 2",
      "%t2 =d copy d_0.5",
      "%t3 =d sltof %t1",
      "%t4 =d call $tl_pow_float(d %t3, d %t2)",
      "call $tl_print_float(d %t4)",
    ]
}

pub fn power_is_right_associative_test() {
  // 2 ** (3 ** 2): the inner power is computed first
  assert body("2 ** 3 ** 2")
    == [
      "%t1 =l copy 2",
      "%t2 =l copy 3",
      "%t3 =l copy 2",
      "%t4 =l call $tl_pow_int(l %t2, l %t3)",
      "%t5 =l call $tl_pow_int(l %t1, l %t4)",
      "call $tl_print_int(l %t5)",
    ]
}

// ---------- which print function is chosen ----------

pub fn float_result_uses_float_print_test() {
  assert list.last(body("8 / 4")) == Ok("call $tl_print_float(d %t5)")
}

pub fn int_result_uses_int_print_test() {
  assert list.last(body("8 // 4")) == Ok("call $tl_print_int(l %t3)")
}

// ---------- several lines ----------

pub fn counter_continues_across_lines_test() {
  assert body("1\n2.5")
    == [
      "%t1 =l copy 1",
      "call $tl_print_int(l %t1)",
      "%t2 =d copy d_2.5",
      "call $tl_print_float(d %t2)",
    ]
}

pub fn second_line_temps_are_fresh_test() {
  assert body("1 + 2\n3 + 4")
    == [
      "%t1 =l copy 1",
      "%t2 =l copy 2",
      "%t3 =l add %t1, %t2",
      "call $tl_print_int(l %t3)",
      "%t4 =l copy 3",
      "%t5 =l copy 4",
      "%t6 =l add %t4, %t5",
      "call $tl_print_int(l %t6)",
    ]
}

pub fn blank_lines_are_skipped_test() {
  assert body("\n1\n\n2\n")
    == [
      "%t1 =l copy 1",
      "call $tl_print_int(l %t1)",
      "%t2 =l copy 2",
      "call $tl_print_int(l %t2)",
    ]
}

// ---------- property: every temporary is defined exactly once ----------

pub fn temps_are_unique_test() {
  // QBE temporaries can be assigned only once, so a repeated name is a bug.
  // This test doesn't depend on how you number them.
  let source = "1 + 2.5 * (3 ** 2) - 7 // 2 % 3 / 2\n-4 ** 2\n1 + 1\n2.5 - 1"
  let temps = defined_temps(source)
  assert list.length(list.unique(temps)) == list.length(temps)
}
