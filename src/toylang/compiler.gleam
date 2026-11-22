import gleam/float
import gleam/int
import gleam/list
import gleam/string
import toylang/parser

pub type CompileType {
  IntType
  FloatType
}

pub fn to_qbe_type(ct: CompileType) -> String {
  case ct {
    IntType -> "l"
    FloatType -> "d"
  }
}

pub type CompileError {
  CompileError(message: String)
}

pub fn work_type(
  op: parser.BinaryOp,
  left_type: CompileType,
  right_type: CompileType,
) -> CompileType {
  case op {
    parser.Div -> FloatType
    _ -> {
      case left_type, right_type {
        IntType, IntType -> IntType
        _, _ -> FloatType
      }
    }
  }
}

pub fn convert(
  t: String,
  from_type: CompileType,
  to_type: CompileType,
  n: Int,
) -> #(List(String), String, Int) {
  case from_type, to_type {
    IntType, IntType -> #([], t, n)
    FloatType, FloatType -> #([], t, n)
    _, _ -> {
      let n1 = n + 1
      let r = "%t" <> int.to_string(n1)
      // Conversion can only happen one way (Int -> Float),
      // hence the default use of 'd' here
      let line = r <> " =d sltof " <> t
      #([line], r, n1)
    }
  }
}

pub fn emit_op(
  op: parser.BinaryOp,
  wtype: CompileType,
  result: String,
  a: String,
  b: String,
) -> String {
  let q = to_qbe_type(wtype)
  case op {
    parser.Add -> {
      result <> " =" <> q <> " add " <> a <> ", " <> b
    }
    parser.Mul -> {
      result <> " =" <> q <> " mul " <> a <> ", " <> b
    }
    parser.Sub -> {
      result <> " =" <> q <> " sub " <> a <> ", " <> b
    }
    parser.Div -> {
      result <> " =d call $tl_div(d " <> a <> ", d " <> b <> ")"
    }
    parser.FloorDiv -> {
      let floor_div_tp = case wtype {
        IntType -> "int"
        FloatType -> "float"
      }
      result
      <> " ="
      <> q
      <> " call $tl_floordiv_"
      <> floor_div_tp
      <> "("
      <> q
      <> " "
      <> a
      <> ", "
      <> q
      <> " "
      <> b
      <> ")"
    }
    parser.Mod -> {
      let mod_tp = case wtype {
        IntType -> "int"
        FloatType -> "float"
      }
      result
      <> " ="
      <> q
      <> " call $tl_mod_"
      <> mod_tp
      <> "("
      <> q
      <> " "
      <> a
      <> ", "
      <> q
      <> " "
      <> b
      <> ")"
    }
    parser.Pow -> {
      let pow_tp = case wtype {
        IntType -> "int"
        FloatType -> "float"
      }
      result
      <> " ="
      <> q
      <> " call $tl_pow_"
      <> pow_tp
      <> "("
      <> q
      <> " "
      <> a
      <> ", "
      <> q
      <> " "
      <> b
      <> ")"
    }
  }
}

pub fn compile_expr(
  expr: parser.Expr,
  n: Int,
) -> #(List(String), String, CompileType, Int) {
  case expr {
    parser.IntLit(k) -> {
      let n1 = n + 1
      let t = "%t" <> int.to_string(n1)
      let lines = [t <> " =l copy " <> int.to_string(k)]
      #(lines, t, IntType, n1)
    }
    parser.FloatLit(k) -> {
      let n1 = n + 1
      let t = "%t" <> int.to_string(n1)
      let lines = [t <> " =d copy d_" <> float.to_string(k)]
      #(lines, t, FloatType, n1)
    }
    parser.Neg(inner) -> {
      let #(lines, t, ty, n1) = compile_expr(inner, n)
      let n2 = n1 + 1
      let t1 = "%t" <> int.to_string(n2)
      let line = t1 <> " =" <> to_qbe_type(ty) <> " neg " <> t
      #(lines |> list.append([line]), t1, ty, n2)
    }
    parser.BinOp(op, left, right) -> {
      let #(l_lines, lt, lty, n1) = compile_expr(left, n)
      let #(r_lines, rt, rty, n2) = compile_expr(right, n1)
      let wt = work_type(op, lty, rty)
      let #(l_conv, lt2, n3) = convert(lt, lty, wt, n2)
      let #(r_conv, rt2, n4) = convert(rt, rty, wt, n3)
      let n5 = n4 + 1
      let r = "%t" <> int.to_string(n5)
      let op_line = emit_op(op, wt, r, lt2, rt2)
      let lines =
        l_lines
        |> list.append(r_lines)
        |> list.append(l_conv)
        |> list.append(r_conv)
        |> list.append([op_line])
      #(lines, r, wt, n5)
    }
  }
}

fn compile_program_to_lines(
  exprs: List(parser.Expr),
  lines: List(String),
  n: Int,
) -> List(String) {
  case exprs {
    [] -> {
      lines |> list.append(["ret 0", "}", "\n"])
    }
    [first, ..rest] -> {
      let #(expr_lines, t, ty, n1) = compile_expr(first, n)
      let print_tp = case ty {
        IntType -> "int"
        FloatType -> "float"
      }
      let print_line =
        "call $tl_print_"
        <> print_tp
        <> "("
        <> to_qbe_type(ty)
        <> " "
        <> t
        <> ")"
      let lines = lines |> list.append(expr_lines) |> list.append([print_line])
      compile_program_to_lines(rest, lines, n1)
    }
  }
}

pub fn compile_program(exprs: List(parser.Expr)) -> String {
  let lines =
    compile_program_to_lines(
      exprs,
      ["export function w $main() {", "@start"],
      0,
    )
  lines |> string.join("\n")
}
