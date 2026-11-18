Command line options
====================

`(rime command-line-options)` exports one macro, `define-command-line-options`.
It defines a function that parses the command line arguments and returns an
accessor for the options and the positional arguments. It works on Chez Scheme and Guile.

```scheme
(import (rnrs (6)) (rime command-line-options))

(define-command-line-options parse
  ["-v" :long "--verbose" :arity 0 :description "print more details"]
  ["-n" :long "--count"   :arity 1 :type int :description "number of repetitions"]
  ["-e" :long "--exclude" :arity (1 +) :description "patterns to exclude"])

(define option (parse (cdr (command-line))))   ; for `prog -v --count 3 -e a b -- x`

(option "-v")                          ; => present
(option "--count")                     ; => 3
(option "-n")                          ; => 3   (short and long name are the same option)
(option "-e")                          ; => ("a" "b")
(option 'number-of-positional-argument) ; => 1
(option 0)                             ; => "x"
```

A runnable version is in `example/command-line-options.scm`.

# Defining options

```scheme
(define-command-line-options <parser>
  [<name> <field> ...]
  ...)
```

Each `[...]` clause defines one option. `<parser>` becomes a function of one argument,
the list of command line arguments (without the program name).

| field                | meaning                                                    | default    |
|----------------------|------------------------------------------------------------|------------|
| `<name>`             | short name, first in the clause, `"-b"`, required         |            |
| `:long "--long-name"`| long name                                                  | none       |
| `:arity <arity>`     | how many arguments the option takes                        | `1`        |
| `:type <type>`       | how to convert each argument, not allowed with arity `0`   | `string`   |
| `:description "..."` | text shown by `--help`                                     | empty      |

Fields can be written in any order. Mistakes in the definition (unknown field, duplicated
name, `:type` on a flag, `min > max`, ...) are reported when the program is compiled,
as syntax violations.

## Names

Option names are strings: `"-b"` (a single dash) and `"--long-name"` (two dashes).
Names must not contain `=`, `,` or whitespace. `-h` and `--help` are reserved.
There is no clustering, `-vq` is an unknown option, not `-v -q`.

Symbols are accepted too, `[-b :long --long-name]` and `(option '-b)`, but
strict R6RS readers (every `.sls` file on Chez, and files starting with `#!r6rs`) refuse
to read `-b` or `--long-name` as symbols. Strings work everywhere, use them in portable code.

## Arity

| written     | means           | takes                                                |
|-------------|-----------------|------------------------------------------------------|
| `0`         | `(0 0)`         | a flag, no argument, and no `:type`                  |
| `n`         | `(n n)`         | exactly `n` arguments                                |
| `(min max)` |                 | between `min` and `max` arguments                    |
| `(min +)`   | `(min max-fixnum)` | at least `min`, no upper bound                    |

`(min +)` stands for the `(min,)` notation, since `,` already means `unquote` in Scheme.

## Types

| `:type`  | converts                                                        | example        |
|----------|-----------------------------------------------------------------|----------------|
| `string` | nothing (default)                                               | `"abc"`        |
| `int`    | a fixnum                                                        | `"-3"` => `-3` |
| `float`  | a flonum, `"3"` gives `3.0`                                     | `"2.5"` => `2.5` |
| `bool`   | `true yes on 1` => `#t`, `false no off 0` => `#f` (any case)    | `"Yes"` => `#t` |
| `(lambda (string) ...)` | any procedure expression of one argument         |                |

A conversion failure, including an exception raised by your own procedure,
is reported as `invalid argument value`.

# Reading the result

`(parse arguments)` returns an accessor procedure, conventionally called `option`.

| call                                    | result                                                      |
|-----------------------------------------|-------------------------------------------------------------|
| `(option "-b")` or `(option "--long")`  | the value of the option, by short or long name              |
| `(option 0)`, `(option 1)`, ...         | the positional argument at that index, always a string      |
| `(option 'number-of-positional-argument)` | the number of positional arguments                        |

Symbols work as names as well, `(option (string->symbol "-b"))`.

What an option gives depends on its arity:

| arity                    | given                          | absent   |
|--------------------------|--------------------------------|----------|
| `0`                      | `present`                      | `absent` |
| `1` (also `(1 1)`)       | the converted value            | `#f`     |
| anything else            | the list of converted values   | `()`     |

An option that is given more than once keeps its last occurrence.
Asking for an option that was not defined, an index out of range, or any other kind of key
raises an error.

# Command line syntax

```
prog -v                       ; flag
prog -n 3                     ; short name, argument follows
prog --count 3                ; long name, argument follows
prog --count=3                ; long name with =
prog -n=3                     ; short name with =
prog -e a b c                 ; several arguments
prog --exclude=a,b,c          ; several arguments with =, separated by commas
```

* An option with `(min max)` arguments takes the following words until it has `max` of them, or the
  next word looks like an option, or the word is `--`. Fewer than `min` is an error.
* With `=`, the arguments are split at every comma and counted exactly, `--count=1,2` is
  `too many arguments for option`. This is the way to give an optional argument without
  ambiguity, `--window=2`.
* A flag does not accept `=`.

## Positional arguments

The first word that is not an option, and is not consumed as an argument of an option, starts the
positional arguments. Everything after that word is positional, even if it looks like an option.
`--` ends option parsing explicitly, everything after it is positional and kept as is.

```
prog -v in.txt out.txt        ; positional: "in.txt" "out.txt"
prog -v -- -x                 ; positional: "-x"
prog in.txt -v                ; positional: "in.txt" "-v"   (-v is NOT the flag here)
```

## Arguments starting with `-`

