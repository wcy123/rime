# RIME

A random set of scheme libraries in R6RS.


# LOOP facility

`(rime loop)` library mimic the common lisp loop facility with many
modifications, while the bacis idea is similar, also borrow some ideas
from Python list comprehension. [more details](doc/loop.md)


# Command line options

`(rime command-line-options)` exports one macro, `define-command-line-options`, that declares
options (short and long names, arity, type, description) and parses command line arguments, with
positional arguments and an automatic `-h` / `--help`. [more details](doc/command-line-options.md)
