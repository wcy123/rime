Command line options
====================

`(rime command-line-options)` exports one macro, `define-command-line-options`.
It defines a function that parses the command line arguments and returns an
accessor for the options and the positional arguments. It works on Chez Scheme and Guile.

```scheme
(import (rnrs (6)) (rime command-line-options))

(define-command-line-options parse
  [:short "-v" :long "--verbose" :arity 0 :description "print more details"]
  [:short "-n" :long "--count"   :arity 1 :type int :description "number of repetitions"]
  [:short "-e" :long "--exclude" :arity (1 +) :description "patterns to exclude"]
  [:positional "file" :description "the input file"])

(define option (parse (cdr (command-line))))   ; for `prog -v --count 3 -e a b -- x`

(option "verbose")                     ; => present
(option "count")                       ; => 3
(option "n")                           ; => 3   (short and long name are the same option)
(option "exclude")                     ; => ("a" "b")
(option "file")                        ; => "x"
```

The names to read an option by are the names without the dashes. A runnable version is in
`example/command-line-options.scm`.

# Defining options

```scheme
(define-command-line-options <parser>
  [<field> ...]
  ...)
```

Each `[...]` clause defines one option, except a clause with `:positional`, which describes the
positional arguments, see [Positional arguments](#positional-arguments). `<parser>` becomes a
function of one argument, the list of command line arguments (without the program name).

| field                | meaning                                                    | default    |
|----------------------|------------------------------------------------------------|------------|
| `:short "-b"`        | short name                                                 | none       |
| `:long "--long-name"`| long name                                                  | none       |
| `:arity <arity>`     | how many arguments the option takes                        | `1`        |
| `:type <type>`       | how to convert each argument, not allowed with arity `0`   | `string`   |
| `:choices (...)`     | the arguments must be one of these, see [Choices](#choices) | none       |
| `:description "..."` | text shown by `--help`                                     | empty      |
| `:required`          | it is an error when the option is absent, see [Required options](#required-options) | optional |

The keywords `:short :long :arity :type :choices :description :required :positional` are exported by the library, so import it whole
(`(import (rime command-line-options))`); `(only (rime command-line-options) define-command-line-options)`
would leave them unbound and the clauses would be rejected.

Fields can be written in any order. An option needs a `:short` name, a `:long` name, or both.
Mistakes in the definition (unknown field, no name, duplicated name, `:type` on a flag, `min > max`, ...) are reported when the program is compiled,
as syntax violations.

## Names

Option names are strings: `:short "-b"` (a single dash) and `:long "--long-name"` (two dashes).
Names must not contain `=`, `,` or whitespace. `-h` and `--help` are reserved.
There is no clustering, `-vq` is an unknown option, not `-v -q`.

The program reads an option by its name without the dashes: `"b"` for `:short "-b"`, `"long-name"`
for `:long "--long-name"`. These names must be different for all options, so `[:short "-x"]` and
`[:long "--x"]` cannot be defined in different options, but they can be the two names of the
same one (`[:short "-emit" :long "--emit"]` is read as `"emit"`). `h` and `help` are reserved too.

Both names are optional, but an option needs at least one. An option does not need a one-letter
name, so there is no limit of one option per letter: a program can have any number of
options that only have a long name.

```scheme
(define-command-line-options parse
  [:short "-q" :arity 0 :description "quiet"]               ; short name only
  [:long "--retries" :type int :description "retry count"]  ; long name only
  [:short "-o" :long "--output" :description "output file"]) ; both
```

Its usage table (`-h`), with a long name alone lined up under the long names:

```
Usage: prog [options]

Options:
  -q                     quiet
      --retries <int>    retry count
  -o, --output <string>  output file
  -h, --help             show this help message and exit
```

A name can be a symbol when reading, `(option 'long-name)`. In the definition, symbols are accepted
too, `[:short -b :long --long-name]`, but strict R6RS readers (every `.sls` file on Chez, and files
starting with `#!r6rs`) refuse to read `-b` or `--long-name` as symbols. Strings work everywhere,
use them in portable code.

## Arity

| written     | means           | takes                                                |
|-------------|-----------------|------------------------------------------------------|
| `0`         | `(0 0)`         | a flag, no argument, and no `:type`                  |
| `n`         | `(n n)`         | exactly `n` arguments                                |
| `(min max)` |                 | between `min` and `max` arguments                    |
| `(min +)`   | `(min max-fixnum)` | at least `min`, no upper bound                    |

`(min +)` stands for the `(min,)` notation, since `,` already means `unquote` in Scheme. The `+` is matched as the ordinary `+` of `(rnrs)`, so it has to be that binding.

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

## Choices

`:choices` makes an option accept only a few values. It is another way to say how an argument is read,
so it takes the place of `:type`: giving both is a syntax error, and so is giving `:choices` to a flag.

```scheme
(define-command-line-options parse
  [:short "-f" :long "--format" :choices ("json" "text" "yaml") :description "output format"]
  [:long "--level" :choices (1 2 4) :description "verbosity level"]
  [:short "-m" :long "--mode" :arity (1 +) :choices ("a" "b" "c") :description "modes"])
```

* A choice is a string or an exact integer, and there is at least one. The value you get is the choice
  itself: `"yaml"`, or the integer `4` (no `:type int` needed). Strings and integers can be mixed.
* An argument has to match exactly, with the same case. An integer matches its usual text, so `4`
  matches `"4"` but not `"04"`; a negative one has to be escaped, `--delta '\-1'`.
* Two choices with the same text are an error (`"1"` and `1`), since the second could never be chosen.
* Every argument of an option with several arguments is checked, `-m a c`.
* A wrong value raises `argument must be one of the choices` (see [Errors](#errors)).
* The usage shows the choices in place of the type:

```
$ prog -h
Usage: prog [options]

Options:
  -f, --format {json,text,yaml}  output format
      --level {1,2,4}            verbosity level
  -m, --mode {a,b,c}...          modes
  -h, --help                     show this help message and exit

$ prog -f yaml --level 4 -m a c
("yaml" 4 ("a" "c"))

$ prog --format xml
Exception in opt-parser: argument must be one of the choices with irritants ("--format" "xml" ("json" "text" "yaml"))
```

## Required options

`:required` has no value. When the command line does not give the option, the parser raises
`missing required option` (see [Errors](#errors)), and no accessor is returned.

```scheme
(define-command-line-options parse
  [:short "-i" :long "--input" :required :description "file to read"]
  [:short "-o" :long "--output" :description "file to write"])
```

```
$ copy -i a.txt
"a.txt"                       ; (option "input")
$ copy -o b.txt
missing required option: ("--input")
```

An option counts as given when it is on the command line, even with no arguments:
a required `-o` with arity `(0 +)` is satisfied by `-o` alone. `-h` and `--help` need no
required option, they print the usage first. A flag (arity `0`) cannot be `:required`, that is
a syntax violation when the program is compiled.

## Positional arguments

The words of the command line that are not options are described by one `:positional` clause.
There is at most one. It has a name, and the fields of an option that make sense for words:
`:arity`, `:type`, `:choices` and `:description`.

```scheme
(define-command-line-options parse
  [:short "-v" :arity 0 :description "verbose"]
  [:positional "file" :arity (1 +) :description "files to read"])
```

* The name is how the program reads them, `(option "file")`, and what the usage shows, `<file>`.
  It must not start with `-`, and it must be different from the names of the options.
* `:arity` is how many words there are, `1` when it is not given. The parser raises
  `too few positional arguments` or `too many positional arguments` (see [Errors](#errors)) when
  the number is not right. A positional cannot have arity `0`.
* `:type` and `:choices` convert each word like they do for an option.
* `:short`, `:long` and `:required` are for options, they are a syntax violation in this clause.
  A positional is required when its minimum is 1 or more.
* Without a `:positional` clause the command line takes no positional words, and a word that is
  not an option raises `unexpected positional argument`.

```
prog -v a.txt b.txt           ; (option "file") => ("a.txt" "b.txt")
prog                          ; too few positional arguments
```

How the words are given on the command line is in [Command line syntax](#command-line-syntax).

# Reading the result

`(parse arguments)` returns an accessor procedure, conventionally called `option`.

| call                                    | result                                                      |
|-----------------------------------------|-------------------------------------------------------------|
| `(option "name")`                       | the value of the option, by its short or long name without the dashes |
| `(option "file")`                       | the words of the `:positional` clause, by its name          |
| `(option "help")`                       | the usage text, as a string, the same text that `--help` prints |

Symbols work as names as well, `(option 'name)`. Names that were not defined, with the dashes
(`(option "-v")`), or an integer raise an error.

What an option gives depends on its arity:

| arity                    | given                          | absent   |
|--------------------------|--------------------------------|----------|
| `0`                      | `present`                      | `absent` |
| `1` (also `(1 1)`)       | the converted value            | `#f`     |
| anything else            | the list of converted values   | `()`     |

The words of a `:positional` clause follow the same table, so with arity `1` the word itself is
returned, and with any other arity the list of words. An option that is given more than once keeps
its last occurrence. Asking for a name that was not defined, or any other kind of key, raises an error.

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

## Positional words

Options and positional words can come in any order. A word that is an option is an option wherever it
is, and a word that is not (and is not consumed as an argument of an option) is positional.
The positional words keep their order, and go to the `:positional` clause, see
[Positional arguments](#positional-arguments).
`--` ends option parsing explicitly, everything after it is positional and kept as is, and
the `--` itself is dropped.

```
prog -v in.txt out.txt        ; positional: "in.txt" "out.txt"
prog in.txt -v out.txt        ; positional: "in.txt" "out.txt", -v is present
prog -v -- -x                 ; positional: "-x"
prog in.txt -- -v             ; positional: "in.txt" "-v"   (-v is NOT the flag here)
```

An option with arity `(min max)` takes the following ordinary words until it has `max` of them, or the
next word is an option or `--`. With arity `(1 +)`, `prog a -e x y b` gives `-e` the words `"x" "y" "b"`
and the positional word `"a"`; write `prog a -e x y -- b` to keep `b` positional.
An option given twice keeps its last occurrence.

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
Usage: /tmp/demo/grep-lite.scm [options] [--] [<file>...]

Arguments:
  [<file>...]  files to search

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

`(option 'help)` returns this same text as a string, to print it from the program,
for example `(display (option 'help))`.

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
| `argument must be one of the choices` | the argument is not one of the `:choices`          | the option name, the text, the choices |
| `missing required option`          | a `:required` option is absent                        | the long name, or the short name when there is no long one |
| `too few positional arguments`     | fewer words than the `:positional` minimum            | the name of the positional |
| `too many positional arguments`    | more words than the `:positional` maximum             | the extra words        |
| `unexpected positional argument`   | a word that is not an option, and no `:positional` clause | the words          |

```scheme
(guard (e [(error? e) (display (condition-message e)) (newline) (exit 2)])
  (parse (cdr (command-line))))
```

The accessor raises `unknown option` for names that were not defined (also a name with its dashes),
and `invalid option key` for anything that is not a string or a symbol.

# A complete example

The examples above were run with this program (`grep-lite.scm`), with
`scheme --libdirs . --program grep-lite.scm <arguments>`, the output is real.

```scheme
#!r6rs
(import (rnrs (6)) (rime command-line-options))

(define-command-line-options parse
  [:short "-v" :long "--verbose" :arity 0 :description "print more details"]
  [:short "-n" :long "--count"   :arity 1 :type int :description "number of repetitions"]
  [:short "-r" :long "--ratio"   :type float :description "sampling ratio"]
  [:short "-c" :long "--color"   :type bool :description "colored output (yes/no/on/off/true/false/1/0)"]
  [:short "-e" :long "--exclude" :arity (1 +) :description "patterns to exclude"]
  [:short "-w" :long "--window"  :arity (0 2) :type int :description "context lines before [and after]"]
  [:short "-t" :long "--tag"     :type (lambda (s) (string-append "<" s ">")) :description "custom conversion"]
  [:positional "file" :arity (0 +) :description "files to search"])

(define option (parse (cdr (command-line))))
(for-each (lambda (name) (write name) (display " => ") (write (option name)) (newline))
          '("v" "n" "r" "c" "e" "w" "t" "file"))
```

```
$ grep-lite
"v" => absent
"n" => #f
"r" => #f
"c" => #f
"e" => ()
"w" => ()
"t" => #f
"file" => ()

$ grep-lite -v --count 3 -r 0.25 -c yes -e a b c -w 2 -t x in.txt out.txt
"v" => present
"n" => 3
"r" => 0.25
"c" => #t
"e" => ("a" "b" "c")
"w" => (2)
"t" => "<x>"
"file" => ("in.txt" "out.txt")

$ grep-lite in.txt -v -n 3 out.txt
"v" => present
"n" => 3
"r" => #f
"c" => #f
"e" => ()
"w" => ()
"t" => #f
"file" => ("in.txt" "out.txt")

$ grep-lite --count=3 --exclude=a,b,c --window=1,2 -- -v file
"v" => absent
"n" => 3
"r" => #f
"c" => #f
"e" => ("a" "b" "c")
"w" => (1 2)
"t" => #f
"file" => ("-v" "file")

$ grep-lite -t '\-dash' '\-file'
"v" => absent
"n" => #f
"r" => #f
"c" => #f
"e" => ()
"w" => ()
"t" => "<-dash>"
"file" => ("-file")

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

# Implementation

Reading and writing are separate steps, and syntax and semantics are kept apart. The clauses are
first read into `option-ast` records, which say what each option means and know nothing about how
it was written; the definition is then written from the records only. The same record type is
used at runtime: the generated code builds the records again and `__runtime.sls` works with them.
The exported macro is just those two calls.

| file (`rime/command-line-options/`) | job                                                                          |
|-------------------------------------|------------------------------------------------------------------------------|
| `../command-line-options.sls`       | the exported macro: `(generate-definition parser options positional)`, from `(parse-options clauses)` |
| `__parse.sls`                       | phase 1, read: walks the clauses and fields by pattern matching, builds records |
| `__ast.sls`                         | the `option-ast` and `positional-ast` records, and the semantic rules (names, arity, converter, duplicates) |
| `__codegen.sls`                     | phase 2, write: generates the definition, which builds the same records again at runtime; never reads user syntax |
| `__keywords.sls`                    | the field keywords `:short :long :arity :type :choices :description :required :positional` |
| `__runtime.sls`                      | the runtime: parses the command line, builds the accessor, prints the usage; the builtin converters |

A converter is an object with a label for the usage and a conversion that raises its own error, so the
runtime does not know which kinds there are. Adding a kind of converter means one constructor in
`__runtime.sls` (like `make-choice-converter`); a builtin type is also an entry in `builtin-converters`.
Adding a field to the clause syntax means a keyword in `__keywords.sls` and a pattern in `__parse.sls`,
a field in the record and a rule in `__ast.sls` if it has one, and a line in `__codegen.sls`.

# Tests

Each module has its own test file, `make test-chez/rime/command-line-options/<name>`:

* `test/rime/command-line-options/__parse-test.sls`: reading, syntax to AST
* `test/rime/command-line-options/__ast-test.sls`: the semantic rules, on records built by hand
* `test/rime/command-line-options/__codegen-test.sls`: writing, AST to code, on records built by hand
* `test/rime/command-line-options-test.sls`: the macro and the parser end to end

`make test-chez` runs everything, and the same with `test-guile`. The real `-h` path, which calls `exit`,
is exercised on Chez and on Guile.