A word starting with `-` is an option. To use it as a value, escape the dash with a backslash,
`\-`. This is the text the program receives, so the backslash has to survive the shell.
In a shell, write `'\-x'` or `\\-x`.

```
prog -s '\-x'                 ; -s gets "-x"
prog -n '\-5'                 ; -n gets -5
prog '\-file'                 ; positional "-file"
prog --files='\-a,b'          ; "-a" "b"
```

A lone `-` is a value, not an option, and so is any word after `--`.
So, negative numbers must be written `\-5`: `-n -5` is `too few arguments for option`.

# Help

`-h` and `--help` are always available. They print the usage table and `(exit 0)`.
Names, argument placeholders and descriptions are aligned, a multi-line description is indented
under its first line.

```
$ grep-lite -h
Usage: /tmp/demo/grep-lite.scm [options] [--] [arguments...]

Options:
  -v, --verbose                 print more details
  -n, --count <int>             number of repetitions
  -r, --ratio <float>           sampling ratio
  -c, --color <bool>            colored output (yes/no/on/off/true/false/1/0)
  -e, --exclude <string>...     patterns to exclude
  -w, --window [<int>] [<int>]  context lines before [and after]
  -t, --tag <value>             custom conversion
  -h, --help                    show this help message and exit
```

The placeholder shows the arity: `<int> <int>` for 2, `<string>...` for `(1 +)`, `[<string>...]` for
`(0 +)`, `[<int>] [<int>]` for `(0 2)`. A custom `:type` procedure is shown as `<value>`.
The program name is the first element of `(command-line)`.

# Errors

Problems with the command line raise an `&error` condition from `(error 'opt-parser message irritant ...)`.
Catch it with `guard`; the library never exits by itself except for `-h`.

| message                            | when                                                  | irritants              |
|------------------------------------|-------------------------------------------------------|------------------------|
| `unknown option`                   | an option-like word that is not defined               | the word               |
| `too few arguments for option`     | fewer than `min` arguments                            | the option name        |
| `too many arguments for option`    | `--name=a,b,c` with more than `max` items             | the option name        |
| `option does not take arguments`   | `--flag=1` on an arity 0 option                       | the option name        |
| `invalid argument value`           | the conversion failed                                 | the option name, the text |

```scheme
(guard (e [(error? e) (display (condition-message e)) (newline) (exit 2)])
  (parse (cdr (command-line))))
```

The accessor raises `unknown option` for names that were not defined,
`positional argument index out of range` for a bad index, and `invalid option key`
for anything that is not a string, a symbol or an exact integer.

# A complete example

The examples above were run with this program (`grep-lite.scm`), with
`scheme --libdirs . --program grep-lite.scm <arguments>`, the output is real.

```scheme
#!r6rs
(import (rnrs (6)) (rime command-line-options))

(define-command-line-options parse
  ["-v" :long "--verbose" :arity 0 :description "print more details"]
  ["-n" :long "--count"   :arity 1 :type int :description "number of repetitions"]
  ["-r" :long "--ratio"   :type float :description "sampling ratio"]
  ["-c" :long "--color"   :type bool :description "colored output (yes/no/on/off/true/false/1/0)"]
  ["-e" :long "--exclude" :arity (1 +) :description "patterns to exclude"]
  ["-w" :long "--window"  :arity (0 2) :type int :description "context lines before [and after]"]
  ["-t" :long "--tag"     :type (lambda (s) (string-append "<" s ">")) :description "custom conversion"])

(define option (parse (cdr (command-line))))
(for-each (lambda (name) (write name) (display " => ") (write (option name)) (newline))
          '("-v" "-n" "-r" "-c" "-e" "-w" "-t"))
(display "positionals: ")
(write (let loop ([i 0])
         (if (< i (option 'number-of-positional-argument))
             (cons (option i) (loop (+ i 1)))
             '())))
(newline)
```

```
$ grep-lite
"-v" => absent
"-n" => #f
"-r" => #f
"-c" => #f
"-e" => ()
"-w" => ()
"-t" => #f
positionals: ()

$ grep-lite -v --count 3 -r 0.25 -c yes -e a b c -w 2 -t x in.txt out.txt
"-v" => present
"-n" => 3
"-r" => 0.25
"-c" => #t
"-e" => ("a" "b" "c")
"-w" => (2)
"-t" => "<x>"
positionals: ("in.txt" "out.txt")

$ grep-lite --count=3 --exclude=a,b,c --window=1,2 -- -v file
"-v" => absent
"-n" => 3
"-r" => #f
"-c" => #f
"-e" => ("a" "b" "c")
"-w" => (1 2)
"-t" => #f
positionals: ("-v" "file")

$ grep-lite -t '\-dash' '\-file'
"-v" => absent
"-n" => #f
"-r" => #f
"-c" => #f
"-e" => ()
"-w" => ()
"-t" => "<-dash>"
positionals: ("-file")

$ grep-lite -n abc
Exception in opt-parser: invalid argument value with irritants ("-n" "abc")

$ grep-lite -n
Exception in opt-parser: too few arguments for option with irritant "-n"

$ grep-lite --nope
Exception in opt-parser: unknown option with irritant "--nope"

$ grep-lite --count=1,2
Exception in opt-parser: too many arguments for option with irritant "--count"

$ grep-lite --verbose=1
Exception in opt-parser: option does not take arguments with irritant "--verbose"
```

# Tests

`test/rime/command-line-options-test.sls`, run with `make test-chez/rime/command-line-options-test`
(or `make test-chez` for everything), and the same with `test-guile`. The real `-h` path, which calls `exit`,
is exercised on Chez and on Guile.
