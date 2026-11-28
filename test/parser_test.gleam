import toylang/lexer
import toylang/parser.{
  Add, BinOp, Div, ExprStmt, FloatLit, FloorDiv, IntLit, Let, Mod, Mul, Neg, Pow,
  Sub, Var,
}

// ---------- helpers (the only place that knows your function names) ----------

// Lex + parse a whole program, expecting success.
fn parse(source: String) -> List(parser.Stmt) {
  let assert Ok(tokens) = lexer.lex(source)
  let assert Ok(stmts) = parser.parse_program(tokens, [])
  stmts
}

// Parse a program that must contain exactly one statement.
fn parse_one(source: String) -> parser.Stmt {
  let assert [stmt] = parse(source)
  stmt
}

// Parse a program that must be exactly one expression statement,
// and return the expression. Keeps the old expression tests short.
fn expr(source: String) -> parser.Expr {
  let assert ExprStmt(e) = parse_one(source)
  e
}

// Lex + parse something that must fail, and return where the error is.
fn error_position(source: String) -> #(Int, Int) {
  let assert Ok(tokens) = lexer.lex(source)
  let assert Error(parser.Parsing(message: _, line: line, col: col)) =
    parser.parse_program(tokens, [])
  #(line, col)
}

// ---------- expressions (the old tests, now through statements) ----------

pub fn int_test() {
  assert expr("42") == IntLit(42)
}

pub fn float_test() {
  assert expr("3.5") == FloatLit(3.5)
}

pub fn mul_binds_tighter_than_add_test() {
  assert expr("1+2*3")
    == BinOp(Add, IntLit(1), BinOp(Mul, IntLit(2), IntLit(3)))
}

pub fn mixed_operators_test() {
  assert expr("1 + 2 - 3 * 4 / 5")
    == BinOp(
      Sub,
      BinOp(Add, IntLit(1), IntLit(2)),
      BinOp(Div, BinOp(Mul, IntLit(3), IntLit(4)), IntLit(5)),
    )
}

pub fn power_binds_tighter_than_mul_test() {
  assert expr("2**3*4")
    == BinOp(Mul, BinOp(Pow, IntLit(2), IntLit(3)), IntLit(4))
}

pub fn subtraction_is_left_associative_test() {
  assert expr("1-2-3")
    == BinOp(Sub, BinOp(Sub, IntLit(1), IntLit(2)), IntLit(3))
}

pub fn division_is_left_associative_test() {
  assert expr("8/4/2")
    == BinOp(Div, BinOp(Div, IntLit(8), IntLit(4)), IntLit(2))
}

pub fn mul_and_div_are_left_associative_test() {
  assert expr("2*3/4")
    == BinOp(Div, BinOp(Mul, IntLit(2), IntLit(3)), IntLit(4))
}

pub fn floor_div_and_mod_are_left_associative_test() {
  assert expr("7//2%3")
    == BinOp(Mod, BinOp(FloorDiv, IntLit(7), IntLit(2)), IntLit(3))
}

pub fn power_is_right_associative_test() {
  assert expr("2**3**2")
    == BinOp(Pow, IntLit(2), BinOp(Pow, IntLit(3), IntLit(2)))
}

pub fn unary_minus_binds_looser_than_power_test() {
  assert expr("-2**2") == Neg(BinOp(Pow, IntLit(2), IntLit(2)))
}

pub fn negative_exponent_test() {
  assert expr("2**-1") == BinOp(Pow, IntLit(2), Neg(IntLit(1)))
}

pub fn double_negation_test() {
  assert expr("--3") == Neg(Neg(IntLit(3)))
}

pub fn unary_minus_binds_tighter_than_mul_test() {
  assert expr("-2*3") == BinOp(Mul, Neg(IntLit(2)), IntLit(3))
}

pub fn negative_right_operand_test() {
  assert expr("2 * -3") == BinOp(Mul, IntLit(2), Neg(IntLit(3)))
}

pub fn negated_group_test() {
  assert expr("-(1+2)") == Neg(BinOp(Add, IntLit(1), IntLit(2)))
}

pub fn parentheses_override_precedence_test() {
  assert expr("(1+2)*3")
    == BinOp(Mul, BinOp(Add, IntLit(1), IntLit(2)), IntLit(3))
}

pub fn nested_parentheses_test() {
  assert expr("((4))") == IntLit(4)
}

pub fn parenthesised_base_of_power_test() {
  assert expr("(2+3)**2")
    == BinOp(Pow, BinOp(Add, IntLit(2), IntLit(3)), IntLit(2))
}

// ---------- using variables ----------

pub fn variable_alone_test() {
  assert parse_one("x") == ExprStmt(Var("x", 1, 1))
}

pub fn variable_in_addition_test() {
  assert expr("x + 1") == BinOp(Add, Var("x", 1, 1), IntLit(1))
}

pub fn two_variables_have_their_own_positions_test() {
  // x at col 1, y at col 5
  assert expr("x * y") == BinOp(Mul, Var("x", 1, 1), Var("y", 1, 5))
}

pub fn variable_in_power_and_negation_test() {
  // - at col 1, x at col 2
  assert expr("-x ** 2") == Neg(BinOp(Pow, Var("x", 1, 2), IntLit(2)))
}

pub fn parenthesised_variable_test() {
  assert expr("(x)") == Var("x", 1, 2)
}

pub fn name_starting_with_a_keyword_is_a_variable_test() {
  assert expr("letter + 1") == BinOp(Add, Var("letter", 1, 1), IntLit(1))
}

pub fn name_with_underscore_and_digits_test() {
  assert expr("my_var_2") == Var("my_var_2", 1, 1)
}

