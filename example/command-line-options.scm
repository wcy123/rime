#!r6rs
;; Run from the repository root:
;;   scheme --libdirs . --program example/command-line-options.scm -v --count 3 -e a b -- file.txt
;;   guile --r6rs -L . example/command-line-options.scm -v --count 3 -e a b -- file.txt
;;   ... example/command-line-options.scm -h
(import (rnrs (6)) (rime command-line-options))

(define-command-line-options parse
  [:short "-v" :long "--verbose" :arity 0
   :description "print more details about what is going on while the program runs"]
  [:short "-n" :long "--count" :type int
   :description "how many times to repeat the work; this is a whole number, and the default is 1.\nUse 0 to only check the arguments without doing any work."]
  [:short "-e" :long "--exclude" :arity (1 +)
   :description "patterns to exclude, one or more, for example:\n  -e '*.tmp' '*.bak' '*~'\nAn argument that starts with a dash has to be escaped with a backslash."]
  [:short "-f" :long "--format" :choices ("json" "text" "yaml")
   :description "output format, one of the choices shown in the usage (the argument is checked)"]
  [:long "--retries" :type int :default 3
   :description "how many times to try again when something fails (a long name only, no short name)"]
  [:positional "file" :arity (0 +)
   :description "the files to work on, any number of them"])

(define option (parse-or-exit parse (cdr (command-line))))

(define (show name value)
  (display name) (display " => ") (write value) (newline))

(show "verbose" (option "verbose"))       ; #t or #f
(show "count" (option "count"))           ; an integer, or #f
(show "exclude" (option "exclude"))       ; a list of strings
(show "retries" (option "retries"))       ; an integer, 3 when not given
(show "format" (option "format"))         ; one of the choices, or #f
(show "file" (option "file"))             ; the positional words, a list of strings
