# ToyLang v0.1

## 1. Spec

### 1.1 Names

- A name starts with a letter or `_`, followed by letters, digits or `_` (ASCII only).
- `let` and `fn` are keywords and can't be used as names.
- `Int` and `Float` are the two type names. They are only looked at after a `:` in a parameter.

### 1.2 Statements

A program is a list of statements, one per line. A statement is one of:

| Statement | Example | Prints something? |
| --- | --- | --- |
| expression | `x + 1` | yes, its value (as in v0) |
| variable definition | `let x = 5` | no |
| function definition | `let f = fn(a: Int) { a + 1 }` | no |

The parser tells the last two apart by the token after the `=`: if it is `fn`, it's a function definition.

### 1.3 Variables

- `let x = expr` evaluates `expr` right away and gives the result the name `x`.
- A variable can only be used **after** the line that defines it.
- It can never change. There is no assignment.
- Defining a name that already exists **in the same scope** is an error (no redefinition).
- Its type is the type of its expression (`Int` or `Float`), exactly as in v0.

### 1.4 Functions

```
let name = fn(p1: Type, p2: Type) {
    let local = expression
    final_expression
}
```

- **Parameters** need a type annotation, `Int` or `Float`. There can be zero parameters: `fn() { 1 }`.
- **The body** is any number of `let` lines followed by one **final expression**, which is the function's result. A body with only a final expression fits on one line: `fn(n: Int) { n * 2 }`.
- **The return type** is not written: it is the type of the final expression.
- **Calling:** `name(arg1, arg2)`. A call is an expression, so it can sit inside bigger expressions and arguments can be any expressions: `double(double(2)) + 1`.
- **Arguments** are evaluated left to right.
- **Newlines** are allowed between the lines of a body (inside `{ }`), but not inside parentheses: a parameter list or an argument list must fit on one line.

### 1.5 What a function can see (scope)

Inside a function body you can use:

1. its parameters,
2. its own `let` variables (after their line),
3. **earlier functions** (to call them).

You **cannot** use top-level variables, and a function cannot call itself or a function defined later. This is deliberate for v0.1 (see section 3): a function only depends on its arguments, so it can be compiled as a separate QBE function with no hidden state.

A parameter or local may reuse a name that exists outside (it shadows it). Two parameters, or two locals, may not share a name.

### 1.6 Types and conversions

- The type rules for operators are exactly v0's (the work-type table).
- **Int to Float is automatic at a call:** passing an `Int` where a `Float` parameter is expected converts it (`area(x, 2)` above gives `h` the value `2.0`).
- **Float to Int is an error.** Passing a `Float` to an `Int` parameter is rejected.
- Functions are **not values**: you can only call them. `let g = f` and passing `f` as an argument are errors.

### 1.7 Errors found before running (the checker)

A new pass, the **checker**, runs after parsing and before the interpreter or compiler. Every error carries a line and column.

| Program | Error |
| --- | --- |
| `x + 1` (x never defined) | unknown name `x` |
| `let x = 1` then `let x = 2` | `x` is already defined |
| `let f = fn(a: Int) { a }` then `let f = 3` | `f` is already defined |
| `let f = fn(a: Int, a: Int) { a }` | duplicate parameter `a` |
| `let f = fn(a: Int) { a }` then `f(1, 2)` | `f` expects 1 argument, got 2 |
| `let f = fn(a: Int) { a }` then `f(1.5)` | argument 1: expected Int, got Float |
| `let f = fn(a: Int) { a }` then `f` | `f` is a function; call it |
| `let f = fn(a: Int) { a }` then `let g = f` | `f` is a function; call it |
| `let x = 5` then `x(1)` | `x` is not a function |
| `let x = 5` then `let f = fn(a: Int) { a + x }` | unknown name `x` (functions only see their parameters, locals and earlier functions) |
| `let f = fn(a: Int) { f(a) }` | unknown function `f` (no recursion) |
| `let f = fn(a) { a }` | parse error: expected `:` after the parameter name |
| `let f = fn(a: String) { a }` | parse error: unknown type `String` |
| `let f = fn(a: Int) { let b = a }` | parse error: the body must end with an expression |

Runtime errors (division by zero and so on) are unchanged from v0: the interpreter returns an `Error`, and the compiled program prints a message and exits with code 1.

### 1.8 Grammar

New or changed rules compared with v0 (the expression rules `expr`, `term`, `unary` and `power` don't change):

```
program    := stmt*
stmt       := (let_stmt | func_def | expr)? NEWLINE
let_stmt   := 'let' IDENT '=' expr
func_def   := 'let' IDENT '=' 'fn' '(' params? ')' block
params     := param (',' param)*
param      := IDENT ':' TYPE
block      := '{' NEWLINE* (let_stmt NEWLINE+)* expr NEWLINE* '}'
atom       := INT | FLOAT | IDENT | IDENT '(' args? ')' | '(' expr ')'
args       := expr (',' expr)*
```

`TYPE` is the identifier `Int` or `Float`. A call binds as tightly as an atom, so `-f(x)` is `-(f(x))` and `f(x) ** 2` squares the result.

### 1.9 Expected results

| Program | Output |
| --- | --- |
| `let x = 5` + `x * 2` | `10` |
| `let x = 5` + `let y = x * 2.5` + `x + y` | `17.5` |
| `let double = fn(n: Int) { n * 2 }` + `double(21)` | `42` |
| same, then `double(double(2))` | `8` |
| `area` from section 1, `area(5, 2)` | `10.0` |
| `area(3, 0.5)` | `1.5` |
| `let one = fn() { 1 }` + `one() + one()` | `2` |
| `let sq = fn(a: Int) { a * a }` + `let sumsq = fn(a: Int, b: Int) { sq(a) + sq(b) }` + `sumsq(3, 4)` | `25` |
| `let x = 100` + `let f = fn(x: Int) { x + 1 }` + `f(1)` | `2` (the parameter shadows) |
| `let half = fn(v: Float) { v / 2 }` + `half(5)` | `2.5` (5 becomes 5.0 at the call) |
| `let f = fn(a: Int) { a + 1 }` + `f(1) * f(2)` | `6` |
| `let f = fn(a: Int) { a + 1 }` + `let y = f(4)` + `y * 2` | `10` |

## 2. Decisions and why

| Topic | v0.1 choice | Why | Later |
| --- | --- | --- | --- |
| Parameter types | required annotation | the compiler needs static types before running; inference is a separate project | infer them from the body |
| Return type | inferred from the final expression | the checker already computes expression types | optional `-> Float` |
| Int passed as Float | allowed, converted at the call | matches the arithmetic promotion you already have | none |
| Float passed as Int | error | it would silently lose information | an explicit `int(x)` function |
| What functions can see | parameters, own locals, earlier functions | each function becomes a separate QBE function, so main's temporaries don't exist inside it | global constants, or closures |
| Recursion | not possible (a function's name isn't bound inside its own body) | there is no `if` yet, so it could never stop | after `if` |
| Same-scope redefinition | error | with immutability, one name should have one meaning | optional shadowing |
| Shadowing in function scope | allowed | harmless, and functions are closed anyway |  |
| Functions as values | no, call only | avoids closures and function pointers | first-class functions |
| Nested functions | no, `fn` only at top level | same reason |  |
| Newlines in parentheses | not supported | keeps the lexer simple | track paren depth in the lexer |
| Positions in the AST | on the new nodes only (`Var`, `Call`, `Let`, `FuncDef`) | that's where the checker's errors are | positions everywhere |
