# ToyLang v0

The language is a calculator with Python flavour. A program is a list of lines; each line is one expression.

### 1.1 Example programs

```
1 + 2 * 3
(10 - 4) / 2
2 ** 3 ** 2   # comment: this is 2 ** (3 ** 2) = 512
7 // 2        # 3
7 % 2         # 1
-5 + 3.5
```

### 1.2 Literals

| Kind | Rule | Valid | Invalid |
| --- | --- | --- | --- |
| Int | one or more digits | `0`, `42`, `007` | `4_2` |
| Float | digits, a dot, digits | `3.14`, `0.5` | `.5`, `5.`, `1e5` |

Negative numbers are not literals. `-5` is the operator `-` applied to `5`.

### 1.3 Operators

| Symbol | Meaning |
| --- | --- |
| `+` | add |
| `-` | subtract, or negate (unary) |
| `*` | multiply |
| `/` | true division (always gives a float) |
| `//` | floor division |
| `%` | remainder |
| `**` | power |
| `( )` | grouping |

### 1.4 Precedence (tightest first)

1. `( )`
1. `**` (right-associative: `2 ** 3 ** 2` means `2 ** (3 ** 2)`)
3. unary `-`
4. `*`  `/`  `//`  `%` (left-associative)
5. `+`  `-` (left-associative)

Note: `-2 ** 2` is `-(2 ** 2)`, which is `-4`, as in Python.

### 1.5 Whitespace, newlines, comments

- Spaces and tabs between tokens are ignored.
- A newline ends a line and produces a `Newline` token.
- `#` starts a comment that runs to the end of the line. Comments produce no tokens.
- `\r` is ignored so Windows line endings work.
- Leading indentation is ignored for now. Real Python-style indentation arrives later, with blocks.
