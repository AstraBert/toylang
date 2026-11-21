import argv
import gleam/int
import gleam/io
import gleam/list
import simplifile
import toylang/interpreter
import toylang/lexer
import toylang/parser

const version: String = "0.0.0"

pub fn main() -> Nil {
  let args = argv.load()
  case args.arguments {
    [] -> {
      io.println_error(
        "You need to provide a flag (--version/--help) or the path to the ToyLang file to execute",
      )
    }
    [first, ..] -> {
      case first {
        "--help" ->
          io.println(
            "Execute a ToyLang script by providing its path. Prints the values to which each expression in the script evaluates.",
          )
        "--version" -> io.println("toylang v" <> version)
        _ -> {
          let res = simplifile.read(first)
          case res {
            Error(e) -> {
              e |> simplifile.describe_error |> io.println_error
            }
            Ok(source) -> {
              let tok_res = lexer.lex(source)
              case tok_res {
                Error(e) -> {
                  io.println_error(
                    "Lexing Error: "
                    <> e.message
                    <> "(line: "
                    <> int.to_string(e.line)
                    <> ", col: "
                    <> int.to_string(e.col)
                    <> ")",
                  )
                }
                Ok(toks) -> {
                  let expr_res = parser.parse_program(toks, [])
                  case expr_res {
                    Error(e) -> {
                      case e {
                        parser.Parsing(message, line, col) ->
                          io.println_error(
                            "Parsing Error: "
                            <> message
                            <> "(line: "
                            <> int.to_string(line)
                            <> ", col: "
                            <> int.to_string(col)
                            <> ")",
                          )
                        parser.Empty ->
                          io.println("Unexpected empty tokens list")
                      }
                    }
                    Ok(exprs) -> {
                      let int_res = interpreter.eval_program(exprs)
                      case int_res {
                        Error(e) -> {
                          io.println_error("Eval error: " <> e.message)
                        }
                        Ok(vals) -> {
                          vals
                          |> list.each(fn(x) {
                            x |> interpreter.to_string |> io.println
                          })
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
