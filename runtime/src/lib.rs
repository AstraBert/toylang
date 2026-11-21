use std::ops::Div;

use num_integer::Integer;

#[unsafe(no_mangle)]
pub extern "C" fn tl_print_int(n: i64) {
    println!("{}", n);
}

#[unsafe(no_mangle)]
pub extern "C" fn tl_div(a: f64, b: f64) -> f64 {
    if b == 0.0 {
        eprintln!("error: Division by zero");
        std::process::exit(1);
    }
    a / b
}

#[unsafe(no_mangle)]
pub extern "C" fn tl_print_float(f: f64) {
    println!("{:?}", f);
}

#[unsafe(no_mangle)]
pub extern "C" fn tl_floordiv_int(i: i64, m: i64) -> i64 {
    if m == 0 {
        eprintln!("error: Floor division by zero");
        std::process::exit(1);
    }
    Integer::div_floor(&i, &m)
}

#[unsafe(no_mangle)]
pub extern "C" fn tl_floordiv_float(i: f64, m: f64) -> f64 {
    if m == 0.0 {
        eprintln!("error: Floor division by zero");
        std::process::exit(1);
    }
    let res = i.div(m);
    res.floor()
}

#[unsafe(no_mangle)]
pub extern "C" fn tl_mod_int(i: i64, m: i64) -> i64 {
    if m == 0 {
        eprintln!("error: Modulo by zero");
        std::process::exit(1);
    }
    Integer::mod_floor(&i, &m)
}

#[unsafe(no_mangle)]
pub extern "C" fn tl_mod_float(i: f64, m: f64) -> f64 {
    if m == 0.0 {
        eprintln!("error: Modulo by zero");
        std::process::exit(1);
    }

    i - m * (i / m).floor()
}

#[unsafe(no_mangle)]
pub extern "C" fn tl_pow_int(i: i64, m: i64) -> i64 {
    if m < 0 {
        eprintln!("error: Use of negative exponent");
        std::process::exit(1);
    }

    match m {
        0 => 1,
        _ => i * tl_pow_int(i, m - 1),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn tl_pow_float(i: f64, m: f64) -> f64 {
    if m < 0.0 && i == 0.0 {
        eprintln!("error: Use of negative exponent with base 0");
        std::process::exit(1);
    }

    i.powf(m)
}
