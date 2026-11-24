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

(option "verbose")                     ; => #t
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
| `:metavar "name"`    | what the usage shows for an argument, see [Metavar](#metavar), not allowed with arity `0` | the type |

The keywords `:short :long :arity :type :choices :description :required :metavar :positional` are exported by the library, so import it whole
(`(import (rime command-line-options))`); `(only (rime command-line-options) define-command-line-options)`
would leave them unbound and the clauses would be rejected.

Fields can be written in any order. An option needs a `:short` name, a `:long` name, or both.
Mistakes in the definition (unknown field, no name, duplicated name, `:type` on a flag, `min > max`, ...) are reported when the program is compiled,
as syntax violations.

## Names

Option names are strings: `:short "-b"` (a single dash) and `:long "--long-name"` (two dashes).
Names must not contain `=`, `,` or whitespace. `-h`, `--help` and the name `usage` are reserved.
There is no clustering, `-vq` is an ordinary word, not `-v -q`.

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
  itself: `"yaml"`, or the integer `4` (no `:type int` needed). The choices of one option are all strings
  or all integers, so the value always has the same type: a list that mixes them, `(1 "2")`, is a syntax
  error.
* An argument has to match exactly, with the same case. An integer matches its usual text, so `4`
  matches `"4"` but not `"04"`; a negative one is written as it is, `--delta -1` (see
  [Words that start with `-`](#words-that-start-with--)).
* Two choices that are the same are an error, `("a" "a")`, since the second could never be chosen.
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

## Metavar

The usage shows the type of an argument, `<string>`, `<int>`. `:metavar` says what the argument is
instead: the name is shown in angle brackets, as many times as the option takes arguments.

```scheme
(define-command-line-options parse
  [:short "-i" :long "--input" :metavar "file" :description "file to read"]
  [:long "--format" :metavar "fmt" :choices ("json" "text") :description "output format"]
  [:short "-e" :long "--exclude" :arity (1 +) :metavar "pattern" :description "patterns to exclude"]
  [:short "-v" :arity 0 :description "verbose"])
```

```
$ prog -h
Usage: /tmp/demo/prog [options]

Options:
  -i, --input <file>          file to read
      --format <fmt>          output format
  -e, --exclude <pattern>...  patterns to exclude
  -v                          verbose
  -h, --help                  show this help message and exit
```

* It only changes the usage. The arguments are read, converted and checked as before, and `--format`
  above still accepts only `json` and `text`. The metavar replaces what the usage would show instead,
  `<string>`, or `{json,text}` for `:choices`; say the choices in the `:description` if you want them shown.
* A flag has no argument, so `:metavar` on a flag (arity `0`) is a syntax violation.
* A positional is already shown by its name, `<file>`, and has no `:metavar`.

## Positional arguments

The words of the command line that are not options are described by `:positional` clauses, one
for each part of the command line, in the order they are written. A clause has a name, and the
fields of an option that make sense for words: `:arity`, `:type`, `:choices` and `:description`.

```scheme
#!r6rs
(import (rnrs (6)) (rime command-line-options))

(define-command-line-options parse
  [:short "-v" :arity 0 :description "verbose"]
  [:positional "source" :arity (1 +) :description "files to copy"]
  [:positional "dest" :description "where to copy them"])

(define option (parse (cdr (command-line))))
(write (option "source")) (newline)
(write (option "dest")) (newline)
```

```
$ cp-lite a b c
("a" "b")
"c"

$ cp-lite -v a b
("a")
"b"

$ cp-lite a
Exception in opt-parser: too few positional arguments with irritant "dest"

$ cp-lite
Exception in opt-parser: too few positional arguments with irritant "source"
```

* The name is how the program reads the words, `(option "dest")`, and what the usage shows, `<dest>`.
  It must not start with `-`, it must be different from the other positionals, and from the names of
  the options.
* `:arity` is how many words the positional takes, `1` when it is not given. A positional cannot
  have arity `0`. The value follows the same rule as an option: with arity `1` the word itself,
  with any other arity the list of words.
* `:type` and `:choices` convert each word like they do for an option.
* `:short`, `:long` and `:required` are for options, they are a syntax violation in this clause.
  A positional is required when its minimum is 1 or more.
* The words are shared out to the positionals in the order of the clauses. At most one positional
  takes a variable number of words (its minimum is less than its maximum), all the others have an exact
  arity. Each gets its exact number of words, and the variable one gets the words that are left.
  So the words can only be shared out in one way, and `(0 1)` next to `(1 +)` is a syntax
  violation instead of a guess. In the example, `source` is `(1 +)` and `dest` is `1`, so `dest`
  is always the last word.
* When there are not enough words, the error names the first positional that lacks words
  (`too few positional arguments`). When there are too many, the error gives the words that no
  positional takes (`too many positional arguments`). A variable positional with `+` never has too many.
* Without a `:positional` clause the command line takes no positional words, and a word that is
  not an option raises `unexpected positional argument`.

How the words are given on the command line is in [Command line syntax](#command-line-syntax).

# Reading the result

`(parse arguments)` returns an accessor procedure, conventionally called `option`.

| call                                    | result                                                      |
|-----------------------------------------|-------------------------------------------------------------|
| `(option "name")`                       | the value of the option, by its short or long name without the dashes |
| `(option "file")`                       | the words of a `:positional` clause, by its name            |
| `(option "help")`                       | `#t` when `-h` or `--help` was given, `#f` otherwise        |
| `(option "usage")`                      | the usage text, as a string, the same text that `--help` prints |

Symbols work as names as well, `(option 'name)`. Names that were not defined, with the dashes
(`(option "-v")`), or an integer raise an error.

What an option gives depends on its arity:

| arity                    | given                          | absent   |
|--------------------------|--------------------------------|----------|
| `0`                      | `#t`                           | `#f`     |
| `1` (also `(1 1)`)       | the converted value            | `#f`     |
| anything else            | the list of converted values   | `()`     |

The words of a `:positional` clause follow the same table, so with arity `1` the word itself is
returned, and with any other arity the list of words. A repeated option is described in
[Repeating an option](#repeating-an-option). Asking for a name that was not defined, or any other kind of key, raises an error.

## Repeating an option

An option that is given more than once follows its arity:

* An option that takes several arguments, `max` above 1 (`2`, `(0 2)`, `(1 +)`, ...), collects the
  arguments of all its occurrences in one flat list, in order. The total is checked when the whole
  command line has been read: at least `min` and at most `max`, otherwise it is an error
  (`too few` or `too many arguments for option`). With no upper limit, `(1 +)`, only the minimum can fail.
* Any other option, a flag or an option with at most one argument (`0`, `1`, `(0 1)`), keeps its last
  occurrence. This is what argparse and click do, and it lets a wrapper or an alias set a default that
  the user can override.

```scheme
(define-command-line-options parse
  [:short "-n" :long "--count" :type int :description "repeat count"]
  [:short "-s" :long "--size" :arity 2 :type int :description "width and height"]
  [:short "-I" :long "--include" :arity (1 +) :description "directories to search"]
  [:positional "file" :arity (0 +)])
```

```
$ prog -n 1 -n 2                        ; one argument: the last one wins
"count" => 2

$ prog -s 10 20
"size" => (10 20)

$ prog -s 10 -s 20                      ; several arguments: they are collected
"size" => (10 20)

$ prog --size=10 --size=20              ; = gives one argument each time
"size" => (10 20)

$ prog -s 10 20 -s 30 40                ; the total is 4, and -s takes 2
Exception in opt-parser: too many arguments for option with irritant "--size"

$ prog -s 10                            ; the total is 1
Exception in opt-parser: too few arguments for option with irritant "--size"

$ prog -I a -I b                        ; no upper limit: they add up
"include" => ("a" "b")

$ prog -I a b -I c
"include" => ("a" "b" "c")

$ prog -I a -I b main.c                 ; the last -I also takes main.c
"include" => ("a" "b" "main.c")
"file" => ()

$ prog -I a -I=b main.c                 ; = takes exactly one argument
"include" => ("a" "b")
"file" => ("main.c")
```

* The value of an option that takes several arguments is always a flat list of the same kind of value,
  `(10 20)` however many occurrences it came from; the occurrences are not kept apart.
* Each occurrence is converted and checked on its own, so a bad value in the second one is
  `invalid argument value`.
* An option that takes several arguments takes every ordinary word after it, up to its maximum, also
  after the last occurrence: `-I a -I b main.c` gives `main.c` to `-I`. Write `-I=b main.c`, which takes
  exactly one argument, or put `--` before the file.
* A default given to the accessor is used only when the option was not given at all.

## A default for an option that was not given

`(option "count" 3)` is the same as `(option "count")`, except that it gives `3` when the option was not
on the command line. The default is your own Scheme value: it is returned as it is, not converted and not
checked against the type or the choices, so write `3`, not `"3"`. It can be computed when the program runs,
`(option "output" (current-directory))`.

```scheme
(define-command-line-options parse
  [:short "-n" :long "--count" :type int :description "repeat count"]
  [:short "-f" :long "--format" :choices ("json" "text") :description "output format"]
  [:short "-b" :long "--bold" :type bool :description "bold text"]
  [:short "-o" :long "--output" :arity (0 +) :description "output files"]
  [:positional "file" :arity (0 +)])

(define option (parse (cdr (command-line))))
(option "count" 1)  (option "format" "text")  (option "bold" 'unset)  (option "output" '("-"))  (option "file" '("stdin"))
```

```
$ prog
"count" => 1
"format" => "text"
"bold" => unset
"output" => ("-")
"file" => ("stdin")

$ prog -n 5 -f json -b off -o=a.txt report.txt
"count" => 5
"format" => "json"
"bold" => #f
"output" => ("a.txt")
"file" => ("report.txt")

$ prog -o
"count" => 1
"format" => "text"
"bold" => unset
"output" => ()
"file" => ("stdin")
```

* The default is used only when the option was not given. `-o` alone is given, with no arguments, so it
  gives `()` and not the default. A positional that got no words counts as not given.
* It tells "not given" from "given as false": `-b off` gives `#f`, and no `-b` gives the default `unset`.
* The default does not hide a mistake: `(option "nope" 1)` is still `unknown option`.
* The usage text cannot show a default. Say it in the `:description` if you want it shown.

# Command line syntax

```
prog -v                       ; flag
prog -n 3                     ; short name, argument follows
prog --count 3                ; long name, argument follows
prog --count=3                ; long name with =
prog -n=3                     ; short name with =
prog -e a b c                 ; several arguments
prog --exclude=a file          ; with =, exactly one argument, "file" is a positional word
```

* An option with `(min max)` arguments takes the following words until it has `max` of them, or the
  next word is an option, or the word is `--`. Fewer than `min` is an error.
* With `=`, the text after the first `=` is exactly one argument, whatever it contains: commas, spaces,
  another `=`, a leading `-`. This is the same rule as in getopt, argparse and click, for every arity.
  There is no comma list. The words that follow are not consumed, so `=` is the way to stop an option that
  takes a variable number of arguments (`--exclude=a file` leaves `file` positional, `--exclude a file`
  would take it), and the way to give an optional argument without ambiguity, `--window=2`.
* An option that needs two or more arguments can use `=` once for each argument, `--pair=3 --pair=4`,
  see [Repeating an option](#repeating-an-option). `--pair=3,4` is one argument, `too few arguments for
  option`: write `--pair 3 4`.
* A flag does not accept `=`.

```
$ prog '--title=Hello, World'       ; one argument, the comma is part of it
"title" => "Hello, World"

$ prog --exclude=a file             ; one argument, then a positional word
"exclude" => ("a")
"file" => ("file")

$ prog --exclude a b file           ; a variable number of arguments takes them all
"exclude" => ("a" "b" "file")
"file" => ()

$ prog --window=2 file
"window" => (2)
"file" => ("file")

$ prog --count=1,2                  ; --count takes one integer, and 1,2 is not one
Exception in opt-parser: invalid argument value with irritants ("--count" "1,2")

$ prog --pair=3,4                   ; --pair needs two arguments, = gives one
Exception in opt-parser: too few arguments for option with irritant "--pair"

$ prog --pair 3 4
"pair" => ("3" "4")
```

## Positional words

Options and positional words can come in any order. A word that is an option is an option wherever it
is, and a word that is not (and is not consumed as an argument of an option) is positional.
The positional words keep their order, and go to the `:positional` clauses, see
[Positional arguments](#positional-arguments).
`--` ends option parsing explicitly, everything after it is positional and kept as is, and
the `--` itself is dropped.

```
prog -v in.txt out.txt        ; positional: "in.txt" "out.txt"
prog in.txt -v out.txt        ; positional: "in.txt" "out.txt", -v is `#t`
prog -v -- -x                 ; positional: "-x"
prog in.txt -- -v             ; positional: "in.txt" "-v"   (-v is NOT the flag here)
```

An option with arity `(min max)` takes the following ordinary words until it has `max` of them, or the
next word is an option or `--`. With arity `(1 +)`, `prog a -e x y b` gives `-e` the words `"x" "y" "b"`
and the positional word `"a"`; write `prog a -e x y -- b` to keep `b` positional.
A repeated option is described in [Repeating an option](#repeating-an-option).

## Words that start with `-`

A word is an option only when it is the name of an option that the program defines (`-n`, `--count`,
`--count=3`), or `-h` and `--help`. Every other word is an ordinary word, whatever it starts with: a
positional word, or the argument of the option before it. This covers negative numbers (`-5`,
`-1.5`) and any other word that is not defined (`-z`, `--typo`).

```
$ prog -n -5 -x -1.5              ; a number is an ordinary word
"count" => -5
"ratio" => -1.5

$ prog -z file                    ; -z is not defined: a positional word
"file" => ("-z" "file")

$ prog --verbos file              ; a typo is a positional word too
"file" => ("--verbos" "file")

$ prog -n -v                      ; -v is defined, so it is an option
Exception in opt-parser: too few arguments for option with irritant "-n"

$ prog -s -z                      ; an undefined word is the argument
"name" => "-z"

$ prog -- -v                      ; after -- everything is a word
"file" => ("-v")

$ prog -s=-v                      ; after = anything is the argument
"name" => "-v"

$ prog -s '\-v'                   ; the escape gives the word -v
"name" => "-v"
```

* An option that has the name of a value cannot be given as that value: if the program defines
  `[:short "-5"]`, `-5` is that option. Give the word after `--`, after `=` (`--name=-5`), or with the
  escape `\-5`, which is the word `-5`. The backslash has to survive the shell: write `'\-5'` or `\\-5`.
* A mistyped option is not an error, it is a word. With a `:positional` clause that takes any
  number of words it becomes one of them (`--verbos file` above), and an option before it takes it as an
  argument when it takes a variable number of them. A program that declares no positional word
  rejects it, `unexpected positional argument`.
* A lone `-` is a word, not an option, and so is any word after `--`.
* The compact forms `-j4` and `-vq` are ordinary words too: write `-j 4` and `-v -q`, see
  [Recipes](#recipes) (short forms, verbosity).

# Help

`-h` and `--help` are always available. They are a flag like the others: `parse` does not print or exit,
it stops reading at `-h`, skips the checks that need the rest (`:required`, the positional words), and
`(option "help")` is `#t`. `parse-or-exit` is the usual reaction: it prints the usage table and does `(exit 0)`.
The `$ prog -h` outputs in this document are from a program that reads its command line with `parse-or-exit`.
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

`(option "usage")` returns this same text as a string, to print it from the program, for example
`(display (option "usage"))`. It is there for any command line, also when `-h` was not given.

`(option "help")` is `#t` when `-h` or `--help` was given. A program that wants to print the help
somewhere else, or to exit with another code, reads it after `parse`:

```scheme
(define option (parse (cdr (command-line))))
(when (option "help")
  (display (option "usage") (current-error-port))
  (exit 0))
```

`-h` skips the checks that need the rest of the command line, so this works when an option is required and
missing. A wrong command line raises a condition, see [Errors](#errors).

The placeholder shows the arity: `<int> <int>` for 2, `<string>...` for `(1 +)`, `[<string>...]` for
`(0 +)`, `[<int>] [<int>]` for `(0 2)`. A custom `:type` procedure is shown as `<value>`.
The program name is the first element of `(command-line)`, the script as it was given. When there is no script
(a REPL, `--eval`), `(command-line)` is `("")` and the name is `program`.

There is no place in the usage for a sentence about the program, and no built-in `--version`: the program
does both with `(option "help")` and a look at its arguments, see [Recipes](#recipes).

# Errors

Problems with the command line raise a `&command-line-error` condition. It is also an `&error` with
the who `opt-parser`, a message and details, what `(error 'opt-parser message detail ...)` makes: the
message says what went wrong, and the details are the values it is about, the option name, the text
that did not fit, and so on. So `error?`, `condition-message` and `condition-irritants` (the R6RS name
for the details) work on it. The library never exits by itself, only `parse-or-exit` below does.

| call                              | result                                                  |
|-----------------------------------|---------------------------------------------------------|
| `(command-line-error? e)`         | `#t` for the problems of the table below, `#f` for any other condition |
| `(command-line-error-usage e)`    | the usage text of the parser that raised it, the same text as `(option "usage")` |

| message                            | when                                                  | details                |
|------------------------------------|-------------------------------------------------------|------------------------|
| `too few arguments for option`     | fewer than `min` arguments, for an option that takes several: in total, from all its occurrences | the option name        |
| `too many arguments for option`    | more than `max` arguments in total, from several occurrences of an option that takes several | the option name        |
| `option does not take arguments`   | `--flag=1` on an arity 0 option                       | the option name        |
| `invalid argument value`           | the conversion failed                                 | the option name, the text |
| `argument must be one of the choices` | the argument is not one of the `:choices`          | the option name, the text, the choices |
| `missing required option`          | a `:required` option is absent                        | the long name, or the short name when there is no long one |
| `too few positional arguments`     | fewer words than the `:positional` minimums           | the name of the first positional that lacks words |
| `too many positional arguments`    | more words than the `:positional` maximums            | the words that no positional takes |
| `unexpected positional argument`   | a word that is not an option, and no `:positional` clause | the words          |

The usage is in the condition, so it can be printed when there is no accessor, which is the case when
the command line is wrong. A program that only wants the usual reaction uses `parse-or-exit`:

```scheme
(define option (parse-or-exit parse (cdr (command-line))))
```

It returns the accessor. At `-h` or `--help` it prints the usage to the output port and exits with `0`, and
when the command line is wrong it prints a sentence, a blank line and the usage to the error port, and exits
with `2`. Other errors are not caught.

```
$ copy -n abc -i a.txt
copy: invalid argument "abc" for -n

Usage: copy [options]

Options:
  -i, --input <string>  file to read
  -n, --count <int>     number of repetitions
  -h, --help            show this help message and exit
[exit 2]
```

The sentence says which option and which text. The condition keeps its message and its details, which are
what a program reads with `condition-message` and `condition-irritants`; the sentence is made only for
`parse-or-exit` (and `format-command-line-error`, which gives the same text):

| message | what a person reads, for example |
|---|---|
| `invalid argument value` | `invalid argument "abc" for -n` |
| `argument must be one of the choices` | `"xml" is not one of json, text (for --format)` |
| `too few arguments for option` | `too few arguments for -n` |
| `too many arguments for option` | `too many arguments for --pair` |
| `option does not take arguments` | `--verbose does not take arguments` |
| `missing required option` | `missing required option --input` |
| `too few positional arguments` | `missing positional argument <dest>` |
| `too many positional arguments` | `too many positional arguments: b c` |
| `unexpected positional argument` | `unexpected positional argument: a` |

A word with a space in it is shown in quotes, and a message that the table does not know is printed as
`message: detail ...`.

A program that wants a different reaction catches the condition itself:

```scheme
(define option
  (guard (e [(command-line-error? e)
             (display (condition-message e) (current-error-port)) (newline (current-error-port))
             (display (command-line-error-usage e) (current-error-port))
             (exit 64)])
    (parse (cdr (command-line)))))
```

The accessor raises `unknown option` for names that were not defined (also a name with its dashes);
the parser never does, a word that is not a defined option is an ordinary word.
The accessor raises `invalid option key` for anything that is not a string or a symbol. `unknown option`
carries the name as it was given, and then a hint about what to do: for a name that starts with a dash,
the text `names are read without the dashes`, and for any other name, the list of the names that exist
(the options in the order they were defined, short name first, then the positionals).

```
(option "verbos")     ; unknown option, details: "verbos" ("v" "verbose" "o" "output" "name" "file")
(option "--verbose")  ; unknown option, details: "--verbose" "names are read without the dashes"
```

These accessor errors are mistakes of the program, not of the command line: they are ordinary
errors, and `command-line-error?` is `#f` for them.

# Recipes

The library leaves some things to the program, because the program does them in a few lines with what the library
already gives. Each recipe is a complete program, and the output is from real runs.

## A program description and an epilog

The usage has no place for a sentence about the program. The program prints its own text around the usage when
`(option "help")` says that `-h` was given (see [Help](#help)), and reads `(option "usage")` for the text.
`parse-or-exit` would print the usage itself at `-h`, so this program calls `parse` and reports a wrong command
line the same way, with the condition and its usage.

```scheme
#!r6rs
(import (rnrs (6)) (rime command-line-options))

(define-command-line-options parse
  [:short "-v" :long "--verbose" :arity 0 :description "print each file"]
  [:positional "source" :arity (1 +) :description "files to copy"]
  [:positional "dest" :description "where to copy them"])

;; a wrong command line: the message, a blank line and the usage, on the error port; exit 2
(define option
  (guard (e [(command-line-error? e)
             (display (condition-message e) (current-error-port))
             (newline (current-error-port))
             (display (command-line-error-usage e) (current-error-port))
             (exit 2)])
    (parse (cdr (command-line)))))

;; -h: the program's own text around the usage
(when (option "help")
  (display "Copy files to a directory.\n\n")
  (display (option "usage"))
  (display "\nExample: cp-lite a.txt b.txt dest/\n")
  (exit 0))

(write (option "source")) (newline)
(write (option "dest")) (newline)
```

```
$ prog -h
Copy files to a directory.

Usage: prog [options] [--] <source>... <dest>

Arguments:
  <source>...  files to copy
  <dest>       where to copy them

Options:
  -v, --verbose  print each file
  -h, --help     show this help message and exit

Example: cp-lite a.txt b.txt dest/

$ prog a.txt b.txt dest/
("a.txt" "b.txt")
"dest/"

$ prog a.txt
too few positional arguments
Usage: prog [options] [--] <source>... <dest>

Arguments:
  <source>...  files to copy
  <dest>       where to copy them

Options:
  -v, --verbose  print each file
  -h, --help     show this help message and exit
[exit 2]
```

* The text can come from anywhere, a file or a procedure, and the program can print it to the error port or exit with another code.
* A program that is happy with the usual `-h` uses `parse-or-exit` and writes none of this.

## `--version`

There is no built-in `--version`. A program looks for it in the raw arguments before the parse. That also works when
an option is required: the parser would stop with `missing required option` before it could answer. The search stops
at `--`, after which every word is literal.

```scheme
#!r6rs
(import (rnrs (6)) (rime command-line-options))

(define-command-line-options parse
  [:short "-i" :long "--input" :required :description "file to read"])

;; --version has to work without the required option, so it is looked for before the parse;
;; the search stops at --, after which every word is literal
(define (asks-for-version? arguments)
  (and (pair? arguments)
       (not (string=? (car arguments) "--"))
       (or (string=? (car arguments) "--version")
           (asks-for-version? (cdr arguments)))))

(define arguments (cdr (command-line)))
(when (asks-for-version? arguments)
  (display "prog 1.2.3\n")
  (exit 0))

(define option (parse-or-exit parse arguments))
(write (option "input")) (newline)
```

```
$ prog --version
prog 1.2.3

$ prog -i a.txt
"a.txt"

$ prog
prog: missing required option --input

Usage: prog [options]

Options:
  -i, --input <string>  file to read
  -h, --help            show this help message and exit
[exit 2]
```

* The version is a string of the program; nothing in the library has to know it.

## Defaults from the environment

The default given to the accessor, `(option "output" default)`, is computed when the program runs, so it can come from
the environment. The command line wins, then the environment, then the last resort. `getenv` is not part of R6RS:
it comes from your implementation, `(only (chezscheme) getenv)` here and `getenv` of `(guile)` on Guile.

```scheme
#!r6rs
(import (rnrs (6)) (only (chezscheme) getenv) (rime command-line-options))

(define-command-line-options parse
  [:short "-o" :long "--output" :description "output file"])

(define option (parse-or-exit parse (cdr (command-line))))

;; the command line first, then the environment, then "a.out"
(display (option "output" (or (getenv "CP_OUTPUT") "a.out")))
(newline)
```

```
$ prog
a.out

$ CP_OUTPUT=env.out prog
env.out

$ CP_OUTPUT=env.out prog -o cli.out
cli.out
```

* The default is used only when the option was not given, see [A default for an option that was not given](#a-default-for-an-option-that-was-not-given).

## Options that exclude each other

The library does not know that two options cannot be given together. The program checks after the parse. A flag is
`#t` or `#f`, so `and` is enough, and the program decides the message and the exit code.

```scheme
#!r6rs
(import (rnrs (6)) (rime command-line-options))

(define-command-line-options parse
  [:long "--json" :arity 0 :description "write json"]
  [:long "--text" :arity 0 :description "write text"])

(define option (parse-or-exit parse (cdr (command-line))))

;; flags are #t or #f, so and works
(when (and (option "json") (option "text"))
  (display "prog: --json and --text exclude each other\n" (current-error-port))
  (exit 2))
(display (if (option "json") "json" "text"))
(newline)
```

```
$ prog --json
json

$ prog --text
text

$ prog --json --text
prog: --json and --text exclude each other
[exit 2]
```

## Subcommands

A program with commands (`copy`, `remove`) uses one parser for each command and chooses it by the first word. Each
command has its own options, its own usage and its own errors.

```scheme
#!r6rs
(import (rnrs (6)) (rime command-line-options))

(define-command-line-options parse-copy
  [:short "-v" :arity 0 :description "print each file"]
  [:positional "source" :arity (1 +) :description "files to copy"]
  [:positional "dest" :description "where to copy them"])

(define-command-line-options parse-remove
  [:long "--force" :arity 0 :description "do not ask"]
  [:positional "file" :arity (1 +) :description "files to remove"])

;; one parser per command, chosen by the first word
(define arguments (cdr (command-line)))
(cond
 [(null? arguments)
  (display "usage: prog copy|remove ...\n" (current-error-port))
  (exit 2)]
 [(string=? (car arguments) "copy")
  (let ([option (parse-or-exit parse-copy (cdr arguments))])
    (write (list 'copy (option "source") (option "dest"))) (newline))]
 [(string=? (car arguments) "remove")
  (let ([option (parse-or-exit parse-remove (cdr arguments))])
    (write (list 'remove (option "force") (option "file"))) (newline))]
 [else
  (display "prog: unknown command " (current-error-port))
  (display (car arguments) (current-error-port))
  (newline (current-error-port))
  (exit 2)])
```

```
$ prog copy a b dest/
(copy ("a" "b") "dest/")

$ prog remove --force x y
(remove #t ("x" "y"))

$ prog remove
prog: missing positional argument <file>

Usage: prog [options] [--] <file>...

Arguments:
  <file>...  files to remove

Options:
      --force  do not ask
  -h, --help   show this help message and exit
[exit 2]

$ prog frobnicate
prog: unknown command frobnicate
[exit 2]

$ prog
usage: prog copy|remove ...
[exit 2]
```

* The first word is not an option of any parser; the program reads it itself and passes the rest on.

## A verbosity level

`-vvv` is not read as a count. A level is an option with a number, `-v 3`, with the accessor's default for when it is
not given. The `:metavar` shows what the number is in the usage.

```scheme
#!r6rs
(import (rnrs (6)) (rime command-line-options))

(define-command-line-options parse
  [:short "-v" :long "--verbose" :type int :metavar "level" :description "how much to print, 0 to 3"])

(define option (parse-or-exit parse (cdr (command-line))))

;; 0 when -v is not given
(display "verbosity ")
(display (option "verbose" 0))
(newline)
```

```
$ prog
verbosity 0

$ prog -v 3
verbosity 3

$ prog --verbose=2
verbosity 2

$ prog -v
prog: too few arguments for -v

Usage: prog [options]

Options:
  -v, --verbose <level>  how much to print, 0 to 3
  -h, --help             show this help message and exit
[exit 2]
```

* `-v` alone is `too few arguments for option`: the level has to be written.

## Short forms

The compact forms `-j4` and `-vq` are not read as `-j 4` and `-v -q`. A word that is not the name of a defined option is
an ordinary word (see [Words that start with `-`](#words-that-start-with--)), so the compact forms become file names
and the options are not set. Write the options separately:

```scheme
#!r6rs
(import (rnrs (6)) (rime command-line-options))

(define-command-line-options parse
  [:short "-j" :long "--jobs" :type int :description "number of jobs"]
  [:short "-v" :arity 0 :description "verbose"]
  [:short "-q" :arity 0 :description "quiet"]
  [:positional "file" :arity (0 +)])

(define option (parse-or-exit parse (cdr (command-line))))
(for-each (lambda (name) (write name) (display " => ") (write (option name)) (newline))
          '("jobs" "v" "q" "file"))
```

```
$ prog -j 4 -v -q a.txt
"jobs" => 4
"v" => #t
"q" => #t
"file" => ("a.txt")

$ prog -j4 -vq a.txt
"jobs" => #f
"v" => #f
"q" => #f
"file" => ("-j4" "-vq" "a.txt")
```

* In the second run nothing is reported: `-j4` and `-vq` are two file names. A program that declares no `:positional` clause rejects them with `unexpected positional argument`.

## Catching a wrong name early

The names given to the accessor are checked when the accessor is called, not when the program is compiled. The macro that
defines the parser does not know which variable holds the accessor, so it cannot see that `(option "cuont")` is a typo.
Read every name the program uses once, right after the parse, so that a wrong name fails when the program starts,
and not in a branch that runs once a month. The error says which names exist.

```scheme
#!r6rs
(import (rnrs (6)) (rime command-line-options))

(define-command-line-options parse
  [:short "-i" :long "--input" :description "file to read"]
  [:short "-c" :long "--count" :type int :description "repeat count"])

(define option (parse-or-exit parse (cdr (command-line))))

;; every name the program uses, read once right after the parse: a wrong name fails here, at start
(for-each (lambda (name) (option name)) '("input" "count" "cuont"))

;; ... the rest of the program
(display "running\n")
```

```
$ prog -i a.txt
Exception in opt-parser: unknown option with irritants ("cuont" ("i" "input" "c" "count"))
[exit 255]
```

* The same list works in a test of the program: parse an empty command line, read every name, and check that nothing raises.

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
"v" => #f
"n" => #f
"r" => #f
"c" => #f
"e" => ()
"w" => ()
"t" => #f
"file" => ()

$ grep-lite -v --count 3 -r 0.25 -c yes -e a b c -w 2 -t x in.txt out.txt
"v" => #t
"n" => 3
"r" => 0.25
"c" => #t
"e" => ("a" "b" "c")
"w" => (2)
"t" => "<x>"
"file" => ("in.txt" "out.txt")

$ grep-lite in.txt -v -n 3 out.txt
"v" => #t
"n" => 3
"r" => #f
"c" => #f
"e" => ()
"w" => ()
"t" => #f
"file" => ("in.txt" "out.txt")

$ grep-lite --count=3 --exclude a b --window 1 2 -- -v file
"v" => #f
"n" => 3
"r" => #f
"c" => #f
"e" => ("a" "b")
"w" => (1 2)
"t" => #f
"file" => ("-v" "file")

$ grep-lite -t '\-dash' '\-file'
"v" => #f
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

$ grep-lite -n -v
Exception in opt-parser: too few arguments for option with irritant "-n"

$ grep-lite --window=1,2
Exception in opt-parser: invalid argument value with irritants ("--window" "1,2")

$ grep-lite --count=1,2
Exception in opt-parser: invalid argument value with irritants ("--count" "1,2")

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
| `__keywords.sls`                    | the field keywords `:short :long :arity :type :choices :description :required :positional :metavar` |
| `__converter.sls`                   | the `converter` record: a label for the usage and a conversion that raises its own error |
| `__format-usage.sls`                | the usage text from the option and positional records, `(format-usage specs program positionals)` |
| `__runtime.sls`                      | the runtime: parses the command line, builds the accessor; the `&command-line-error` condition and `parse-or-exit`; the builtin converters |

A converter (`__converter.sls`) is an object with a label for the usage and a conversion that raises its own
error, so the runtime does not know which kinds there are. Adding a kind of converter means one constructor in
`__runtime.sls` (like `make-choice-converter`); a builtin type is also an entry in `builtin-converters`.
Adding a field to the clause syntax means a keyword in `__keywords.sls` and a pattern in `__parse.sls`,
a field in the record and a rule in `__ast.sls` if it has one, and a line in `__codegen.sls`.

The reader sets each field of a clause at most once: the procedures it uses,
`option-ast-<field>-set-if-not-given-yet!`, call `on-duplicate` for a field that was given already, and they
are generated from the list of fields of each record by `define-field-setters` in `__ast.sls`.

# Tests

One test file, `test/rime/command-line-options-test.sls`, run with
`make test-chez/rime/command-line-options-test` (and `test-guile/...`). Every test goes through the
exported macro, so all three layers are exercised the way a program uses them: a definition is
expanded for real, and the parser it defines is run. There are no tests of the internal modules.

| what                          | how it is tested                                                          |
|-------------------------------|---------------------------------------------------------------------------|
| the syntax and the rules of a definition | `check-definition-rows`: a table of definitions with the message of the syntax violation each one has to give, valid definitions are in the same tables so that a rule cannot pass by rejecting everything. `definition-error-form` checks which part of the definition the error points at |
| the generated code            | the behaviour of the parser it defines: types, arity, `:required`, positionals |
| the parser at runtime         | command lines in, values and errors out; the specs can also be built by hand with `make-option-ast`, for the converters and the usage |
| the usage and `-h`            | the exact text; the real `-h` path of `parse-or-exit`, which calls `exit`, is exercised on Chez and on Guile |

A new rule of the definition syntax is one more row in a table, with its message. The message is
compared as a prefix, so adding a field to the list in "unknown field ... (expected ...)" does not
break the tests.
