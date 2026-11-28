# ToyLang

A toy language that I'm building to understand language development and learn [Gleam](https://gleam.run).

## Try It!

You can try ToyLang on MacOS and Linux, installing its interpreter and compiler with:

```bash
curl -fsSL https://raw.githubusercontent.com/AstraBert/toylang/main/install.sh | sh
```

Then write a toylang file, let's say `example.toy`:

```toy
let x = 5 
let y = x ** 2 # = 25
x + y # should print 30
```

And run it with the interpreter:

```bash
toylang run example.toy
```

Or compile it to a native binary (requires [qbe](https://c9x.me/compile/) and [cc](https://www.unix.com/man_page/v7/1/cc/) to be installed on your machine):

```bash
toylang build example.toy example.toyx
./example.toyx
```

In both cases, the [BEAM](https://en.wikipedia.org/wiki/BEAM_(Erlang_virtual_machine)) VM has to be available on your machine.