// ---------- let statements ----------
// The line and column of a Let are those of the variable's name
// (the x in "let x = 5", col 5). If you chose the position of the `let`
// keyword instead, change the 5s below to 1s.

pub fn let_with_a_number_test() {
  assert parse_one("let x = 5") == Let("x", IntLit(5), 1, 5)
}

pub fn let_with_a_float_test() {
  assert parse_one("let pi = 3.14") == Let("pi", FloatLit(3.14), 1, 5)
}

pub fn let_with_an_expression_test() {
  assert parse_one("let z = (1 + 2) * 3")
    == Let("z", BinOp(Mul, BinOp(Add, IntLit(1), IntLit(2)), IntLit(3)), 1, 5)
}

pub fn let_using_a_variable_test() {
  // x at col 9
  assert parse_one("let y = x * 2.5")
    == Let("y", BinOp(Mul, Var("x", 1, 9), FloatLit(2.5)), 1, 5)
}

pub fn let_with_negation_test() {
  assert parse_one("let n = -5") == Let("n", Neg(IntLit(5)), 1, 5)
}

pub fn let_without_spaces_around_equals_test() {
  assert parse_one("let x=5") == Let("x", IntLit(5), 1, 5)
}

pub fn let_with_a_trailing_comment_test() {
  assert parse_one("let x = 5 # five") == Let("x", IntLit(5), 1, 5)
}

// ---------- whole programs ----------

pub fn empty_program_test() {
  assert parse("") == []
}

pub fn only_blank_lines_test() {
  assert parse("\n\n") == []
}

pub fn two_expression_lines_test() {
  assert parse("1\n\n2") == [ExprStmt(IntLit(1)), ExprStmt(IntLit(2))]
}

pub fn two_expressions_test() {
  assert parse("1+2\n\n3*4")
    == [
      ExprStmt(BinOp(Add, IntLit(1), IntLit(2))),
      ExprStmt(BinOp(Mul, IntLit(3), IntLit(4))),
    ]
}

pub fn leading_and_trailing_newlines_test() {
  assert parse("\n\n1\n") == [ExprStmt(IntLit(1))]
}

pub fn comment_is_ignored_test() {
  assert parse("1 # a comment") == [ExprStmt(IntLit(1))]
}

pub fn let_then_expression_test() {
  assert parse("let x = 5\nx + 1")
    == [
      Let("x", IntLit(5), 1, 5),
      ExprStmt(BinOp(Add, Var("x", 2, 1), IntLit(1))),
    ]
}

pub fn two_lets_test() {
  assert parse("let a = 1\nlet b = 2")
    == [Let("a", IntLit(1), 1, 5), Let("b", IntLit(2), 2, 5)]
}

pub fn let_using_an_earlier_let_test() {
  // second line: b at col 5, a at col 9
  assert parse("let a = 1\nlet b = a + 1")
    == [
      Let("a", IntLit(1), 1, 5),
      Let("b", BinOp(Add, Var("a", 2, 9), IntLit(1)), 2, 5),
    ]
}

pub fn blank_lines_between_statements_test() {
  assert parse("let a = 1\n\n\na")
    == [Let("a", IntLit(1), 1, 5), ExprStmt(Var("a", 4, 1))]
}

pub fn mixed_program_test() {
  assert parse("let x = 5\nlet y = x * 2.5\nx + y")
    == [
      Let("x", IntLit(5), 1, 5),
      Let("y", BinOp(Mul, Var("x", 2, 9), FloatLit(2.5)), 2, 5),
      ExprStmt(BinOp(Add, Var("x", 3, 1), Var("y", 3, 5))),
    ]
}

// ---------- errors in expressions ----------

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

// ---------- errors in let statements ----------

pub fn let_alone_test() {
  // "let": expected a name, found EOF at col 4
  assert error_position("let") == #(1, 4)
}

pub fn let_without_a_name_test() {
  // "let = 5": the = at col 5 is where a name was expected
  assert error_position("let = 5") == #(1, 5)
}

pub fn let_with_a_number_as_name_test() {
  // "let 5 = 1": the 5 at col 5
  assert error_position("let 5 = 1") == #(1, 5)
}

pub fn let_with_a_keyword_as_name_test() {
  // "let let = 1": the second let at col 5
  assert error_position("let let = 1") == #(1, 5)
}

pub fn let_without_equals_at_end_test() {
  // "let x": expected =, found EOF at col 6
  assert error_position("let x") == #(1, 6)
}

pub fn let_with_something_else_instead_of_equals_test() {
  // "let x 5": the 5 at col 7
  assert error_position("let x 5") == #(1, 7)
}

pub fn let_without_expression_test() {
  // "let x =": EOF at col 8
  assert error_position("let x =") == #(1, 8)
}

pub fn let_with_a_broken_expression_test() {
  // "let x = * 3": the * at col 9
  assert error_position("let x = * 3") == #(1, 9)
}

pub fn let_followed_by_a_second_number_test() {
  // "let x = 1 2": the 2 at col 11
  assert error_position("let x = 1 2") == #(1, 11)
}

pub fn two_statements_on_one_line_test() {
  // "let x = 1 let y = 2": the second let at col 11
  assert error_position("let x = 1 let y = 2") == #(1, 11)
}

pub fn equals_without_let_test() {
  // "x = 5": the = at col 3 is unexpected after the expression x
  assert error_position("x = 5") == #(1, 3)
}

pub fn error_in_a_let_on_the_second_line_test() {
  // "let a = 1\nlet b =": EOF on line 2, col 8
  assert error_position("let a = 1\nlet b =") == #(2, 8)
}
