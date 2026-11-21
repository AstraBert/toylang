#!/bin/bash

dir=qbe-test
runtime=target/release/libruntime.a
pass=0
fail=0
rebuild=$1

if [[ "$rebuild" == "--rebuild" ]]
then
    cargo build --release
fi

for s in "$dir"/*.ssa; do
    name=$(basename "$s" .ssa)

    # Expected stdout = the comment lines that contain only a number
    expected=$(grep -E '^# -?[0-9]+(\.[0-9]+)?$' "$s" | sed 's/^# //')
    expected_code=0

    # err_* programs print 99, then must fail with exit code 1
    if [[ $name == err_* ]]; then
        expected="99"
        expected_code=1
    fi

    if ! qbe -o "$dir/out.s" "$s"; then
        echo "FAIL $name (qbe failed)"
        fail=$((fail + 1))
        continue
    fi
    if ! cc -o "$dir/out.toyx" "$dir/out.s" "$runtime"; then
        echo "FAIL $name (cc failed)"
        fail=$((fail + 1))
        rm -f "$dir/out.s"
        continue
    fi

    actual=$("$dir/out.toyx" 2>"$dir/err.txt")
    code=$?
    ok=1

    [[ "$actual" == "$expected" ]] || ok=0
    [[ $code -eq $expected_code ]] || ok=0
    # error programs must also print something on stderr
    if [[ $name == err_* && ! -s "$dir/err.txt" ]]; then ok=0; fi

    if [[ $ok -eq 1 ]]; then
        echo "PASS $name"
        pass=$((pass + 1))
    else
        echo "FAIL $name (exit code $code, expected $expected_code)"
        diff <(echo "$expected") <(echo "$actual")
        fail=$((fail + 1))
    fi

    rm -f "$dir/out.s" "$dir/out.toyx" "$dir/err.txt"
done

echo ""
echo "$pass passed, $fail failed"
[[ $fail -eq 0 ]]
