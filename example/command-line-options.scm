#!r6rs
;; Run from the repository root:
;;   scheme --libdirs . --program example/command-line-options.scm -v --count 3 -e a b -- file.txt
;;   guile --r6rs -L . example/command-line-options.scm -v --count 3 -e a b -- file.txt
;;   ... example/command-line-options.scm -h
(import (rnrs (6)) (rime command-line-options))

(define-command-line-options parse
  ["-v" :long "--verbose" :arity 0 :description "print more details"]
  ["-n" :long "--count"   :type int :description "number of repetitions"]
  ["-e" :long "--exclude" :arity (1 +) :description "patterns to exclude"])

(define option (parse (cdr (command-line))))

(define (show name value)
  (display name) (display " => ") (write value) (newline))

(show "-v" (option "-v"))                 ; present or absent
(show "--count" (option "--count"))       ; an integer, or #f
(show "-e" (option "-e"))                 ; a list of strings
(show "positionals" (let loop ([i 0])
                      (if (< i (option 'number-of-positional-argument))
                          (cons (option i) (loop (+ i 1)))
                          '())))
