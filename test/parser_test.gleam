import toylang/lexer
import toylang/parser.{
  Add, BinOp, Div, FloatLit, FloorDiv, IntLit, Mod, Mul, Neg, Pow, Sub,
}

// ---------- helpers (the only place that knows your function names) ----------

// Lex + parse a whole program, expecting success.
fn parse(source: String) -> List(parser.Expr) {
  let assert Ok(tokens) = lexer.lex(source)
  let assert Ok(exprs) = parser.parse_program(tokens, [])
  exprs
}

// Parse a program that must contain exactly one expression.
fn parse_one(source: String) -> parser.Expr {
  let assert [expr] = parse(source)
  expr
}

// Lex + parse something that must fail, and return where the error is.
fn error_position(source: String) -> #(Int, Int) {
  let assert Ok(tokens) = lexer.lex(source)
  let assert Error(error) = parser.parse_program(tokens, [])
  case error {
    parser.Parsing(_, line, col) -> #(line, col)
    parser.Empty -> {
      echo "Unexpected empty error"
      panic
    }
  }
}

// ---------- atoms ----------

pub fn int_test() {
  assert parse_one("42") == IntLit(42)
}

pub fn float_test() {
  assert parse_one("3.5") == FloatLit(3.5)
}

// ---------- precedence ----------

pub fn mul_binds_tighter_than_add_test() {
  assert parse_one("1+2*3")
    == BinOp(Add, IntLit(1), BinOp(Mul, IntLit(2), IntLit(3)))
}

pub fn mixed_operators_test() {
  // 1 + 2 - 3 * 4 / 5  ==  (1 + 2) - ((3 * 4) / 5)
  assert parse_one("1 + 2 - 3 * 4 / 5")
    == BinOp(
      Sub,
      BinOp(Add, IntLit(1), IntLit(2)),
      BinOp(Div, BinOp(Mul, IntLit(3), IntLit(4)), IntLit(5)),
    )
}

pub fn power_binds_tighter_than_mul_test() {
  assert parse_one("2**3*4")
    == BinOp(Mul, BinOp(Pow, IntLit(2), IntLit(3)), IntLit(4))
}

// ---------- associativity ----------

pub fn subtraction_is_left_associative_test() {
  assert parse_one("1-2-3")
    == BinOp(Sub, BinOp(Sub, IntLit(1), IntLit(2)), IntLit(3))
}

pub fn division_is_left_associative_test() {
  assert parse_one("8/4/2")
    == BinOp(Div, BinOp(Div, IntLit(8), IntLit(4)), IntLit(2))
}

pub fn mul_and_div_are_left_associative_test() {
  assert parse_one("2*3/4")
    == BinOp(Div, BinOp(Mul, IntLit(2), IntLit(3)), IntLit(4))
}

pub fn floor_div_and_mod_are_left_associative_test() {
  assert parse_one("7//2%3")
    == BinOp(Mod, BinOp(FloorDiv, IntLit(7), IntLit(2)), IntLit(3))
}

pub fn power_is_right_associative_test() {
  assert parse_one("2**3**2")
    == BinOp(Pow, IntLit(2), BinOp(Pow, IntLit(3), IntLit(2)))
}

// ---------- unary minus ----------

pub fn unary_minus_binds_looser_than_power_test() {
  // -2**2 is -(2**2), as in Python
  assert parse_one("-2**2") == Neg(BinOp(Pow, IntLit(2), IntLit(2)))
}

pub fn negative_exponent_test() {
  assert parse_one("2**-1") == BinOp(Pow, IntLit(2), Neg(IntLit(1)))
}

pub fn double_negation_test() {
  assert parse_one("--3") == Neg(Neg(IntLit(3)))
}

pub fn unary_minus_binds_tighter_than_mul_test() {
  assert parse_one("-2*3") == BinOp(Mul, Neg(IntLit(2)), IntLit(3))
}

pub fn negative_right_operand_test() {
  assert parse_one("2 * -3") == BinOp(Mul, IntLit(2), Neg(IntLit(3)))
}

pub fn negated_group_test() {
  assert parse_one("-(1+2)") == Neg(BinOp(Add, IntLit(1), IntLit(2)))
}

// ---------- parentheses ----------

pub fn parentheses_override_precedence_test() {
  assert parse_one("(1+2)*3")
    == BinOp(Mul, BinOp(Add, IntLit(1), IntLit(2)), IntLit(3))
}

pub fn nested_parentheses_test() {
  assert parse_one("((4))") == IntLit(4)
}

pub fn parenthesised_base_of_power_test() {
  assert parse_one("(2+3)**2")
    == BinOp(Pow, BinOp(Add, IntLit(2), IntLit(3)), IntLit(2))
}

// ---------- whole programs ----------

pub fn empty_program_test() {
  assert parse("") == []
}

pub fn only_blank_lines_test() {
  assert parse("\n\n") == []
}

pub fn two_lines_test() {
  assert parse("1\n\n2") == [IntLit(1), IntLit(2)]
}

pub fn two_expressions_test() {
  assert parse("1+2\n\n3*4")
    == [
      BinOp(Add, IntLit(1), IntLit(2)),
      BinOp(Mul, IntLit(3), IntLit(4)),
    ]
}

pub fn leading_and_trailing_newlines_test() {
  assert parse("\n\n1\n") == [IntLit(1)]
}

pub fn comment_is_ignored_test() {
  assert parse("1 # a comment") == [IntLit(1)]
}

// ---------- errors ----------

pub fn missing_right_operand_test() {
  // "1 +": EOF is at col 4
  assert error_position("1 +") == #(1, 4)
}

pub fn missing_closing_paren_test() {
  // "(1": EOF is at col 3
  assert error_position("(1") == #(1, 3)
}

pub fn lone_closing_paren_test() {
  assert error_position(")") == #(1, 1)
}

pub fn empty_parentheses_test() {
  // "()": the ) at col 2 is where a number was expected
  assert error_position("()") == #(1, 2)
}

pub fn two_numbers_in_a_row_test() {
  // "1 2": the second number at col 3 is unexpected
  assert error_position("1 2") == #(1, 3)
}

pub fn leading_operator_test() {
  assert error_position("* 3") == #(1, 1)
}

pub fn two_operators_in_a_row_test() {
  // "1 + * 2": the * at col 5
  assert error_position("1 + * 2") == #(1, 5)
}

pub fn extra_closing_paren_test() {
  // "1 + 2)": the ) at col 6
  assert error_position("1 + 2)") == #(1, 6)
}

pub fn missing_closing_paren_before_other_token_test() {
  // "(1 2)": the 2 at col 4 where ")" was expected
  assert error_position("(1 2)") == #(1, 4)
}

pub fn dangling_power_test() {
  // "2 **": EOF at col 5
  assert error_position("2 **") == #(1, 5)
}

pub fn lone_minus_test() {
  // "-": EOF at col 2
  assert error_position("-") == #(1, 2)
}

pub fn error_on_second_line_test() {
  // "1\n2 +": EOF is on line 2, col 4
  assert error_position("1\n2 +") == #(2, 4)
}
