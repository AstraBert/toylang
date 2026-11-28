import argv
import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import simplifile
import toylang/compiler
import toylang/interpreter
import toylang/lexer
import toylang/parser

const version: String = "0.1.0"

pub fn main() -> Nil {
  let args = argv.load()
  case args.arguments {
    [] -> {
      io.println_error(
        "You need to provide a flag (--version/--help) or a command (`run`, `build`) the path to the ToyLang file to execute",
      )
    }
    [first] -> {
      case first {
        "--version" -> {
          io.println("toylang v" <> version)
        }
        "--help" -> {
          io.println(
            "Run or compile a ToyLang file\nCommands:\n\trun <PATH>: run a file using the ToyLang interpreter\n\tbuild <PATH> [<OUT>]: compile a file to .ssa file containing QBE IL (use build.sh to compile to native binary with qbe, the runtime and cc)\n\nRun `toylang --version` to see the version of the language you are running on\nRun `toylang --help` to display this message again\n",
          )
        }
        _ -> {
          io.println_error("Unrecognized flag or command: " <> first)
        }
      }
    }
    [first, second, ..rest] -> {
      let res = simplifile.read(second)
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
                    parser.Empty -> io.println("Unexpected empty tokens list")
                  }
                }
                Ok(exprs) -> {
                  case first {
                    "run" -> {
                      let env: interpreter.Env = dict.new()
                      let vals: List(interpreter.RunValue) = []
                      let int_res = interpreter.eval_program(exprs, env, vals)
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
                    "build" -> {
                      let compiled = compiler.compile_program(exprs)
                      case compiled {
                        Ok(s) -> {
                          let out_file = case list.first(rest) {
                            Error(Nil) -> "out.s"
                            Ok(s) -> s
                          }
                          let resw = simplifile.write(out_file, s)
                          case resw {
                            Error(e) ->
                              io.println_error(
                                "An error occurred when writing the .ssa file: "
                                <> simplifile.describe_error(e),
                              )
                            Ok(_) ->
                              io.println("Saved QBE IL output to " <> out_file)
                          }
                        }
                        Error(e) -> {
                          io.println_error("Compilation error: " <> e.message)
                        }
                      }
                    }
                    _ -> {
                      io.println_error("Unknown command: " <> first)
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
