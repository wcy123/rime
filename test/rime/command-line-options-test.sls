#!r6rs
(library (test rime command-line-options-test)
  (export main)
  (import (rnrs (6))
          (rnrs eval (6))
          (rime unit-test)
          (rime command-line-options))

  (define (main)
    (run-all-tests))

  ;; what the usage and the error report show as the program: the script that runs the tests
  (define prog (car (command-line)))

  (define-command-line-options parse
    [:short "-v" :long "--verbose" :arity 0 :description "verbose output"]
    [:short "-q" :arity 0 :description "quiet"]
    [:short "-n" :long "--count" :arity 1 :type int :description "repeat count"]
    [:short "-x" :long "--ratio" :type float :description "ratio"]
    [:short "-b" :long "--flag" :type bool :description "a flag"]
    [:short "-s" :long "--name" :description "name"]
    [:short "-f" :long "--files" :arity (1 +) :type string :description "input files"]
    [:short "-r" :long "--range" :arity (0 2) :type int :description "range"]
    [:short "-p" :long "--pair" :arity 2 :type int :description "pair"]
    [:short "-u" :long "--upper" :type (lambda (s) (string-upcase s)) :description "custom"]
    [:short "-o" :long "--opt-list" :arity (0 +) :description "zero or more"]
    [:positional "args" :arity (0 +) :description "the positional arguments"])

  ;; the positional words, which the parsers of this file collect under the name "args"
  (define (positional option i) (list-ref (option "args") i))
  (define (positional-count option) (length (option "args")))

  ;; message of the error raised by thunk, #f if nothing raised
  (define (error-message thunk)
    (guard (e [(and (error? e) (message-condition? e)) (condition-message e)]
              [else 'not-an-error-condition])
      (thunk)
      #f))

  (define (syntax-error? form)
    (guard (e [(syntax-violation? e) #t]
              [else #f])
      (eval form (environment '(rnrs (6)) '(rime command-line-options)))
      #f))

  ;; ========================================
  ;; arity 0
  ;; ========================================

  (define-test test-arity-0-present
    (let ([option (parse '("-v" "-q"))])
      (CHECK eq? (option "v") #t)
      (CHECK eq? (option "verbose") #t)
      (CHECK eq? (option "q") #t)))

  (define-test test-arity-0-absent
    (let ([option (parse '())])
      (CHECK eq? (option "v") #f)
      (CHECK eq? (option "verbose") #f)
      (CHECK eq? (option "q") #f)))

  (define-test test-arity-0-long-name
    (let ([option (parse '("--verbose"))])
      (CHECK eq? (option "v") #t)
      (CHECK eq? (option "q") #f)))

  (define-test test-an-absent-flag-is-false-in-an-if
    ;; the symbol 'absent used to be truthy, so this always gave yes
    (CHECK eq? (if ((parse '()) "verbose") 'yes 'no) 'no)
    (CHECK eq? (if ((parse '("-v")) "verbose") 'yes 'no) 'yes)
    (CHECK eq? (and ((parse '("-v")) "v") ((parse '("-q")) "q")) #t)
    (CHECK eq? (or ((parse '()) "v") ((parse '()) "q")) #f))

  (define-test test-a-flag-is-exactly-a-boolean
    (CHECK eq? (boolean? ((parse '("-v")) "v")) #t)
    (CHECK eq? (boolean? ((parse '()) "v")) #t)
    (CHECK eq? ((parse '("-v")) "v") #t)
    (CHECK eq? ((parse '()) "v") #f))

  (define-test test-a-flag-given-twice-is-still-true
    (CHECK eq? ((parse '("-v" "-v")) "v") #t)
    (CHECK eq? ((parse '("-v" "--verbose")) "verbose") #t))

  (define-test test-arity-0-does-not-consume-next
    (let ([option (parse '("-v" "file"))])
      (CHECK eq? (option "v") #t)
      (CHECK equal? (positional option 0) "file")))

  ;; ========================================
  ;; types
  ;; ========================================

  (define-test test-type-int
    (let ([option (parse '("-n" "42"))])
      (CHECK eqv? (option "n") 42)
      (CHECK eqv? (option "count") 42)))

  (define-test test-type-int-signed-escaped
    (let ([option (parse '("-n" "\\-7"))])
      (CHECK eqv? (option "n") -7)))

  (define-test test-type-float
    (let ([option (parse '("-x" "2.5"))])
      (CHECK eqv? (option "x") 2.5)))

  (define-test test-type-float-from-integer-text
    (let ([option (parse '("--ratio" "3"))])
      (CHECK eqv? (option "x") 3.0)))

  (define-test test-type-bool-true-words
    (for-each
     (lambda (word)
       (CHECK eq? ((parse (list "-b" word)) "b") #t))
     '("true" "yes" "on" "1" "TRUE" "Yes")))

  (define-test test-type-bool-false-words
    (for-each
     (lambda (word)
       (CHECK eq? ((parse (list "-b" word)) "b") #f))
     '("false" "no" "off" "0" "FALSE" "No")))

  (define-test test-type-bool-false-value
    (CHECK eq? ((parse '("-b" "off")) "flag") #f)
    (CHECK eq? ((parse '()) "flag") #f))

  (define-test test-type-string-default
    (let ([option (parse '("-s" "hello"))])
      (CHECK equal? (option "s") "hello")
      (CHECK equal? (option "name") "hello")))

  (define-test test-type-custom-procedure
    (let ([option (parse '("-u" "abc"))])
      (CHECK equal? (option "u") "ABC")))

  ;; ========================================
  ;; absent values
  ;; ========================================

  (define-test test-absent-single-argument-is-false
    (let ([option (parse '())])
      (CHECK eq? (option "n") #f)
      (CHECK eq? (option "s") #f)
      (CHECK eq? (option "ratio") #f)))

  (define-test test-absent-multiple-argument-is-empty-list
    (let ([option (parse '())])
      (CHECK equal? (option "f") '())
      (CHECK equal? (option "r") '())
      (CHECK equal? (option "p") '())
      (CHECK equal? (option "o") '())))

  ;; ========================================
  ;; arity
  ;; ========================================

  (define-test test-arity-exact-n
    (let ([option (parse '("-p" "1" "2"))])
      (CHECK equal? (option "p") '(1 2))))

  (define-test test-arity-min-unbounded
    (let ([option (parse '("-f" "a" "b" "c"))])
      (CHECK equal? (option "files") '("a" "b" "c"))))

  (define-test test-arity-min-unbounded-with-exactly-min
    (let ([option (parse '("-f" "a"))])
      (CHECK equal? (option "files") '("a"))))

  (define-test test-arity-range-lower-bound
    (let ([option (parse '("-r"))])
      (CHECK equal? (option "r") '())
      (CHECK equal? (positional-count option) 0)))

  (define-test test-arity-range-middle
    (let ([option (parse '("-r" "1"))])
      (CHECK equal? (option "r") '(1))))

  (define-test test-arity-range-upper-bound
    (let ([option (parse '("-r" "1" "2"))])
      (CHECK equal? (option "r") '(1 2))))

  (define-test test-arity-range-stops-at-max
    (let ([option (parse '("-r" "1" "2" "3"))])
      (CHECK equal? (option "r") '(1 2))
      (CHECK equal? (positional option 0) "3")))

  (define-test test-arity-zero-unbounded-present-without-arguments
    (let ([option (parse '("-o"))])
      (CHECK equal? (option "o") '())))

  (define-test test-arity-single-stops-at-max
    (let ([option (parse '("-n" "1" "2"))])
      (CHECK eqv? (option "n") 1)
      (CHECK equal? (positional option 0) "2")))

  ;; ========================================
  ;; argument forms
  ;; ========================================

  (define-test test-form-long-space
    (let ([option (parse '("--files" "a" "b"))])
      (CHECK equal? (option "f") '("a" "b"))))

  (define-test test-form-short-space
    (let ([option (parse '("-f" "a" "b"))])
      (CHECK equal? (option "files") '("a" "b"))))

  (define-test test-form-long-equals-is-one-argument-even-with-commas
    (let ([option (parse '("--files=a,b,c"))])
      (CHECK equal? (option "f") '("a,b,c"))))

  (define-test test-form-long-equals-single
    (let ([option (parse '("--count=5"))])
      (CHECK eqv? (option "n") 5)))

  (define-test test-form-short-equals
    (let ([option (parse '("-f=a,b"))])
      (CHECK equal? (option "f") '("a,b"))))

  (define-test test-form-equals-converts-the-argument
    (let ([option (parse '("--range=7"))])
      (CHECK equal? (option "r") '(7))))

  (define-test test-form-equals-does-not-consume-next
    (let ([option (parse '("--files=a" "pos"))])
      (CHECK equal? (option "f") '("a"))
      (CHECK equal? (positional option 0) "pos")))

  (define-test test-form-equals-value-may-start-with-dash
    (let ([option (parse '("--name=-weird"))])
      (CHECK equal? (option "s") "-weird")))

  ;; after =, the text is one argument, whatever the arity: there is no comma list
  (define-command-line-options parse-comma
    [:short "-t" :long "--title" :description "one argument"]
    [:long "--text" :arity (0 1) :type string :description "zero or one argument"]
    [:long "--level" :arity (0 1) :type int :description "zero or one integer"]
    [:long "--pair" :arity 2 :description "two arguments"]
    [:long "--files" :arity (1 +) :description "several arguments"]
    [:long "--range" :arity (0 2) :description "up to two arguments"]
    [:long "--flag" :arity 0 :description "a flag"])

  (define-test test-form-equals-one-argument-keeps-its-commas
    (CHECK equal? ((parse-comma '("--title=Hello, World")) "title") "Hello, World")
    (CHECK equal? ((parse-comma '("-t=a,b,c")) "t") "a,b,c")
    (CHECK equal? ((parse-comma '("--title=a,,b,")) "title") "a,,b,")
    (CHECK equal? ((parse-comma '("--title=,")) "title") ","))

  (define-test test-form-equals-one-argument-splits-at-the-first-equals-only
    (CHECK equal? ((parse-comma '("--title=a=b,c")) "title") "a=b,c")
    (CHECK equal? ((parse-comma '("--title==")) "title") "="))

  (define-test test-form-equals-one-argument-empty-value
    (CHECK equal? ((parse-comma '("--title=")) "title") ""))

  (define-test test-form-equals-zero-or-one-argument-keeps-its-commas
    (CHECK equal? ((parse-comma '("--text=1,2")) "text") '("1,2"))
    (CHECK equal? ((parse-comma '("--text=a")) "text") '("a"))
    (CHECK equal? (error-message (lambda () (parse-comma '("--level=1,2")))) "invalid argument value")
    (CHECK equal? (error-irritants (lambda () (parse-comma '("--level=1,2")))) '("--level" "1,2"))
    (CHECK equal? ((parse-comma '("--level=7")) "level") '(7)))

  (define-test test-form-equals-supplies-one-argument-to-a-variable-arity-option
    (CHECK equal? ((parse-comma '("--files=a,b,c")) "files") '("a,b,c"))
    (CHECK equal? ((parse-comma '("--files=a")) "files") '("a"))
    (CHECK equal? ((parse-comma '("--range=1,2")) "range") '("1,2"))
    (CHECK equal? ((parse-comma '("--range=1")) "range") '("1"))
    (CHECK equal? ((parse-comma '("--files=a, b")) "files") '("a, b")))

  (define-test test-form-equals-cannot-give-the-two-arguments-an-option-needs
    (CHECK equal? (error-message (lambda () (parse-comma '("--pair=1")))) "too few arguments for option")
    (CHECK equal? (error-message (lambda () (parse-comma '("--pair=1,2")))) "too few arguments for option")
    (CHECK equal? (error-irritants (lambda () (parse-comma '("--pair=3,4")))) '("--pair"))
    (CHECK equal? ((parse-comma '("--pair" "3" "4")) "pair") '("3" "4")))

  (define-test test-form-equals-empty-value-is-one-empty-argument
    (CHECK equal? ((parse-comma '("--files=")) "files") '(""))
    (CHECK equal? ((parse-comma '("--range=")) "range") '(""))
    (CHECK equal? ((parse-comma '("--title=")) "title") ""))

  (define-test test-form-equals-there-is-no-too-many-error-any-more
    ;; one argument can never be too many, and a space-separated option stops at its maximum
    (CHECK eq? (error-message (lambda () (parse-comma '("--range=1,2,3")))) #f)
    (CHECK equal? ((parse-comma '("--range" "1" "2")) "range") '("1" "2")))

  (define-test test-form-equals-a-flag-takes-no-value-whatever-it-contains
    (CHECK equal? (error-message (lambda () (parse-comma '("--flag=1")))) "option does not take arguments")
    (CHECK equal? (error-message (lambda () (parse-comma '("--flag=a,b")))) "option does not take arguments"))

  (define-test test-form-space-and-equals-agree-for-one-argument
    (CHECK equal? ((parse-comma '("--title" "Hello, World")) "title")
           ((parse-comma '("--title=Hello, World")) "title")))

  (define-test test-form-equals-empty-value
    (let ([option (parse '("--name="))])
      (CHECK equal? (option "s") "")))

  (define-test test-form-equals-empty-value-is-one-empty-argument-even-when-the-option-may-take-none
    (CHECK equal? ((parse '("--opt-list=")) "opt-list") '(""))
    (CHECK equal? ((parse '("-o=")) "o") '(""))
    ;; --range is an integer option, and an empty text is not an integer
    (CHECK equal? (error-message (lambda () (parse '("--range=")))) "invalid argument value"))

  (define-test test-form-equals-empty-value-is-one-empty-argument-when-the-option-needs-one
    (CHECK equal? ((parse '("--files=")) "files") '(""))
    (CHECK equal? ((parse '("-f=")) "f") '(""))
    (CHECK equal? ((parse '("--name=")) "name") "")
    ;; --pair is an integer option too: the empty text is converted first, and it is not an integer
    (CHECK equal? (error-message (lambda () (parse '("--pair=")))) "invalid argument value")
    (CHECK equal? (error-message (lambda () (parse '("--count=")))) "invalid argument value"))

  (define-test test-form-mixed
    (let ([option (parse '("-v" "--count=2" "-f" "a" "b" "-s" "n" "--ratio" "0.5"))])
      (CHECK eq? (option "v") #t)
      (CHECK eqv? (option "n") 2)
      (CHECK equal? (option "f") '("a" "b"))
      (CHECK equal? (option "s") "n")
      (CHECK eqv? (option "x") 0.5)))

  ;; ========================================
  ;; repeated option: an option with an upper limit keeps its last occurrence, one without adds up
  ;; ========================================

  (define-test test-repeated-option-with-one-argument-last-wins
    (CHECK eqv? ((parse '("-n" "1" "-n" "2")) "n") 2)
    (CHECK equal? ((parse '("-s" "a" "--name" "b")) "s") "b"))

  (define-test test-an-option-that-takes-several_arguments-collects-them-from-every-occurrence
    ;; -p takes exactly two: the arguments of all the occurrences are joined, and the total is checked
    (CHECK equal? ((parse '("-p" "1" "2")) "pair") '(1 2))
    (CHECK equal? ((parse '("-p" "1" "-p" "2")) "pair") '(1 2))
    (CHECK equal? ((parse '("--pair=1" "--pair=2")) "pair") '(1 2))
    (CHECK equal? ((parse '("-p" "1" "-v" "-p" "2")) "pair") '(1 2)))

  (define-test test-too-many-arguments-from-all-the-occurrences-is-an-error
    (CHECK equal? (error-message (lambda () (parse '("-p" "1" "2" "-p" "3" "4"))))
           "too many arguments for option")
    (CHECK equal? (error-irritants (lambda () (parse '("-p" "1" "2" "-p" "3" "4")))) '("--pair"))
    (CHECK equal? (error-message (lambda () (parse '("-p" "1" "-p" "2" "-p" "3"))))
           "too many arguments for option"))

  (define-test test-too-few-arguments-from-all-the-occurrences-is-an-error
    (CHECK equal? (error-message (lambda () (parse '("-p" "1")))) "too few arguments for option")
    (CHECK equal? (error-message (lambda () (parse '("-p" "1" "-v")))) "too few arguments for option")
    (CHECK equal? (error-message (lambda () (parse '("--pair=1")))) "too few arguments for option"))

  (define-test test-an-option-with-a-bounded-arity-collects-and-checks-the-total
    (CHECK equal? ((parse '("-r" "1" "-r" "2")) "range") '(1 2))
    (CHECK equal? ((parse '("-r" "-r" "1")) "range") '(1))
    (CHECK equal? ((parse '("-r" "1" "2")) "range") '(1 2))
    (CHECK equal? (error-message (lambda () (parse '("-r" "1" "2" "-r" "3")))) "too many arguments for option"))

  (define-test test-an-option-with-at-most-one-argument-still-keeps-the-last
    ;; --text takes zero or one argument: its value cannot hold more, so the last occurrence wins
    (CHECK equal? ((parse-comma '("--text" "a" "--text" "b")) "text") '("b"))
    (CHECK equal? ((parse-comma '("--text" "a" "--text")) "text") '()))

  (define-test test-repeated-option-without-an-upper-limit-adds-up
    (CHECK equal? ((parse '("-f" "a" "-f" "b")) "files") '("a" "b"))
    (CHECK equal? ((parse '("-f" "a" "b" "-f" "c")) "files") '("a" "b" "c"))
    (CHECK equal? ((parse '("--files=a" "--files=b" "-f=c")) "files") '("a" "b" "c"))
    (CHECK equal? ((parse '("-f" "a" "-v" "--files" "b")) "files") '("a" "b")))

  (define-test test-repeated-zero-or-more-option-adds-up
    (CHECK equal? ((parse '("-o" "a" "-o" "b")) "opt-list") '("a" "b"))
    (CHECK equal? ((parse '("-o" "-o" "a")) "opt-list") '("a"))
    (CHECK equal? ((parse '("-o" "-o")) "opt-list") '()))

  (define-command-line-options parse-numbers
    [:short "-n" :long "--num" :arity (1 +) :type int]
    [:long "--level" :arity (1 +) :choices (1 2 4)]
    [:positional "rest" :arity (0 +)])

  (define-test test-every-repeated-value-is-converted-and-checked
    (CHECK equal? ((parse-numbers '("-n" "1" "-n" "2" "3")) "num") '(1 2 3))
    (CHECK equal? (error-message (lambda () (parse-numbers '("-n" "1" "-n" "x")))) "invalid argument value")
    (CHECK equal? ((parse-numbers '("--level" "1" "--level" "4")) "level") '(1 4))
    (CHECK equal? (error-message (lambda () (parse-numbers '("--level" "1" "--level" "3"))))
           "argument must be one of the choices"))

  (define-test test-a-default-is-used-only-when-the-option-was-not-given
    (CHECK equal? ((parse '()) "files" '("d")) '("d"))
    (CHECK equal? ((parse '("-f" "a" "-f" "b")) "files" '("d")) '("a" "b")))

  (define-test test-the-last-repeated-option-takes-the-words-after-it
    ;; an option without an upper limit takes every ordinary word that follows, the last one included
    (let ([option (parse '("-f" "a" "-f" "b" "file.c"))])
      (CHECK equal? (option "files") '("a" "b" "file.c"))
      (CHECK equal? (option "args") '()))
    (let ([option (parse '("-f" "a" "-f" "b" "--" "file.c"))])
      (CHECK equal? (option "files") '("a" "b"))
      (CHECK equal? (option "args") '("file.c")))
    (let ([option (parse '("-f" "a" "-f=b" "file.c"))])
      (CHECK equal? (option "files") '("a" "b"))
      (CHECK equal? (option "args") '("file.c"))))

  (define-test test-a-flag-repeated-stays-true
    (CHECK eq? ((parse '("-v" "-v" "--verbose")) "v") #t))

  ;; ========================================
  ;; escape with backslash
  ;; ========================================

  (define-test test-escape-dash-argument
    (let ([option (parse '("-s" "\\-x"))])
      (CHECK equal? (option "s") "-x")))

  (define-test test-escape-double-dash-argument
    (let ([option (parse '("-s" "\\--long"))])
      (CHECK equal? (option "s") "--long")))

  (define-test test-escape-in-multiple-arguments
    (let ([option (parse '("-f" "a" "\\-b" "\\--c"))])
      (CHECK equal? (option "f") '("a" "-b" "--c"))))

  (define-test test-escape-positional
    (let ([option (parse '("\\-x" "y"))])
      (CHECK equal? (positional option 0) "-x")
      (CHECK equal? (positional option 1) "y")))

  (define-test test-escape-in-equals-form
    (let ([option (parse '("--files=\\-a,b"))])
      (CHECK equal? (option "f") '("-a,b"))))

  (define-test test-backslash-not-before-dash-is-kept
    (let ([option (parse '("-s" "a\\-b"))])
      (CHECK equal? (option "s") "a\\-b"))
    (let ([option (parse '("-s" "\\x"))])
      (CHECK equal? (option "s") "\\x")))

  (define-test test-lone-dash-is-a-value
    (let ([option (parse '("-s" "-"))])
      (CHECK equal? (option "s") "-"))
    (let ([option (parse '("-"))])
      (CHECK equal? (positional option 0) "-")))

  (define-test test-unescaped-dash-argument-is-an-option
    (CHECK equal? (error-message (lambda () (parse '("-s" "-x"))))
           "too few arguments for option"))

  ;; ========================================
  ;; positional arguments
  ;; ========================================

  (define-test test-positional-only
    (let ([option (parse '("a" "b" "c"))])
      (CHECK eqv? (positional-count option) 3)
      (CHECK equal? (positional option 0) "a")
      (CHECK equal? (positional option 1) "b")
      (CHECK equal? (positional option 2) "c")))

  (define-test test-positional-none
    (let ([option (parse '("-v"))])
      (CHECK eqv? (positional-count option) 0)))

  (define-test test-positional-after-options
    (let ([option (parse '("-v" "-n" "3" "in.txt" "out.txt"))])
      (CHECK eq? (option "v") #t)
      (CHECK eqv? (option "n") 3)
      (CHECK eqv? (positional-count option) 2)
      (CHECK equal? (positional option 0) "in.txt")
      (CHECK equal? (positional option 1) "out.txt")))

  (define-test test-positional-after-double-dash
    (let ([option (parse '("-v" "--" "a" "b"))])
      (CHECK eq? (option "v") #t)
      (CHECK eqv? (positional-count option) 2)
      (CHECK equal? (positional option 0) "a")
      (CHECK equal? (positional option 1) "b")))

  (define-test test-double-dash-terminates-variable-arity
    (let ([option (parse '("-f" "a" "b" "--" "c"))])
      (CHECK equal? (option "f") '("a" "b"))
      (CHECK equal? (positional option 0) "c")
      (CHECK eqv? (positional-count option) 1)))

  (define-test test-double-dash-then-option-like-is-literal
    (let ([option (parse '("--" "-v" "--count" "\\-x"))])
      (CHECK eq? (option "v") #f)
      (CHECK eqv? (positional-count option) 3)
      (CHECK equal? (positional option 0) "-v")
      (CHECK equal? (positional option 1) "--count")
      (CHECK equal? (positional option 2) "\\-x")))

  (define-test test-double-dash-twice-second-is-literal
    (let ([option (parse '("--" "--" "a"))])
      (CHECK eqv? (positional-count option) 2)
      (CHECK equal? (positional option 0) "--")))

  (define-test test-options-after-the-first-positional-are-options
    (let ([option (parse '("a" "-v" "--count" "5"))])
      (CHECK eq? (option "v") #t)
      (CHECK eqv? (option "n") 5)
      (CHECK eqv? (positional-count option) 1)
      (CHECK equal? (positional option 0) "a")))

  (define-test test-integer-key-is-invalid
    (let ([option (parse '("a"))])
      (CHECK equal? (error-message (lambda () (option 0))) "invalid option key")
      (CHECK equal? (error-message (lambda () (option -1))) "invalid option key")))

  (define-test test-the-old-positional-count-key-is-gone
    (let ([option (parse '("a"))])
      (CHECK equal? (error-message (lambda () (option 'number-of-positional-argument)))
             "unknown option")))

  ;; ========================================
  ;; parse errors
  ;; ========================================

  ;; a word is an option only when it is the name of a defined option: any other word, whatever it
  ;; starts with, is an ordinary word (a positional word, or an argument of the option before it)
  (define-test test-an-undefined-dash-word-is-a-positional-word
    (CHECK equal? ((parse '("-z")) "args") '("-z"))
    (CHECK equal? ((parse '("--nope")) "args") '("--nope"))
    (CHECK equal? ((parse '("--nope=1")) "args") '("--nope=1"))
    (CHECK equal? ((parse '("-vq")) "args") '("-vq"))
    (CHECK equal? ((parse '("a" "-z" "b")) "args") '("a" "-z" "b")))

  (define-test test-an-undefined-dash-word-is-an-error-when-there-is-no-positional
    (CHECK equal? (error-message (lambda () (parse-none '("-z")))) "unexpected positional argument")
    (CHECK equal? (error-irritants (lambda () (parse-none '("--nope=1")))) '("--nope=1")))

  (define-test test-an-undefined-dash-word-is-an-argument-of-the-option-before-it
    (CHECK equal? ((parse '("-f" "a" "--nope" "b")) "f") '("a" "--nope" "b"))
    (CHECK equal? ((parse '("-s" "-z")) "s") "-z"))

  (define-test test-help-with-an-equals-is-not-the-help
    (CHECK equal? ((parse '("-h=x")) "args") '("-h=x")))

  ;; ========================================
  ;; negative numbers are values, not options
  ;; ========================================

  (define-test test-negative-number-is-an-argument
    (CHECK eqv? ((parse '("-n" "-5")) "n") -5)
    (CHECK eqv? ((parse '("--count" "-5")) "count") -5)
    (CHECK eqv? ((parse '("-n" "-0")) "n") 0))

  (define-test test-negative-float-is-an-argument
    (CHECK eqv? ((parse '("-x" "-1.5")) "x") -1.5)
    (CHECK eqv? ((parse '("-x" "-.5")) "x") -0.5)
    (CHECK eqv? ((parse '("-x" "-1e3")) "x") -1000.0)
    (CHECK eqv? ((parse '("-x" "-2.5E-3")) "x") -0.0025)
    (CHECK eqv? ((parse '("-x" "-2e+2")) "x") -200.0))

  (define-test test-negative-numbers-for-options-with-several-arguments
    (CHECK equal? ((parse '("-p" "-1" "-2")) "p") '(-1 -2))
    (CHECK equal? ((parse '("-f" "-1" "-2" "-3")) "f") '("-1" "-2" "-3"))
    (CHECK equal? ((parse '("-r" "-1" "-2")) "r") '(-1 -2)))

  (define-test test-negative-number-ends-at-the-next-option
    (let ([option (parse '("-f" "-1" "-v" "-2"))])
      (CHECK equal? (option "f") '("-1"))
      (CHECK equal? (positional option 0) "-2")))

  (define-test test-negative-number-as-a-positional-word
    (CHECK equal? ((parse '("-5")) "args") '("-5"))
    (CHECK equal? ((parse '("a" "-5" "b")) "args") '("a" "-5" "b"))
    (CHECK equal? ((parse '("-v" "-5")) "args") '("-5")))

  (define-test test-negative-number-after-double-dash-is-a-word
    (CHECK equal? ((parse '("--" "-5")) "args") '("-5")))

  (define-test test-negative-integer-choice-without-the-escape
    (CHECK eqv? ((with-choices '("--delta" "-1")) "delta") -1))

  (define-test test-negative-number-with-the-escape-still-works
    (CHECK eqv? ((parse '("-n" "\\-5")) "n") -5)
    (CHECK equal? ((parse '("\\-5")) "args") '("-5")))

  (define-test test-words-that-are-not-numbers-are-words-too
    (for-each
     (lambda (word)
       (CHECK equal? (list word ((parse (list word)) "args")) (list word (list word))))
     '("-5a" "-0x10" "-1/2" "-inf" "-e5" "-1e" "-1." "-." "-1.2.3" "-+5" "-5-" "--5" "-1e+" "-i")))

  (define-test test-a-word-like-a-number-but-not-a-number-can-be-escaped
    (CHECK equal? ((parse '("\\-5a")) "args") '("-5a"))
    (CHECK equal? ((parse '("-s" "\\-0x10")) "s") "-0x10"))

  (define-command-line-options parse-digit
    [:short "-1" :arity 0 :description "one"]
    [:short "-n" :type int]
    [:positional "rest" :arity (0 +)])

  (define-test test-an-option-named-like-a-number-wins
    (let ([option (parse-digit '("-1" "x"))])
      (CHECK eq? (option "1") #t)
      (CHECK equal? (option "rest") '("x")))
    (CHECK equal? (error-message (lambda () (parse-digit '("-n" "-1")))) "too few arguments for option"))

  (define-test test-another-number-is-still-a-value-when-an-option-is-named-like-a-number
    (let ([option (parse-digit '("-n" "-2" "-3"))])
      (CHECK eqv? (option "n") -2)
      (CHECK equal? (option "rest") '("-3")))
    (CHECK equal? ((parse-digit '("-2")) "rest") '("-2")))

  (define-test test-error-too-few-none-given
    (CHECK equal? (error-message (lambda () (parse '("-n"))))
           "too few arguments for option")
    (CHECK equal? (error-message (lambda () (parse '("--files"))))
           "too few arguments for option"))

  (define-test test-error-too-few-for-exact-arity
    (CHECK equal? (error-message (lambda () (parse '("-p" "1"))))
           "too few arguments for option"))

  (define-test test-error-too-few-stops-at-next-option
    (CHECK equal? (error-message (lambda () (parse '("-p" "1" "-v"))))
           "too few arguments for option"))

  (define-test test-error-too-few-at-double-dash
    (CHECK equal? (error-message (lambda () (parse '("-n" "--" "1"))))
           "too few arguments for option"))

  (define-test test-error-too-few-in-equals-form
    (CHECK equal? (error-message (lambda () (parse '("--pair=1"))))
           "too few arguments for option"))

  (define-test test-error-equals-form-takes-one-argument
    ;; 1,2,3 is one argument, and not an integer
    (CHECK equal? (error-message (lambda () (parse '("--range=1,2,3"))))
           "invalid argument value")
    ;; --pair is an integer option too, and the one text 1,2,3 is not an integer
    (CHECK equal? (error-message (lambda () (parse '("--pair=1,2,3"))))
           "invalid argument value"))

  (define-test test-equals-form-of-a-typed-one-argument-option-is-not-split
    (CHECK equal? (error-message (lambda () (parse '("--count=1,2"))))
           "invalid argument value")
    (CHECK equal? (error-irritants (lambda () (parse '("--count=1,2"))))
           '("--count" "1,2")))

  (define-test test-error-arity-0-with-equals
    (CHECK equal? (error-message (lambda () (parse '("--verbose=1"))))
           "option does not take arguments"))

  (define-test test-error-invalid-int
    (CHECK equal? (error-message (lambda () (parse '("-n" "abc"))))
           "invalid argument value")
    (CHECK equal? (error-message (lambda () (parse '("-n" "1.5"))))
           "invalid argument value")
    (CHECK equal? (error-message (lambda () (parse '("-n" ""))))
           "invalid argument value"))

  (define-test test-error-invalid-int-out-of-fixnum-range
    (CHECK equal? (error-message
                   (lambda () (parse '("-n" "123456789012345678901234567890"))))
           "invalid argument value"))

  (define-test test-error-invalid-float
    (CHECK equal? (error-message (lambda () (parse '("-x" "abc"))))
           "invalid argument value"))

  (define-test test-type-int-and-float-forms
    (CHECK eqv? ((parse '("-n" "+3")) "n") 3)
    (CHECK eqv? ((parse '("-x" "1e3")) "x") 1000.0)
    (CHECK eqv? ((parse '("-x" ".5")) "x") 0.5))

  (define-test test-error-invalid-bool
    (CHECK equal? (error-message (lambda () (parse '("-b" "maybe"))))
           "invalid argument value"))

  (define-test test-error-invalid-value-in-list
    (CHECK equal? (error-message (lambda () (parse '("-p" "1" "x"))))
           "invalid argument value"))

  (define-command-line-options strict
    [:short "-k" :arity 1 :type (lambda (s) (if (string=? s "ok") s (raise 'bad)))])

  (define-test test-error-custom-converter-failure
    (CHECK equal? ((strict '("-k" "ok")) "k") "ok")
    (CHECK equal? (error-message (lambda () (strict '("-k" "no"))))
           "invalid argument value"))

  (define-test test-error-condition-irritants-name-the-option
    (guard (e [(error? e)
               (CHECK equal? (condition-irritants e) '("--count" "abc"))
               (CHECK eq? (condition-who e) 'opt-parser)])
      (parse '("--count" "abc"))
      (assert #f)))

  ;; ========================================
  ;; the command-line error type, and the usage in the error
  ;; ========================================

  ;; the condition that the thunk raises, #f when it raises nothing
  (define (raised thunk)
    (guard (e [#t e])
      (thunk)
      #f))

  (define-test test-a-bad-command-line-raises-a-command-line-error
    (let ([e (raised (lambda () (parse '("-n" "abc"))))])
      (CHECK eq? (command-line-error? e) #t)
      ;; everything that an error from the library had before is still there
      (CHECK eq? (error? e) #t)
      (CHECK eq? (who-condition? e) #t)
      (CHECK eq? (condition-who e) 'opt-parser)
      (CHECK equal? (condition-message e) "invalid argument value")
      (CHECK equal? (condition-irritants e) '("-n" "abc"))))

  (define-test test-every-kind-of-command-line-error-carries-the-usage
    (let ([usage ((parse '()) "usage")])
      (for-each
       (lambda (arguments)
         (let ([e (raised (lambda () (parse arguments)))])
           (CHECK eq? (and (command-line-error? e) #t) #t)
           (CHECK equal? (list arguments (and e (command-line-error-usage e)))
                  (list arguments usage))))
       '(("-n" "abc")           ; invalid argument value
         ("--pair=1")           ; too few arguments for option, --pair needs two
         ("-n")                 ; too few arguments for option
         ("--count=1,2")        ; invalid argument value, 1,2 is not an integer
         ("--verbose=1")))))    ; option does not take arguments

  (define-test test-missing-required-option-carries-the-usage
    (let ([e (raised (lambda () (parse-required '())))])
      (CHECK eq? (command-line-error? e) #t)
      (CHECK equal? (condition-message e) "missing required option")
      (CHECK equal? (command-line-error-usage e) ((parse-required '("-i" "a")) "usage"))))

  (define-test test-positional-errors-carry-the-usage
    (let ([few (raised (lambda () (parse-one '())))]
          [many (raised (lambda () (parse-one '("a" "b"))))]
          [none (raised (lambda () (parse-none '("a"))))])
      (CHECK equal? (condition-message few) "too few positional arguments")
      (CHECK equal? (command-line-error-usage few) ((parse-one '("a")) "usage"))
      (CHECK equal? (condition-message many) "too many positional arguments")
      (CHECK equal? (command-line-error-usage many) ((parse-one '("a")) "usage"))
      (CHECK equal? (condition-message none) "unexpected positional argument")
      (CHECK equal? (command-line-error-usage none) ((parse-none '()) "usage"))))

  (define-test test-a-failing-custom-type-is-a-command-line-error-with-the-usage
    (let ([e (raised (lambda () (strict '("-k" "no"))))])
      (CHECK eq? (command-line-error? e) #t)
      (CHECK equal? (condition-message e) "invalid argument value")
      (CHECK equal? (command-line-error-usage e) ((strict '("-k" "ok")) "usage"))))

  (define-test test-errors-that-are-not-about-the-command-line-are-not-command-line-errors
    (let ([option (parse '())])
      ;; the program's own mistakes: a name that does not exist, a key that is not a name
      (CHECK eq? (command-line-error? (raised (lambda () (option "nope")))) #f)
      (CHECK eq? (command-line-error? (raised (lambda () (option 0)))) #f)
      (CHECK equal? (condition-message (raised (lambda () (option "nope")))) "unknown option")
      (CHECK equal? (condition-message (raised (lambda () (option 0)))) "invalid option key")
      ;; and any other error of the program
      (CHECK eq? (command-line-error? (raised (lambda () (parse '()) (error 'mine "a bug")))) #f)
      (CHECK eq? (command-line-error? #f) #f)
      (CHECK eq? (command-line-error? 'oops) #f)))

  ;; the sentence of the report: what comes before the blank line that separates it from the usage
  (define (report-text thunk)
    (caddr (run-capturing-exit-and-error
            (lambda () (parse-or-exit (lambda (arguments) (thunk)) '())))))

  (define (report-sentence report)
    (let ([end (let loop ([i 0])
                 (cond [(>= (+ i 1) (string-length report)) (string-length report)]
                       [(and (char=? (string-ref report i) #\newline)
                             (char=? (string-ref report (+ i 1)) #\newline))
                        i]
                       [else (loop (+ i 1))]))])
      (substring report 0 end)))

  ;; (message details sentence thunk): the thunk raises the error, and what a person reads is the sentence
  (define report-rows
    (list
     (list "invalid argument value" '("-n" "abc")
           "invalid argument \"abc\" for -n"
           (lambda () (parse '("-n" "abc"))))
     (list "invalid argument value" '("-n" "")
           "invalid argument \"\" for -n"
           (lambda () (parse '("-n" ""))))
     (list "invalid argument value" '("-n" "a \"b\"")
           "invalid argument \"a \\\"b\\\"\" for -n"
           (lambda () (parse '("-n" "a \"b\""))))
     (list "argument must be one of the choices" '("--format" "xml" ("json" "text" "yaml"))
           "\"xml\" is not one of json, text, yaml (for --format)"
           (lambda () (with-choices '("--format" "xml"))))
     (list "argument must be one of the choices" '("--level" "3" (1 2 4))
           "\"3\" is not one of 1, 2, 4 (for --level)"
           (lambda () (with-choices '("--level" "3"))))
     (list "too few arguments for option" '("-n")
           "too few arguments for -n"
           (lambda () (parse '("-n"))))
     (list "too few arguments for option" '("--pair")
           "too few arguments for --pair"
           (lambda () (parse '("--pair=3"))))
     (list "too many arguments for option" '("--pair")
           "too many arguments for --pair"
           (lambda () (parse '("--pair" "1" "2" "--pair" "3" "4"))))
     (list "option does not take arguments" '("--verbose")
           "--verbose does not take arguments"
           (lambda () (parse '("--verbose=1"))))
     (list "missing required option" '("--input")
           "missing required option --input"
           (lambda () (parse-required '())))
     (list "missing required option" '("-k")
           "missing required option -k"
           (lambda () (parse-required-short '())))
     (list "too few positional arguments" '("file")
           "missing positional argument <file>"
           (lambda () (parse-one '())))
     (list "too many positional arguments" '("b" "c")
           "too many positional arguments: b c"
           (lambda () (parse-one '("a" "b" "c"))))
     (list "unexpected positional argument" '("a")
           "unexpected positional argument: a"
           (lambda () (parse-none '("a"))))
     (list "unexpected positional argument" '("a b" "c")
           "unexpected positional argument: \"a b\" c"
           (lambda () (parse-none '("a b" "c"))))))

  (define-test test-the-report-says-which-option-and-which-text
    (when run-capturing-exit-and-error
      (for-each
       (lambda (row)
         (CHECK equal? (list (cadr row) (report-sentence (report-text (cadddr row))))
                (list (cadr row) (string-append prog ": " (caddr row)))))
       report-rows)))

  (define-test test-the-report-is-the-sentence-and-the-usage
    (when run-capturing-exit-and-error
      (CHECK equal? (report-text (lambda () (parse '("-n" "abc"))))
             (string-append prog ": invalid argument \"abc\" for -n\n\n"
                            ((parse '()) "usage")))
      (CHECK equal? (report-text (lambda () (parse-required '())))
             (string-append prog ": missing required option --input\n\n"
                            ((parse-required '("-i" "a")) "usage")))))

  (define-test test-the-message-and-the-details-of-the-condition-are-not-changed
    (for-each
     (lambda (row)
       (let ([e (raised (cadddr row))])
         (CHECK equal? (list (cadr row) (condition-message e) (condition-irritants e))
                (list (cadr row) (car row) (cadr row)))))
     (map (lambda (row) (list (car row) (cadr row) (caddr row) (cadddr row))) report-rows)))

  ;; ========================================
  ;; accessor errors
  ;; ========================================

  (define-test test-accessor-unknown-option
    (let ([option (parse '())])
      (CHECK equal? (error-message (lambda () (option "z"))) "unknown option")
      (CHECK equal? (error-message (lambda () (option "nope"))) "unknown option")
      (CHECK equal? (error-message (lambda () (option "-n"))) "unknown option")
      (CHECK equal? (error-message (lambda () (option "--count"))) "unknown option")
      (CHECK equal? (error-message (lambda () (option "h"))) "unknown option")))

  (define-test test-accessor-unknown-option-lists-the-names-that-exist
    (let ([option (parse '())])
      (CHECK equal? (error-irritants (lambda () (option "nope")))
             '("nope" ("v" "verbose" "q" "n" "count" "x" "ratio" "b" "flag" "s" "name" "f" "files"
                       "r" "range" "p" "pair" "u" "upper" "o" "opt-list" "args")))
      ;; the first irritant is the key as it was given, a symbol stays a symbol
      (CHECK equal? (car (error-irritants (lambda () (option 'nope)))) 'nope)
      (CHECK equal? (error-irritants (lambda () (option "h")))
             (list "h" (cadr (error-irritants (lambda () (option "nope"))))))))

  (define-test test-accessor-unknown-name-with-dashes-says-names-have-no-dashes
    (let ([option (parse '())])
      (CHECK equal? (error-irritants (lambda () (option "-n")))
             '("-n" "names are read without the dashes"))
      (CHECK equal? (error-irritants (lambda () (option "--count")))
             '("--count" "names are read without the dashes"))
      (CHECK equal? (error-irritants (lambda () (option (sym "-n"))))
             (list (sym "-n") "names are read without the dashes"))))

  (define-test test-accessor-invalid-key
    (let ([option (parse '())])
      (CHECK equal? (error-message (lambda () (option 1.5))) "invalid option key")
      (CHECK equal? (error-message (lambda () (option #\a))) "invalid option key")
      (CHECK equal? (error-message (lambda () (option '(1)))) "invalid option key")))

  ;; ========================================
  ;; (option "name" default): the default is the value when the option was not given
  ;; ========================================

  (define-test test-default-is-the-value-of-an-option-that-was-not-given
    (let ([option (parse '())])
      (CHECK eqv? (option "n" 3) 3)
      (CHECK equal? (option "s" "text") "text")
      (CHECK equal? (option "files" '("a")) '("a"))
      (CHECK equal? (option "range" '(0 9)) '(0 9))))

  (define-test test-default-is-not-used-when-the-option-was-given
    (let ([option (parse '("-n" "5" "-s" "x" "-f" "a" "b"))])
      (CHECK eqv? (option "n" 3) 5)
      (CHECK equal? (option "s" "text") "x")
      (CHECK equal? (option "files" '("d")) '("a" "b"))))

  (define-test test-default-of-a-flag
    (CHECK eq? ((parse '()) "q" 'unset) 'unset)
    (CHECK eq? ((parse '("-q")) "q" 'unset) #t))

  (define-test test-an-option-given-without-arguments-is-given
    ;; -o takes zero or more arguments: -o alone is given, with no arguments
    (CHECK equal? ((parse '("-o")) "opt-list" '("d")) '())
    (CHECK equal? ((parse '()) "opt-list" '("d")) '("d")))

  (define-test test-default-tells-not-given-from-given-as-false
    (CHECK eq? ((parse '("-b" "off")) "b" 'unset) #f)
    (CHECK eq? ((parse '("-b" "on")) "b" 'unset) #t)
    (CHECK eq? ((parse '()) "b" 'unset) 'unset))

  (define-test test-default-may-be-any-value
    (CHECK eq? ((parse '()) "n" #f) #f)
    (CHECK equal? ((parse '()) "n" '()) '())
    (CHECK eqv? ((parse '()) "n" (+ 1 2)) 3))

  (define-test test-default-of-the-positional-is-for-no-words
    (CHECK equal? ((parse '()) "args" '("none")) '("none"))
    (CHECK equal? ((parse '("a" "b")) "args" '("none")) '("a" "b"))
    (CHECK equal? ((parse '()) "args") '()))

  (define-test test-the-default-does-not-hide-a-wrong-name
    (CHECK equal? (error-message (lambda () ((parse '()) "nope" 1))) "unknown option")
    (CHECK equal? (error-message (lambda () ((parse '()) 42 1))) "invalid option key"))

  (define-test test-usage-ignores-the-default
    (let ([option (parse '())])
      (CHECK equal? (option "usage" 'x) (option "usage"))))

  (define-test test-no-default-is-as-before
    (let ([option (parse '())])
      (CHECK eq? (option "n") #f)
      (CHECK equal? (option "files") '())
      (CHECK eq? (option "q") #f)))

  (define-test test-at-most-one-default
    (CHECK eq? (guard (e [#t 'raised]) ((parse '()) "n" 1 2) 'returned) 'raised))

  ;; ========================================
  ;; names may also be given as symbols
  ;; ========================================
  ;; strict R6RS readers (Chez .sls) cannot read -v or --long as symbols, so build them

  (define (sym s) (string->symbol s))

  (define-test test-accessor-accepts-symbols
    (let ([option (parse '("-n" "4" "-v"))])
      (CHECK eqv? (option (sym "n")) 4)
      (CHECK eqv? (option (sym "count")) 4)
      (CHECK eq? (option (sym "verbose")) #t)
      (CHECK eq? (option (sym "q")) #f)))

  (define-test test-accessor-unknown-symbol-option
    (let ([option (parse '())])
      (CHECK equal? (error-message (lambda () (option (sym "z")))) "unknown option")))

  (define-test test-definition-accepts-symbols
    (let* ([form `(let ()
                    (define-command-line-options p
                      [:short ,(sym "-a") :long ,(sym "--alpha") :arity 1 :type int])
                    p)]
           [p (eval form (environment '(rnrs (6)) '(rime command-line-options)))]
           [option (p '("--alpha" "5"))])
      (CHECK eqv? (option "a") 5)
      (CHECK eqv? (option "alpha") 5)
      (CHECK eqv? (option (sym "a")) 5)))

  (define-test test-definition-symbol-and-string-conflict-is-duplicate
    (CHECK eq? (syntax-error?
                `(let ()
                   (define-command-line-options p
                     [:short ,(sym "-a")] [:short "-a"])
                   p))
           #t))

  ;; ========================================
  ;; independent parsers
  ;; ========================================

  (define-test test-two-parse-results-are-independent
    (let ([a (parse '("-n" "1"))]
          [b (parse '("-n" "2" "x"))])
      (CHECK eqv? (a "n") 1)
      (CHECK eqv? (b "n") 2)
      (CHECK eqv? (positional-count a) 0)
      (CHECK eqv? (positional-count b) 1)))

  (define-command-line-options other
    [:short "-n" :long "--number" :arity 1 :type string :description "string number"])

  (define-test test-second-definition-is-independent
    (CHECK equal? ((other '("-n" "7")) "number") "7")
    (CHECK eqv? ((parse '("-n" "7")) "count") 7))

  ;; ========================================
  ;; defaults in the definition
  ;; ========================================

  (define-command-line-options shuffled
    [:short "-a" :description "d" :type int :arity 1 :long "--alpha"])
  (define-command-line-options minimal
    [:short "-m"])
  (define-command-line-options three
    [:short "-t" :arity 3 :type int])
  (define-command-line-options exactly-one
    [:short "-e" :arity (1 1) :type int])
  (define-command-line-options flag
    [:short "-g" :arity (0 0)])
  (define-command-line-options none)

  (define-test test-clause-fields-in-any-order
    (CHECK eqv? ((shuffled '("--alpha" "9")) "a") 9))

  (define-test test-clause-minimal
    (CHECK equal? ((minimal '("-m" "x")) "m") "x"))

  (define-test test-arity-shorthand-n
    (CHECK equal? ((three '("-t" "1" "2" "3")) "t") '(1 2 3)))

  (define-test test-arity-pair-same-min-max-is-exact
    (CHECK eqv? ((exactly-one '("-e" "5")) "e") 5)
    (CHECK eq? ((exactly-one '()) "e") #f))

  (define-test test-arity-pair-0-0-is-flag
    (CHECK eq? ((flag '("-g")) "g") #t)
    (CHECK eq? ((flag '()) "g") #f))

  (define-test test-no-options-defined
    (CHECK eq? (procedure? (none '())) #t)
    (CHECK equal? (error-message (lambda () (none '("a" "b")))) "unexpected positional argument"))

  ;; ========================================
  ;; definition errors, detected at expansion time
  ;; ========================================

  (define-test test-syntax-error-type-with-arity-0
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p [:short "-a" :arity 0 :type int])
                   p))
           #t))

  (define-test test-syntax-error-type-with-implicit-arity-0-pair
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p [:short "-a" :arity (0 0) :type int])
                   p))
           #t))

  (define-test test-syntax-error-min-greater-than-max
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p [:short "-a" :arity (3 2)])
                   p))
           #t))

  (define-test test-syntax-error-negative-arity
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p [:short "-a" :arity -1])
                   p))
           #t))

  (define-test test-syntax-error-bad-arity-form
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p [:short "-a" :arity (1 2 3)])
                   p))
           #t)
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p [:short "-a" :arity many])
                   p))
           #t))

  (define-test test-syntax-error-duplicate-short-name
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p [:short "-a"] [:short "-a"])
                   p))
           #t))

  (define-test test-syntax-error-duplicate-long-name
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p [:short "-a" :long "--x"] [:short "-b" :long "--x"])
                   p))
           #t))

  (define-test test-syntax-error-reserved-help
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p [:short "-h"])
                   p))
           #t)
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p [:short "-a" :long "--help"])
                   p))
           #t))

  (define-test test-syntax-error-bad-short-name
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p [:short "a"])
                   p))
           #t)
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p [:short "--abc"])
                   p))
           #t))

  (define-test test-syntax-error-bad-long-name
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p [:short "-a" :long "x"])
                   p))
           #t)
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p [:short "-a" :long "-x"])
                   p))
           #t))

  (define-test test-syntax-error-unknown-field
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p [:short "-a" :colour red])
                   p))
           #t))

  (define-test test-syntax-error-field-without-value
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p [:short "-a" :long])
                   p))
           #t))

  (define-test test-syntax-error-duplicate-field
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p [:short "-a" :arity 1 :arity 2])
                   p))
           #t))

  (define-test test-syntax-error-description-not-string
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p [:short "-a" :description 42])
                   p))
           #t))

  (define-test test-syntax-error-option-name-is-not-string-or-symbol
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p [:short 42])
                   p))
           #t)
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p [:short "-a" :long 42])
                   p))
           #t))

  (define-test test-syntax-error-clause-is-not-a-list
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p "-a")
                   p))
           #t))

  (define-test test-syntax-error-name-is-not-identifier
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options "p" [:short "-a"])
                   1))
           #t))

  ;; ========================================
  ;; options without a short name
  ;; ========================================

  (define-command-line-options mixed-names
    [:short "-s" :arity 0 :description "short only"]
    [:long "--long-only" :type int :description "long only"]
    [:short "-b" :long "--both" :description "both names"]
    [:long "--flag-only" :arity 0 :description "a long flag"])

  (define-test test-long-only-option
    (let ([option (mixed-names '("--long-only" "3"))])
      (CHECK eqv? (option "long-only") 3)
      (CHECK eq? (option "s") #f)))

  (define-test test-long-only-option-with-equals
    (let ([option (mixed-names '("--long-only=4"))])
      (CHECK eqv? (option "long-only") 4)))

  (define-test test-long-only-flag
    (let ([option (mixed-names '("--flag-only"))])
      (CHECK eq? (option "flag-only") #t)
      (CHECK eq? ((mixed-names '()) "flag-only") #f)))

  (define-test test-long-only-option-absent
    (CHECK eq? ((mixed-names '()) "long-only") #f))

  (define-test test-short-only-option
    (let ([option (mixed-names '("-s"))])
      (CHECK eq? (option "s") #t)))

  (define-test test-option-with-both-names
    (CHECK equal? ((mixed-names '("-b" "x")) "both") "x")
    (CHECK equal? ((mixed-names '("--both" "y")) "b") "y"))

  (define-test test-names-that-were-not-given-are-unknown
    ;; --long-only has no short name, -s has no long name
    (let ([option (mixed-names '())])
      (CHECK equal? (error-message (lambda () (option "l"))) "unknown option")
      (CHECK equal? (error-message (lambda () (option "short-only"))) "unknown option")))

  (define-test test-options-without-a-short-name-are-independent
    ;; each option is told apart by itself, not by a name
    (let ([option (mixed-names '("--long-only" "7" "--flag-only"))])
      (CHECK eqv? (option "long-only") 7)
      (CHECK eq? (option "flag-only") #t)
      (CHECK eq? (option "s") #f)
      (CHECK eq? (option "b") #f)))

  (define env (environment '(rnrs (6)) '(rime command-line-options)))

  ;; a parser of `count` options that only have a long name, --option-0 ... --option-<count-1>
  (define (many-long-options count)
    (eval `(let ()
             (define-command-line-options p
               ,@(map (lambda (i)
                        (list ':long (string-append "--option-" (number->string i))
                              ':type 'int))
                      (iota* count)))
             p)
          env))

  (define (iota* n)
    (let loop ([i (- n 1)] [acc '()])
      (if (< i 0) acc (loop (- i 1) (cons i acc)))))

  (define-test test-more-options-than-letters
    ;; a one-letter short name would limit the options to 52
    (let* ([parse (many-long-options 300)]
           [option (parse '("--option-0=10" "--option-57" "58" "--option-299=3"))])
      (CHECK eqv? (option "option-0") 10)
      (CHECK eqv? (option "option-57") 58)
      (CHECK eqv? (option "option-299") 3)
      (CHECK eq? (option "option-1") #f)
      (CHECK eq? (option "option-298") #f)
      (CHECK equal? (error-message (lambda () (option "option-300"))) "unknown option")))

  (define-test test-an-option-without-any-name-is-a-syntax-error
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p [:arity 1])
                   p))
           #t)
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p [])
                   p))
           #t))

  (define-test test-old-syntax-with-a-leading-name-is-a-syntax-error
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p ["-a" :long "--alpha"])
                   p))
           #t))

  (define-test test-duplicate-names-without-short-names
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p [:long "--x"] [:long "--x"])
                   p))
           #t))

  (define-command-line-options long-only-parser
    [:short "-a" :long "--alpha" :type int :description "both"]
    [:long "--beta" :arity 0 :description "long only"]
    [:short "-c" :arity 0 :description "short only"])

  (define-test test-usage-aligns-long-only-names
    (CHECK string=?
           (help-text long-only-parser)
           (string-append
            "Usage: " prog " [options]\n"
            "\n"
            "Options:\n"
            "  -a, --alpha <int>  both\n"
            "      --beta         long only\n"
            "  -c                 short only\n"
            "  -h, --help         show this help message and exit\n")))

  ;; ========================================
  ;; choices
  ;; ========================================

  (define-command-line-options with-choices
    [:short "-f" :long "--format" :choices ("json" "text" "yaml") :description "output format"]
    [:long "--level" :choices (1 2 4) :description "verbosity level"]
    [:short "-m" :long "--mode" :arity (1 +) :choices ("a" "b" "c")]
    [:long "--delta" :choices (-1 0 1)]
    [:short "-v" :arity 0 :description "a flag"])

  (define (error-irritants thunk)
    (guard (e [(error? e) (condition-irritants e)])
      (thunk)
      #f))

  (define-test test-choice-is-accepted-and-returned-as-it-is
    (let ([option (with-choices '("--format" "json"))])
      (CHECK equal? (option "format") "json")
      (CHECK equal? (option "f") "json")))

  (define-test test-choice-in-every-argument-form
    (CHECK equal? ((with-choices '("-f" "text")) "format") "text")
    (CHECK equal? ((with-choices '("--format" "yaml")) "f") "yaml")
    (CHECK equal? ((with-choices '("--format=json")) "f") "json")
    (CHECK equal? ((with-choices '("-f=text")) "f") "text"))

  (define-test test-integer-choices-give-integers
    (let ([option (with-choices '("--level" "4"))])
      (CHECK eqv? (option "level") 4))
    (CHECK eqv? ((with-choices '("--level=1")) "level") 1))

  (define-test test-negative-integer-choice-with-the-escape
    (CHECK eqv? ((with-choices '("--delta" "\\-1")) "delta") -1)
    (CHECK eqv? ((with-choices '("--delta" "0")) "delta") 0))

  (define-test test-every-argument-is-checked
    (CHECK equal? ((with-choices '("-m" "a" "c" "b")) "mode") '("a" "c" "b"))
    (CHECK equal? ((with-choices '("--mode=a")) "m") '("a"))
    (CHECK equal? (error-message (lambda () (with-choices '("--mode=a,b"))))
           "argument must be one of the choices")
    (CHECK equal? (error-message (lambda () (with-choices '("-m" "a" "x"))))
           "argument must be one of the choices"))

  (define-test test-choices-absent
    (let ([option (with-choices '())])
      (CHECK eq? (option "format") #f)
      (CHECK eq? (option "level") #f)
      (CHECK equal? (option "mode") '())))

  (define-test test-wrong-choice-message-and-irritants
    (CHECK equal? (error-message (lambda () (with-choices '("--format" "xml"))))
           "argument must be one of the choices")
    (CHECK equal? (error-irritants (lambda () (with-choices '("--format" "xml"))))
           '("--format" "xml" ("json" "text" "yaml")))
    (CHECK equal? (error-irritants (lambda () (with-choices '("-f" "xml"))))
           '("-f" "xml" ("json" "text" "yaml"))))

  (define-test test-wrong-integer-choice
    (CHECK equal? (error-irritants (lambda () (with-choices '("--level" "3"))))
           '("--level" "3" (1 2 4)))
    (CHECK equal? (error-message (lambda () (with-choices '("--level" "abc"))))
           "argument must be one of the choices"))

  (define-test test-choices-are-exact-and-case-sensitive
    (CHECK equal? (error-message (lambda () (with-choices '("--format" "JSON"))))
           "argument must be one of the choices")
    (CHECK equal? (error-message (lambda () (with-choices '("--format" "jso"))))
           "argument must be one of the choices")
    (CHECK equal? (error-message (lambda () (with-choices '("--format" " json"))))
           "argument must be one of the choices")
    (CHECK equal? (error-message (lambda () (with-choices '("--level" "04"))))
           "argument must be one of the choices")
    (CHECK equal? (error-message (lambda () (with-choices '("--format="))))
           "argument must be one of the choices"))

  (define-test test-a-conversion-error-is-still-a-different-message
    (CHECK equal? (error-message (lambda () (parse '("-n" "abc")))) "invalid argument value"))

  (define-command-line-options choices-usage-parser
    [:short "-f" :long "--format" :choices ("json" "text" "yaml") :description "output format"]
    [:long "--level" :choices (1 2 4) :description "verbosity level"]
    [:short "-m" :long "--mode" :arity (1 +) :choices ("a" "b" "c") :description "mode"]
    [:short "-n" :long "--num" :arity (0 2) :choices ("x" "y") :description "number"])

  (define-test test-choices-in-the-usage-text
    (let ([usage (help-text choices-usage-parser)])
      (CHECK eq? (and (contains? usage "-f, --format {json,text,yaml}  output format") #t) #t)
      (CHECK eq? (and (contains? usage "    --level {1,2,4}") #t) #t)
      (CHECK eq? (and (contains? usage "-m, --mode {a,b,c}...") #t) #t)
      (CHECK eq? (and (contains? usage "-n, --num [{x,y}] [{x,y}]") #t) #t)
      (CHECK eq? (and (contains? usage "<string>") #t) #f)))

  (define-command-line-options choices-aligned-parser
    [:short "-f" :long "--format" :choices ("json" "text") :description "output format"]
    [:short "-v" :long "--verbose" :arity 0 :description "verbose"])

  (define-test test-choices-are-aligned-with-the-other-options
    (CHECK string=?
           (help-text choices-aligned-parser)
           (string-append
            "Usage: " prog " [options]\n"
            "\n"
            "Options:\n"
            "  -f, --format {json,text}  output format\n"
            "  -v, --verbose             verbose\n"
            "  -h, --help                show this help message and exit\n")))

  (define-test test-choices-show-in-the-help-of-a-parser
    (let ([usage (help-text with-choices)])
      (CHECK eq? (and (contains? usage "-f, --format {json,text,yaml}") #t) #t)
      (CHECK eq? (and (contains? usage "--level {1,2,4}") #t) #t)
      (CHECK eq? (and (contains? usage "-m, --mode {a,b,c}...") #t) #t)
      (CHECK eq? (and (contains? usage "--delta {-1,0,1}") #t) #t)))

  (define-test test-a-flag-next-to-choices-still-works
    (CHECK eq? ((with-choices '("-v" "--format" "json")) "v") #t))

  (define-test test-choices-on-a-flag-is-a-syntax-error
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p [:short "-a" :arity 0 :choices ("x")])
                   p))
           #t))

  (define-test test-choices-and-type-together-is-a-syntax-error
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p [:short "-a" :type int :choices (1 2)])
                   p))
           #t)
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p [:short "-a" :choices (1 2) :type int])
                   p))
           #t))

  (define-test test-bad-choices-are-syntax-errors
    (for-each
     (lambda (form)
       (CHECK eq? (syntax-error? form) #t))
     '((let () (define-command-line-options p [:short "-a" :choices ()]) p)
       (let () (define-command-line-options p [:short "-a" :choices ("x" "x")]) p)
       (let () (define-command-line-options p [:short "-a" :choices "x"]) p)
       (let () (define-command-line-options p [:short "-a" :choices (x)]) p)
       (let () (define-command-line-options p [:short "-a" :choices (1.5)]) p)
       (let () (define-command-line-options p [:short "-a" :choices (1.0)]) p))))

  (define-test test-choice-keyword-is-exported
    (CHECK eq?
           (guard (e [else #f])
             (environment '(only (rime command-line-options) :choices))
             #t)
           #t))

  ;; ========================================
  ;; keywords
  ;; ========================================

  (define-test test-keywords-are-exported
    (CHECK eq?
           (guard (e [else #f])
             (environment '(only (rime command-line-options) :long :arity :type :description))
             #t)
           #t))

  (define-test test-keywords-are-auxiliary-syntax
    ;; using a keyword as an expression is a syntax violation, not an unbound variable
    (for-each
     (lambda (keyword)
       (CHECK eq? (syntax-error? keyword) #t))
     '(:long :arity :type :description)))

  (define-test test-valid-definition-is-not-syntax-error
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p [:short "-a" :long "--alpha" :arity (1 +) :type int])
                   p))
           #f))

  ;; ========================================
  ;; help
  ;; ========================================

  (define (spaces n) (make-string n #\space))

  (define-command-line-options usage-parser
    [:short "-v" :long "--verbose" :arity 0 :description "verbose output"]
    [:short "-n" :long "--count" :type int :description "repeat count"]
    [:short "-f" :long "--files" :arity (1 +) :description "input files"]
    [:short "-r" :long "--range" :arity (0 2) :type int :description "range"]
    [:short "-q" :arity 0 :description "quiet"]
    [:short "-u" :long "--upper" :type string-upcase :description "first line\nsecond line"])

  ;; the usage of a parser; -h skips the required options and the words, so any parser gives it
  (define (help-text parser)
    ((parser '("--help")) "usage"))

  (define-test test-usage-of-a-parser
    (CHECK string=?
           (help-text usage-parser)
           (string-append
            "Usage: " prog " [options]\n"
            "\n"
            "Options:\n"
            "  -v, --verbose" (spaces 16) "verbose output\n"
            "  -n, --count <int>" (spaces 12) "repeat count\n"
            "  -f, --files <string>..." (spaces 6) "input files\n"
            "  -r, --range [<int>] [<int>]" (spaces 2) "range\n"
            "  -q" (spaces 27) "quiet\n"
            "  -u, --upper <value>" (spaces 10) "first line\n"
            (spaces 31) "second line\n"
            "  -h, --help" (spaces 19) "show this help message and exit\n")))

  (define (split-lines text)
    (let loop ([chars (string->list text)] [line '()] [acc '()])
      (cond [(null? chars) (reverse acc)]
            [(char=? (car chars) #\newline)
             (loop (cdr chars) '() (cons (list->string (reverse line)) acc))]
            [else (loop (cdr chars) (cons (car chars) line) acc)])))

  (define (contains? text part)
    (let ([n (string-length text)] [m (string-length part)])
      (let loop ([i 0])
        (cond [(> (+ i m) n) #f]
              [(string=? (substring text i (+ i m)) part) #t]
              [else (loop (+ i 1))]))))

  (define-test test-usage-column-is-aligned
    ;; every row has its description at column 31
    (let ([rows (filter (lambda (l) (and (> (string-length l) 31)
                                         (char=? (string-ref l 2) #\-)))
                        (split-lines (help-text usage-parser)))])
      (CHECK eqv? (length rows) 7)
      (for-each
       (lambda (row)
         (CHECK equal? (substring row 29 31) "  ")
         (CHECK eq? (char=? (string-ref row 31) #\space) #f))
       rows)))

  (define-command-line-options placeholder-parser
    [:short "-a" :arity 2 :type int :description "d"]
    [:short "-b" :arity (0 +) :description "d"]
    [:short "-c" :arity (1 3) :type float :description "d"])

  (define-test test-usage-placeholders
    (let ([usage (help-text placeholder-parser)])
      (CHECK eq? (and (contains? usage "-a <int> <int>") #t) #t)
      (CHECK eq? (and (contains? usage "-b [<string>...]") #t) #t)
      (CHECK eq? (and (contains? usage "-c <float> [<float>] [<float>]") #t) #t)))

  (define-command-line-options no-options-parser)

  (define-test test-usage-without-options
    (CHECK string=?
           (help-text no-options-parser)
           (string-append
            "Usage: " prog " [options]\n"
            "\n"
            "Options:\n"
            "  -h, --help  show this help message and exit\n")))

  (define-test test-help-short-is-reported
    (let ([option (usage-parser '("-h"))])
      (CHECK eq? (option "help") #t)
      (CHECK equal? (option "usage") (help-text usage-parser))
      (CHECK eq? (option "v") #f)))

  (define-test test-help-long-is-reported
    (CHECK eq? ((usage-parser '("-v" "--help")) "help") #t))

  (define-test test-help-after-positional-is-reported
    (CHECK eq? ((usage-parser '("a" "--help")) "help") #t))

  (define-test test-help-as-option-argument-is-escapable
    (let ([option (usage-parser '("-u" "\\-h"))])
      (CHECK eq? (option "help") #f)
      (CHECK equal? (option "u") "-H")))

  ;; ========================================
  ;; the help flag of the defined parser
  ;; ========================================

  (define-test test-the-parser-reports-help-instead-of-exiting
    (let ([option (parse '("-v" "-h" "-n" "5"))])
      ;; the parse goes on to return an accessor, and the usage is the text of this parser
      (CHECK eq? (procedure? option) #t)
      (CHECK eq? (option "help") #t)
      (CHECK equal? (option "usage") ((parse '()) "usage"))
      ;; what came before -h was read, what came after was not
      (CHECK eq? (option "v") #t)
      (CHECK equal? (option "n") #f)))

  (define-test test-help-is-false-when-help-is-not-asked
    (CHECK eq? ((parse '("-v" "-n" "5")) "help") #f)
    (CHECK eq? ((parse '()) "help") #f))

  (define-test test-help-skips-the-required-checks
    (CHECK eq? ((parse-required '("--help")) "help") #t)
    (CHECK eq? ((parse-one '("-h")) "help") #t))

  (define-test test-help-follows-the-default-rule
    ;; a default is used when -h was not given, and the flag is the value when it was
    (CHECK equal? ((parse '()) "help" 'x) 'x)
    (CHECK eq? ((parse '("-h")) "help" 'x) #t))

  (define-test test-the-parser-still-takes-the-arguments-alone
    (CHECK equal? ((parse '("-n" "7")) "n") 7))

  ;; The real -h path of a macro-defined parser prints usage and calls (exit 0).
  ;; exit and the output port are intercepted through eval in an implementation specific
  ;; environment (cf. rime/rime-0/__feature-registry.sls); the test is skipped elsewhere.
  (define (try-environment import-spec)
    (guard (e [else #f]) (environment import-spec)))

  (define chez-environment (try-environment '(chezscheme)))
  (define guile-environment (try-environment '(guile)))

  ;; (run-capturing-exit thunk) => (exit-code . printed-text), or #f when unsupported
  (define run-capturing-exit
    (cond
     [chez-environment
      (eval '(lambda (thunk)
               (let* ([exit-code 'exit-not-called]
                      [output
                       (call-with-string-output-port
                        (lambda (port)
                          (parameterize ([current-output-port port])
                            (call/cc
                             (lambda (return)
                               (parameterize ([exit-handler
                                               (lambda codes
                                                 (set! exit-code (if (null? codes) 0 (car codes)))
                                                 (return #f))])
                                 (thunk)))))))])
                 (cons exit-code output)))
            chez-environment)]
     [guile-environment
      (eval '(lambda (thunk)
               (let* ([exit-code 'exit-not-called]
                      [output
                       (with-output-to-string
                         (lambda ()
                           (catch 'quit
                             thunk
                             (lambda (key . codes)
                               (set! exit-code (if (null? codes) 0 (car codes)))))))])
                 (cons exit-code output)))
            guile-environment)]
     [else #f]))

  (define-command-line-options helpful
    [:short "-v" :long "--verbose" :arity 0 :description "verbose output"]
    [:short "-n" :long "--count" :arity 1 :type int :description "repeat count"]
    [:short "-f" :long "--files" :arity (1 +) :description "input files"])

  (define helpful-usage
    (string-append
     "Usage: " prog " [options]\n"
     "\n"
     "Options:\n"
     "  -v, --verbose" (spaces 12) "verbose output\n"
     "  -n, --count <int>" (spaces 8) "repeat count\n"
     "  -f, --files <string>..." (spaces 2) "input files\n"
     "  -h, --help" (spaces 15) "show this help message and exit\n"))

  (define-test test-parse-or-exit-short-help-prints-usage-and-exits
    (when run-capturing-exit
      (let ([result (run-capturing-exit (lambda () (parse-or-exit helpful '("-h"))))])
        (CHECK eqv? (car result) 0)
        (CHECK string=? (cdr result) helpful-usage))))

  (define-test test-parse-or-exit-long-help-prints-usage-and-exits
    (when run-capturing-exit
      (let ([result (run-capturing-exit (lambda () (parse-or-exit helpful '("-v" "--help"))))])
        (CHECK eqv? (car result) 0)
        (CHECK string=? (cdr result) helpful-usage))))

  (define-test test-help-stops-parsing
    ;; options after -h are not parsed, so a bad one does not raise
    (when run-capturing-exit
      (let ([result (run-capturing-exit (lambda () (parse-or-exit helpful '("-h" "--nope"))))])
        (CHECK eqv? (car result) 0))))

  (define-command-line-options takes-words [:positional "words" :arity (0 +)])

  (define-test test-help-after-double-dash-does-not-exit
    (when run-capturing-exit
      (let ([result (run-capturing-exit (lambda () (parse-or-exit takes-words '("--" "-h"))))])
        (CHECK eq? (car result) 'exit-not-called)
        (CHECK equal? (cdr result) ""))))

  ;; (run-capturing-exit-and-error thunk) => (exit-code output error-output), or #f when unsupported
  (define run-capturing-exit-and-error
    (cond
     [chez-environment
      (eval '(lambda (thunk)
               (let* ([exit-code 'exit-not-called]
                      [error-text ""]
                      [output
                       (call-with-string-output-port
                        (lambda (out)
                          (set! error-text
                                (call-with-string-output-port
                                 (lambda (err)
                                   (parameterize ([current-output-port out] [current-error-port err])
                                     (call/cc
                                      (lambda (return)
                                        (parameterize ([exit-handler
                                                        (lambda codes
                                                          (set! exit-code (if (null? codes) 0 (car codes)))
                                                          (return #f))])
                                          (thunk))))))))))])
                 (list exit-code output error-text)))
            chez-environment)]
     [guile-environment
      (eval '(lambda (thunk)
               (let* ([exit-code 'exit-not-called]
                      [error-text ""]
                      [output
                       (with-output-to-string
                         (lambda ()
                           (set! error-text
                                 (with-error-to-string
                                  (lambda ()
                                    (catch 'quit
                                      thunk
                                      (lambda (key . codes)
                                        (set! exit-code (if (null? codes) 0 (car codes))))))))))])
                 (list exit-code output error-text)))
            guile-environment)]
     [else #f]))

  (define-test test-parse-or-exit-returns-the-accessor-when-the-command-line-is-fine
    (CHECK equal? ((parse-or-exit parse '("-n" "7")) "n") 7))

  (define-test test-parse-or-exit-exits-with-2-and-reports-on-the-error-port
    (when run-capturing-exit-and-error
      (let ([result (run-capturing-exit-and-error (lambda () (parse-or-exit parse '("-n" "abc"))))])
        (CHECK eqv? (car result) 2)
        (CHECK equal? (cadr result) "")
        (CHECK equal? (caddr result)
               (string-append prog ": invalid argument \"abc\" for -n\n\n"
                              ((parse '()) "usage"))))
      (let ([result (run-capturing-exit-and-error (lambda () (parse-or-exit parse-one '())))])
        (CHECK eqv? (car result) 2)
        (CHECK eq? (contains? (caddr result) "missing positional argument <file>") #t)
        (CHECK eq? (contains? (caddr result) "Usage: ") #t))))

  (define-test test-parse-or-exit-lets-the-other-errors-through
    (let ([e (raised (lambda () (parse-or-exit (lambda (arguments) (error 'mine "a bug")) '())))])
      (CHECK equal? (condition-message e) "a bug")
      (CHECK eq? (command-line-error? e) #f)))

  (define-test test-parse-or-exit-prints-the-usage-to-the-output-port
    (when run-capturing-exit-and-error
      (let ([result (run-capturing-exit-and-error (lambda () (parse-or-exit helpful '("-h"))))])
        (CHECK eqv? (car result) 0)
        (CHECK equal? (cadr result) helpful-usage)
        (CHECK equal? (caddr result) ""))))

  (define-test test-help-is-not-a-user-option
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p [:short "-h" :long "--help"])
                   p))
           #t))

  ;; (command-line) is ("") when there is no script: a REPL, or a program given with --eval

  ;; a converter that nothing in the runtime knows about: it brings its label, and it reports
  ;; its own failure, given the text and the name of the option

  ;; ========================================
  ;; options and positional words in any order
  ;; ========================================

  (define-command-line-options parse-mixed
    [:short "-emit" :long "--emit" :description "action"]
    [:short "-opt" :long "--opt" :arity 0 :description "run the optimizer"]
    [:short "-x" :long "--x" :description "kind of input"]
    [:short "-v" :arity 0 :description "verbose"]
    [:short "-e" :arity (1 +) :description "words"]
    [:positional "files" :arity (0 +)])

  (define (positionals option) (option "files"))

  ;; (emit opt x positional) of the command line
  (define (mixed args)
    (let ([option (parse-mixed args)])
      (list (option "emit") (option "opt") (option "x") (positionals option))))

  (define-test test-mixed-option-before-positional
    (CHECK equal? (mixed '("--emit=ast" "example.toy")) '("ast" #f #f ("example.toy"))))

  (define-test test-mixed-option-after-positional
    (CHECK equal? (mixed '("example.toy" "--emit=ast")) '("ast" #f #f ("example.toy"))))

  (define-test test-mixed-lone-dash-is-positional
    (CHECK equal? (mixed '("-" "--emit=ast")) '("ast" #f #f ("-"))))

  (define-test test-mixed-option-argument-after-positional
    (CHECK equal? (mixed '("example.toy" "-emit" "ast")) '("ast" #f #f ("example.toy"))))

  (define-test test-mixed-flag-after-positional
    (CHECK equal? (mixed '("example.toy" "-emit=mlir" "-opt")) '("mlir" #t #f ("example.toy"))))

  (define-test test-mixed-option-before-and-after-positional
    (CHECK equal? (mixed '("-x" "mlir" "driver-input.txt" "-emit=mlir"))
           '("mlir" #f "mlir" ("driver-input.txt")))
    (CHECK equal? (mixed '("driver-input.txt" "-x" "mlir" "-emit=mlir"))
           '("mlir" #f "mlir" ("driver-input.txt"))))

  (define-test test-mixed-positional-only
    (CHECK equal? (mixed '("example.toy")) '(#f #f #f ("example.toy"))))

  (define-test test-mixed-double-dash-ends-options
    (CHECK equal? (mixed '("example.toy" "--" "--emit=ast")) '(#f #f #f ("example.toy" "--emit=ast")))
    (CHECK equal? (mixed '("-opt" "--" "-x")) '(#f #t #f ("-x")))
    (CHECK equal? (mixed '("a" "--" "b" "-opt")) '(#f #f #f ("a" "b" "-opt"))))

  (define-test test-mixed-positional-order-is-kept
    (let ([option (parse-mixed '("a" "-v" "b" "-v" "c"))])
      (CHECK eq? (option "v") #t)
      (CHECK equal? (positionals option) '("a" "b" "c"))
      (CHECK eqv? (length (positionals option)) 3)))

  (define-test test-mixed-escaped-word-is-positional
    (CHECK equal? (positionals (parse-mixed '("a" "\\-x" "b"))) '("a" "-x" "b")))

  (define-test test-mixed-option-with-unlimited-arity-takes-ordinary-words
    (let ([option (parse-mixed '("a" "-e" "x" "y" "b"))])
      (CHECK equal? (option "e") '("x" "y" "b"))
      (CHECK equal? (positionals option) '("a"))))

  (define-test test-mixed-unlimited-arity-stops-at-an-option
    (let ([option (parse-mixed '("-e" "x" "y" "-v" "b"))])
      (CHECK equal? (option "e") '("x" "y"))
      (CHECK eq? (option "v") #t)
      (CHECK equal? (positionals option) '("b"))))

  (define-test test-mixed-last-occurrence-wins
    (CHECK equal? (mixed '("-emit=a" "f" "-emit=b")) '("b" #f #f ("f"))))

  (define-test test-mixed-undefined-dash-word-after-positional
    (CHECK equal? ((parse-mixed '("f" "--nope")) "files") '("f" "--nope")))
  ;; ========================================
  ;; (option 'usage), the usage as a string
  ;; ========================================

  (define-command-line-options parse-small
    [:short "-v" :long "--verbose" :arity 0 :description "verbose output"])

  (define-test test-help-key-returns-the-usage
    (CHECK equal? ((parse-small '()) 'usage)
           (string-append "Usage: " prog " [options]\n"
                          "\n"
                          "Options:\n"
                          "  -v, --verbose  verbose output\n"
                          "  -h, --help     show this help message and exit\n")))

  (define-test test-help-key-is-the-same-text-as-the-help-option
    (CHECK equal? ((usage-parser '()) 'usage) (help-text usage-parser)))

  (define-test test-help-key-does-not-start-the-help
    (CHECK eq? (string? ((parse '("-v")) 'usage)) #t)
    (CHECK eq? (contains? ((parse '()) 'usage) "--count") #t))

  ;; ========================================
  ;; :required, it is an error when the option is absent
  ;; ========================================

  (define-command-line-options parse-required
    [:short "-i" :long "--input" :required :description "input file"]
    [:short "-v" :arity 0 :description "verbose"]
    [:positional "rest" :arity (0 +)])

  (define-command-line-options parse-required-short
    [:short "-k" :required])

  (define-command-line-options parse-required-list
    [:short "-o" :arity (0 +) :required])

  (define-test test-required-given
    (let ([option (parse-required '("-i" "a"))])
      (CHECK equal? (option "i") "a")))

  (define-command-line-options parse-two-required
    [:short "-a" :long "--aa" :required]
    [:short "-b" :required]
    [:short "-c"])

  (define-test test-the-first-missing-required-option-is-named
    (CHECK equal? (error-irritants (lambda () (parse-two-required '()))) '("--aa"))
    (CHECK equal? (error-irritants (lambda () (parse-two-required '("-a" "x")))) '("-b"))
    (CHECK equal? ((parse-two-required '("-a" "x" "-b" "y")) "b") "y"))

  (define-test test-required-given-after-a-positional-word-in-the-equals-form
    (let ([option (parse-required '("f" "--input=a"))])
      (CHECK equal? (option "input") "a")
      (CHECK equal? (option "rest") '("f"))))

  (define-test test-required-missing
    (CHECK equal? (error-message (lambda () (parse-required '()))) "missing required option")
    (CHECK equal? (error-irritants (lambda () (parse-required '()))) '("--input")))

  (define-test test-required-missing-when-only-others-are-given
    (CHECK equal? (error-message (lambda () (parse-required '("-v" "file"))))
           "missing required option"))

  (define-test test-required-missing-names-the-short-name-when-there-is-no-long-name
    (CHECK equal? (error-irritants (lambda () (parse-required-short '()))) '("-k")))

  (define-test test-required-list-given-with-no-arguments-is-present
    (CHECK equal? ((parse-required-list '("-o")) "o") '()))

  (define-test test-required-list-missing
    (CHECK equal? (error-message (lambda () (parse-required-list '("a"))))
           "missing required option"))

  (define-test test-required-is-not-checked-when-help-is-asked
    (CHECK eq? (string? (help-text parse-required)) #t))

  (define-test test-syntax-error-required-on-a-flag
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p [:short "-a" :arity 0 :required])
                   p))
           #t))

  (define-test test-syntax-error-required-twice
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p [:short "-a" :required :required])
                   p))
           #t))

  (define-test test-syntax-error-required-takes-no-value
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p [:short "-a" :required #t])
                   p))
           #t))
  ;; ========================================
  ;; names without the dashes
  ;; ========================================

  (define-command-line-options parse-names
    [:short "-emit" :long "--emit" :description "action"]
    [:short "-v" :arity 0 :description "verbose"]
    [:long "--level" :type int :description "level"])

  (define-test test-lookup-names-have-no-dashes
    (let ([option (parse-names '("-emit" "ast" "-v" "--level" "3"))])
      (CHECK equal? (option "emit") "ast")
      (CHECK eq? (option "v") #t)
      (CHECK eqv? (option "level") 3)
      (CHECK eqv? (option 'level) 3)))

  (define-test test-lookup-names-with-dashes-are-unknown
    (let ([option (parse-names '())])
      (CHECK equal? (error-message (lambda () (option "-v"))) "unknown option")
      (CHECK equal? (error-message (lambda () (option "--level"))) "unknown option")
      (CHECK equal? (error-irritants (lambda () (option "--level")))
             '("--level" "names are read without the dashes"))))

  (define-test test-lookup-of-an-undefined-name
    (CHECK equal? (error-message (lambda () ((parse-names '()) "nope"))) "unknown option"))

  (define-test test-lookup-of-an-undefined-name-lists-the-names-of-the-options-once-each
    ;; -emit and --emit are one option and one name
    (CHECK equal? (error-irritants (lambda () ((parse-names '()) "nope")))
           '("nope" ("emit" "v" "level"))))

  (define-test test-usage-is-an-option-name
    (let ([option (parse-small '())])
      (CHECK equal? (option "usage") (option 'usage))
      (CHECK eq? (contains? (option "usage") "--verbose") #t)))

  (define-test test-syntax-error-short-and-long-name-of-different-options-clash
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p [:short "-x"] [:long "--x"])
                   p))
           #t))

  (define-test test-syntax-error-a-long-name-that-looks-like-the-help-name
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p [:long "--h"])
                   p))
           #t))

  ;; ========================================
  ;; positional arguments, :positional
  ;; ========================================

  (define-command-line-options parse-one [:positional "file"])

  (define-command-line-options parse-files [:positional "files" :arity (1 +)])

  (define-command-line-options parse-maybe [:positional "file" :arity (0 1)])

  (define-command-line-options parse-pair [:positional "pair" :arity 2 :type int])

  (define-command-line-options parse-mode
    [:short "-v" :arity 0 :description "verbose"]
    [:positional "mode" :choices ("fast" "slow")])

  (define-command-line-options parse-none [:short "-v" :arity 0])

  (define-test test-positional-default-arity-is-one
    (CHECK equal? ((parse-one '("a")) "file") "a"))

  (define-test test-positional-too-few
    (CHECK equal? (error-message (lambda () (parse-one '()))) "too few positional arguments")
    (CHECK equal? (error-irritants (lambda () (parse-one '()))) '("file")))

  (define-test test-positional-too-many
    (CHECK equal? (error-message (lambda () (parse-one '("a" "b" "c"))))
           "too many positional arguments")
    (CHECK equal? (error-irritants (lambda () (parse-one '("a" "b" "c")))) '("b" "c")))

  (define-test test-positional-with-unlimited-arity-is-a-list
    (CHECK equal? ((parse-files '("a" "b" "c")) "files") '("a" "b" "c"))
    (CHECK equal? ((parse-files '("a")) "files") '("a"))
    (CHECK equal? (error-message (lambda () (parse-files '()))) "too few positional arguments"))

  (define-test test-positional-optional-word
    (CHECK equal? ((parse-maybe '()) "file") '())
    (CHECK equal? ((parse-maybe '("a")) "file") '("a"))
    (CHECK equal? (error-message (lambda () (parse-maybe '("a" "b")))) "too many positional arguments"))

  (define-test test-positional-is-converted
    (CHECK equal? ((parse-pair '("1" "2")) "pair") '(1 2))
    (CHECK equal? (error-message (lambda () (parse-pair '("1" "x")))) "invalid argument value")
    (CHECK equal? (error-irritants (lambda () (parse-pair '("1" "x")))) '("pair" "x")))

  (define-test test-positional-choices
    (CHECK equal? ((parse-mode '("fast")) "mode") "fast")
    (CHECK equal? (error-message (lambda () (parse-mode '("x"))))
           "argument must be one of the choices")
    (CHECK equal? (error-irritants (lambda () (parse-mode '("x")))) '("mode" "x" ("fast" "slow"))))

  (define-test test-positional-and-options-in-any-order
    (CHECK eq? ((parse-mode '("-v" "fast")) "v") #t)
    (CHECK equal? ((parse-mode '("fast" "-v")) "mode") "fast")
    (CHECK eq? ((parse-mode '("fast" "-v")) "v") #t))

  (define-test test-positional-after-double-dash-and-escaped
    (CHECK equal? ((parse-files '("--" "-a" "-b")) "files") '("-a" "-b"))
    (CHECK equal? ((parse-files '("\\-a")) "files") '("-a")))

  (define-test test-positional-word-without-a-clause-is-an-error
    (CHECK equal? (error-message (lambda () (parse-none '("a")))) "unexpected positional argument")
    (CHECK equal? (error-irritants (lambda () (parse-none '("a" "b")))) '("a" "b"))
    (CHECK equal? (error-message (lambda () (parse-none '("--" "x")))) "unexpected positional argument"))

  (define-test test-no-positional-word-and-no-clause-is-fine
    (CHECK eq? ((parse-none '("-v")) "v") #t))

  (define-test test-help-needs-no-positional-word
    (CHECK eq? (string? (help-text parse-documented)) #t))

  ;; ========================================
  ;; usage with a positional
  ;; ========================================

  (define-command-line-options parse-documented
    [:short "-v" :arity 0 :description "verbose"]
    [:positional "file" :arity (1 +) :description "files to read"])

  (define-test test-usage-lists-the-positional
    (CHECK equal? ((parse-documented '("a")) 'usage)
           (string-append "Usage: " prog " [options] [--] <file>...\n"
                          "\n"
                          "Arguments:\n"
                          "  <file>...  files to read\n"
                          "\n"
                          "Options:\n"
                          "  -v          verbose\n"
                          "  -h, --help  show this help message and exit\n")))

  (define-command-line-options positional-exact [:positional "f"])
  (define-command-line-options positional-optional [:positional "f" :arity (0 1)])
  (define-command-line-options positional-one-or-more [:positional "f" :arity (1 +)])
  (define-command-line-options positional-any [:positional "f" :arity (0 +)])
  (define-command-line-options positional-two [:positional "f" :arity 2])

  (define-test test-usage-placeholders-of-a-positional
    (for-each
     (lambda (case)
       (let ([usage (help-text (car case))])
         (CHECK eq? (contains? usage (string-append " [options] [--] " (cadr case) "\n")) #t)))
     (list (list positional-exact "<f>")
           (list positional-optional "[<f>]")
           (list positional-one-or-more "<f>...")
           (list positional-any "[<f>...]")
           (list positional-two "<f> <f>"))))

  ;; ========================================
  ;; usage: :metavar
  ;; ========================================

  (define-command-line-options parse-metavar
    [:short "-i" :long "--input" :metavar "file" :description "file to read"]
    [:long "--pair" :arity 2 :metavar "n" :type int :description "two numbers"]
    [:short "-e" :arity (1 +) :metavar "pattern" :description "patterns"]
    [:long "--tag" :arity (0 +) :metavar "t"]
    [:short "-w" :arity (0 2) :metavar "n" :type int]
    [:short "-q" :arity 0 :description "quiet"])

  (define-test test-metavar-replaces-the-type-in-the-usage
    (CHECK equal? ((parse-metavar '()) 'usage)
           (string-append "Usage: " prog " [options]\n"
                          "\n"
                          "Options:\n"
                          "  -i, --input <file>  file to read\n"
                          "      --pair <n> <n>  two numbers\n"
                          "  -e <pattern>...     patterns\n"
                          "      --tag [<t>...]\n"
                          "  -w [<n>] [<n>]\n"
                          "  -q" (spaces 18) "quiet\n"
                          "  -h, --help" (spaces 10) "show this help message and exit\n")))

  (define-test test-metavar-does-not-change-how-the-arguments-are-read
    (let ([option (parse-metavar '("-i" "a.txt" "--pair" "1" "2" "-e" "x" "y"))])
      (CHECK equal? (option "input") "a.txt")
      (CHECK equal? (option "pair") '(1 2))
      (CHECK equal? (option "e") '("x" "y")))
    (CHECK equal? (error-message (lambda () (parse-metavar '("--pair" "1" "x")))) "invalid argument value"))

  (define-command-line-options parse-metavar-choices
    [:long "--format" :metavar "fmt" :choices ("json" "text") :description "output format"])

  (define-test test-metavar-replaces-the-choices-in-the-usage-and-they-are-still-checked
    (CHECK equal? ((parse-metavar-choices '()) 'usage)
           (string-append "Usage: " prog " [options]\n"
                          "\n"
                          "Options:\n"
                          "      --format <fmt>  output format\n"
                          "  -h, --help          show this help message and exit\n"))
    (CHECK equal? ((parse-metavar-choices '("--format" "json")) "format") "json")
    (CHECK equal? (error-message (lambda () (parse-metavar-choices '("--format" "xml"))))
           "argument must be one of the choices"))

  ;; ========================================
  ;; definition errors of :positional
  ;; ========================================

  (define-test test-syntax-error-two-positional-clauses-with-a-variable-arity
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p [:positional "a" :arity (1 +)] [:positional "b" :arity (0 1)])
                   p))
           #t))

  (define-test test-two-positional-clauses-with-exact-arities-are-fine
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p [:positional "a"] [:positional "b" :arity 2])
                   p))
           #f))

  (define-test test-syntax-error-positional-with-a-short-name
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p [:positional "a" :short "-a"])
                   p))
           #t))

  (define-test test-syntax-error-positional-with-a-long-name
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p [:positional "a" :long "--aa"])
                   p))
           #t))

  (define-test test-syntax-error-positional-is-not-required
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p [:positional "a" :required])
                   p))
           #t))

  (define-test test-syntax-error-positional-with-arity-0
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p [:positional "a" :arity 0])
                   p))
           #t))

  (define-test test-syntax-error-positional-name-starts-with-a-dash
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p [:positional "-a"])
                   p))
           #t))

  (define-test test-syntax-error-positional-name-clashes-with-an-option
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p [:short "-v" :arity 0] [:positional "v"])
                   p))
           #t)
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p [:long "--file"] [:positional "file"])
                   p))
           #t))

  (define-test test-syntax-error-positional-name-is-reserved
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p [:positional "help"])
                   p))
           #t))

  (define-test test-syntax-error-positional-without-a-name
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p [:positional])
                   p))
           #t)
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p [:positional 42])
                   p))
           #t))
  ;; ========================================
  ;; more positional cases
  ;; ========================================

  (define-command-line-options parse-input
    [:long "--input" :required :description "input"]
    [:positional "file"])

  (define-test test-required-option-is-checked-before-the-positional
    (CHECK equal? (error-message (lambda () (parse-input '()))) "missing required option")
    (CHECK equal? (error-message (lambda () (parse-input '("--input" "a")))) "too few positional arguments")
    (CHECK equal? ((parse-input '("f" "--input" "a")) "file") "f"))

  (define-test test-help-needs-neither-the-required-option-nor-the-positional
    (CHECK eq? (string? (help-text parse-input)) #t))

  (define-command-line-options parse-upper
    [:positional "word" :arity (1 +) :type (lambda (s) (string-upcase s))])

  (define-test test-positional-with-a-custom-type
    (CHECK equal? ((parse-upper '("a" "b")) "word") '("A" "B")))

  (define-command-line-options parse-list-and-file
    [:short "-e" :arity (1 +) :description "words"]
    [:positional "file"])

  (define-test test-an-unlimited-option-takes-the-words-after-it
    (let ([option (parse-list-and-file '("f" "-e" "a" "b"))])
      (CHECK equal? (option "e") '("a" "b"))
      (CHECK equal? (option "file") "f"))
    (CHECK equal? (error-message (lambda () (parse-list-and-file '("-e" "a" "b"))))
           "too few positional arguments"))

  (define-test test-double-dash-ends-an-unlimited-option-before-the-positional
    (let ([option (parse-list-and-file '("-e" "a" "--" "f"))])
      (CHECK equal? (option "e") '("a"))
      (CHECK equal? (option "file") "f")))

  (define-command-line-options parse-count-and-file
    [:short "-n" :long "--count" :type int]
    [:positional "file"])

  (define-test test-positional-and-the-equals-form-of-an-option
    (let ([option (parse-mode '("fast" "-v"))])
      (CHECK equal? (option "mode") "fast"))
    (let ([option (parse-count-and-file '("f" "--count=3"))])
      (CHECK eqv? (option "count") 3)
      (CHECK equal? (option "file") "f")))

  (define-test test-positional-name-is-unknown-without-a-clause
    (CHECK equal? (error-message (lambda () ((parse-none '()) "file"))) "unknown option"))

  (define-test test-lookup-names-are-case-sensitive
    (CHECK equal? (error-message (lambda () ((parse-names '()) "V"))) "unknown option")
    (CHECK equal? (error-message (lambda () ((parse-names '()) "Emit"))) "unknown option"))

  (define-test test-lookup-by-short-and-long-name-of-the-same-option
    (let ([option (parse-names '("--emit" "mlir"))])
      (CHECK equal? (option "emit") "mlir")
      (CHECK equal? (option 'emit) "mlir")))

  (define-command-line-options parse-two-or-three [:positional "w" :arity (2 3)])

  (define-test test-positional-too-few-and-too-many
    (CHECK equal? (error-message (lambda () (parse-two-or-three '("a")))) "too few positional arguments")
    (CHECK equal? (error-irritants (lambda () (parse-two-or-three '("a")))) '("w"))
    (CHECK equal? ((parse-two-or-three '("a" "b")) "w") '("a" "b"))
    (CHECK equal? ((parse-two-or-three '("a" "b" "c")) "w") '("a" "b" "c"))
    (CHECK equal? (error-irritants (lambda () (parse-two-or-three '("a" "b" "c" "d" "e"))))
           '("d" "e")))

  ;; ========================================
  ;; the usage of a positional
  ;; ========================================

  (define-test test-usage-of-a-positional-without-a-description
    (CHECK equal? (help-text parse-one)
           (string-append "Usage: " prog " [options] [--] <file>\n"
                          "\n"
                          "Arguments:\n"
                          "  <file>\n"
                          "\n"
                          "Options:\n"
                          "  -h, --help  show this help message and exit\n")))

  (define-command-line-options positional-multi-line
    [:positional "f" :arity (0 +) :description "first\nsecond"])

  (define-test test-usage-of-a-positional-with-a-multi-line-description
    (CHECK equal? (help-text positional-multi-line)
           (string-append "Usage: " prog " [options] [--] [<f>...]\n"
                          "\n"
                          "Arguments:\n"
                          "  [<f>...]  first\n"
                          "            second\n"
                          "\n"
                          "Options:\n"
                          "  -h, --help  show this help message and exit\n")))

  (define-test test-usage-without-a-positional-has-no-arguments-section
    (CHECK eq? (contains? (help-text parse-none) "Arguments:") #f)
    (CHECK eq? (contains? (help-text parse-none) "[--]") #f))
  ;; ========================================
  ;; more definition errors of :positional
  ;; ========================================

  ;; every definition in `bodies` is a syntax error; the bodies are the clauses after the parser name
  (define (all-syntax-errors? . bodies)
    (for-all (lambda (body)
               (syntax-error? `(let () (define-command-line-options p ,@body) p)))
             bodies))

  (define-test test-syntax-error-two-positionals-that-take-a-variable-number-of-words
    (CHECK eq? (all-syntax-errors?
                '([:positional "a" :arity (1 +)] [:positional "b" :arity (1 +)])
                '([:positional "a" :arity (0 1)] [:positional "b" :arity (0 1)])
                '([:positional "a" :arity (1 +)] [:positional "b" :arity (1 2)])
                '([:positional "a" :arity (0 +)] [:positional "b" :arity (2 +)])
                '([:positional "a" :arity (1 2)] [:positional "b"] [:positional "c" :arity (3 4)])
                '([:positional "a" :arity (0 1)] [:short "-v" :arity 0] [:positional "b" :arity (0 +)]))
           #t))

  (define-test test-syntax-error-two-positionals-with-the-same-name
    (CHECK eq? (all-syntax-errors?
                '([:positional "a"] [:positional "a"])
                '([:positional "a" :arity 2] [:positional "b"] [:positional "a" :arity (0 +)]))
           #t))

  (define-test test-several-positionals-with-at-most-one-variable-arity-are-fine
    (CHECK eq? (any-syntax-error?
                '([:positional "a"] [:positional "b"])
                '([:positional "source" :arity (1 +)] [:positional "dest"])
                '([:positional "cmd"] [:positional "args" :arity (0 +)])
                '([:positional "first"] [:positional "middle" :arity (0 3)] [:positional "last" :arity 2])
                '([:positional "a" :arity 2] [:positional "b" :arity 3] [:positional "c" :arity (1 +)]))
           #f))

  (define-test test-syntax-error-positional-arity
    (CHECK eq? (all-syntax-errors?
                '([:positional "a" :arity (3 2)])
                '([:positional "a" :arity -1])
                '([:positional "a" :arity (1 2 3)])
                '([:positional "a" :arity many])
                '([:positional "a" :arity (0 0)])
                '([:positional "a" :arity])
                '([:positional "a" :arity 1 :arity 2]))
           #t))

  (define-test test-syntax-error-positional-name
    (CHECK eq? (all-syntax-errors?
                '([:positional ""])
                '([:positional "a b"])
                '([:positional "a=b"])
                '([:positional "a,b"])
                '([:positional "--a"])
                '([:positional 42])
                '([:positional]))
           #t))

  (define-test test-syntax-error-positional-converter
    (CHECK eq? (all-syntax-errors?
                '([:positional "a" :choices ()])
                '([:positional "a" :choices ("x" "x")])
                '([:positional "a" :choices "x"])
                '([:positional "a" :type int :choices ("x")])
                '([:positional "a" :choices ("x") :type int]))
           #t))

  (define-test test-syntax-error-positional-other-fields
    (CHECK eq? (all-syntax-errors?
                '([:positional "a" :description 42])
                '([:positional "a" :description "x" :description "y"])
                '([:positional "a" :colour red])
                '([:positional "a" :description]))
           #t))

  (define-test test-syntax-error-positional-clashes-with-either-name-of-an-option
    (CHECK eq? (all-syntax-errors?
                '([:short "-emit" :long "--emit"] [:positional "emit"])
                '([:positional "emit"] [:short "-emit" :long "--emit"])
                '([:long "--file"] [:positional "file"])
                '([:positional "h"])
                '([:positional "help"]))
           #t))

  (define-test test-a-positional-next-to-options-is-fine
    (CHECK eq? (any-syntax-error?
                '([:short "-v" :arity 0] [:positional "file" :arity (1 +)])
                '([:positional "file" :arity (0 1)] [:short "-v" :arity 0])
                '([:positional "emit"] [:short "-e" :long "--exit"]))
           #f))

  (define (any-syntax-error? . bodies)
    (exists (lambda (body)
              (syntax-error? `(let () (define-command-line-options p ,@body) p)))
            bodies))
  ;; ========================================
  ;; several positionals
  ;; ========================================

  (define-command-line-options parse-cp
    [:short "-v" :arity 0 :description "verbose"]
    [:positional "source" :arity (1 +) :description "files to copy"]
    [:positional "dest" :description "where to copy them"])

  (define-command-line-options parse-cmd
    [:positional "cmd"]
    [:positional "args" :arity (0 +)])

  (define-command-line-options parse-sandwich
    [:positional "first"]
    [:positional "middle" :arity (0 +)]
    [:positional "last"])

  (define-command-line-options parse-bounded
    [:positional "x" :arity 2]
    [:positional "y" :arity (0 2)])

  (define-command-line-options parse-typed
    [:positional "count" :type int]
    [:positional "mode" :choices ("fast" "slow")]
    [:positional "rest" :arity (0 +)])

  ;; the values of the positionals, in the order of their names
  (define (values-of option . names)
    (map (lambda (name) (option name)) names))

  (define-test test-the-variable-positional-takes-what-the-exact-ones-leave
    (CHECK equal? (values-of (parse-cp '("a" "b" "c")) "source" "dest") '(("a" "b") "c"))
    (CHECK equal? (values-of (parse-cp '("a" "b")) "source" "dest") '(("a") "b"))
    (CHECK equal? (values-of (parse-cp '("a" "b" "c" "d" "e")) "source" "dest")
           '(("a" "b" "c" "d") "e")))

  (define-test test-an-exact-positional-before-the-variable-one
    (CHECK equal? (values-of (parse-cmd '("run" "x" "y")) "cmd" "args") '("run" ("x" "y")))
    (CHECK equal? (values-of (parse-cmd '("run")) "cmd" "args") '("run" ())))

  (define-test test-the-variable-positional-between-two-exact-ones
    (CHECK equal? (values-of (parse-sandwich '("a" "z")) "first" "middle" "last") '("a" () "z"))
    (CHECK equal? (values-of (parse-sandwich '("a" "m" "z")) "first" "middle" "last") '("a" ("m") "z"))
    (CHECK equal? (values-of (parse-sandwich '("a" "m" "n" "o" "z")) "first" "middle" "last")
           '("a" ("m" "n" "o") "z")))

  (define-test test-an-exact-positional-with-arity-above-one-is-a-list
    (CHECK equal? (values-of (parse-bounded '("a" "b")) "x" "y") '(("a" "b") ()))
    (CHECK equal? (values-of (parse-bounded '("a" "b" "c")) "x" "y") '(("a" "b") ("c")))
    (CHECK equal? (values-of (parse-bounded '("a" "b" "c" "d")) "x" "y") '(("a" "b") ("c" "d"))))

  (define-test test-too-few-names-the-first-positional-that-lacks-words
    (CHECK equal? (error-message (lambda () (parse-cp '()))) "too few positional arguments")
    (CHECK equal? (error-irritants (lambda () (parse-cp '()))) '("source"))
    (CHECK equal? (error-irritants (lambda () (parse-cp '("a")))) '("dest"))
    (CHECK equal? (error-irritants (lambda () (parse-sandwich '("a")))) '("last"))
    (CHECK equal? (error-irritants (lambda () (parse-bounded '("a")))) '("x")))

  (define-command-line-options parse-two-exact [:positional "p"] [:positional "q"])

  (define-test test-too-many-gives-the-words-that-no-positional-takes
    (CHECK equal? (error-message (lambda () (parse-bounded '("a" "b" "c" "d" "e"))))
           "too many positional arguments")
    (CHECK equal? (error-irritants (lambda () (parse-bounded '("a" "b" "c" "d" "e" "f"))))
           '("e" "f"))
    (CHECK equal? (error-message (lambda () (parse-two-exact '("a" "b" "c"))))
           "too many positional arguments"))

  (define-test test-the-variable-positional-has-no-upper-limit
    (CHECK equal? (length ((parse-cp (map number->string (iota* 100))) "source")) 99))

  (define-test test-every-positional-is-converted-by-its-own-type
    (let ([option (parse-typed '("3" "fast" "x" "y"))])
      (CHECK equal? (values-of option "count" "mode" "rest") '(3 "fast" ("x" "y"))))
    (CHECK equal? (error-irritants (lambda () (parse-typed '("three" "fast")))) '("count" "three"))
    (CHECK equal? (error-irritants (lambda () (parse-typed '("3" "medium"))))
           '("mode" "medium" ("fast" "slow"))))

  (define-test test-several-positionals-and-options-in-any-order
    (let ([option (parse-cp '("a" "-v" "b" "c"))])
      (CHECK eq? (option "v") #t)
      (CHECK equal? (values-of option "source" "dest") '(("a" "b") "c")))
    (let ([option (parse-cp '("-v" "a" "--" "-b"))])
      (CHECK equal? (values-of option "source" "dest") '(("a") "-b"))))

  (define-test test-several-positionals-the-escape-and-the-double-dash
    (CHECK equal? (values-of (parse-cmd '("\\-run" "--" "-x" "\\-y")) "cmd" "args")
           '("-run" ("-x" "\\-y"))))

  (define-test test-an-unknown-positional-name-is-unknown-with-several
    (CHECK equal? (error-message (lambda () ((parse-cp '("a" "b")) "other"))) "unknown option"))

  (define-test test-the-names-in-the-unknown-name-error-include-the-positionals
    (CHECK equal? (error-irritants (lambda () ((parse-cp '("a" "b")) "other")))
           '("other" ("v" "source" "dest")))
    (CHECK equal? (error-irritants (lambda () ((parse-none '()) "file")))
           '("file" ("v"))))

  (define-test test-help-needs-no-positional-words-with-several
    (CHECK eq? (string? (help-text parse-cp)) #t))

  (define-test test-usage-lists-every-positional
    (CHECK equal? ((parse-cp '("a" "b")) 'usage)
           (string-append "Usage: " prog " [options] [--] <source>... <dest>\n"
                          "\n"
                          "Arguments:\n"
                          "  <source>...  files to copy\n"
                          "  <dest>       where to copy them\n"
                          "\n"
                          "Options:\n"
                          "  -v          verbose\n"
                          "  -h, --help  show this help message and exit\n")))

  (define-test test-usage-of-exact-and-optional-positionals
    (CHECK equal? ((parse-sandwich '("a" "z")) 'usage)
           (string-append "Usage: " prog " [options] [--] <first> [<middle>...] <last>\n"
                          "\n"
                          "Arguments:\n"
                          "  <first>\n"
                          "  [<middle>...]\n"
                          "  <last>\n"
                          "\n"
                          "Options:\n"
                          "  -h, --help  show this help message and exit\n")))

  (define-test test-usage-of-a-positional-with-an-exact-arity-above-one
    (CHECK equal? ((parse-bounded '("a" "b")) 'usage)
           (string-append "Usage: " prog " [options] [--] <x> <x> [<y>] [<y>]\n"
                          "\n"
                          "Arguments:\n"
                          "  <x> <x>\n"
                          "  [<y>] [<y>]\n"
                          "\n"
                          "Options:\n"
                          "  -h, --help  show this help message and exit\n")))

  ;; ========================================
  ;; the recipes of the doc: what a program does with what the library gives
  ;; ========================================

  ;; help: the program's own text around the usage
  (define-command-line-options recipe-copy
    [:short "-v" :long "--verbose" :arity 0 :description "print each file"]
    [:positional "source" :arity (1 +) :description "files to copy"]
    [:positional "dest" :description "where to copy them"])

  (define (recipe-help-text usage)
    (string-append "Copy files to a directory.\n\n" usage "\nExample: cp-lite a.txt b.txt dest/\n"))

  (define-test test-recipe-help-puts-text-around-the-usage
    (let* ([option (recipe-copy '("-h"))]
           [shown (and (option "help") (recipe-help-text (option "usage")))])
      (CHECK eq? (and (starts-with? shown "Copy files to a directory.\n\nUsage: ") #t) #t)
      (CHECK eq? (contains? shown "  -v, --verbose  print each file\n") #t)
      (CHECK eq? (contains? shown "\nExample: cp-lite a.txt b.txt dest/\n") #t)))

  ;; --version: the raw arguments are checked before the parse, up to a --
  (define (recipe-asks-for-version? arguments)
    (and (pair? arguments)
         (not (string=? (car arguments) "--"))
         (or (string=? (car arguments) "--version")
             (recipe-asks-for-version? (cdr arguments)))))

  (define-command-line-options recipe-needs-input
    [:short "-i" :long "--input" :required :description "file to read"])

  (define-test test-recipe-version-is-found-in-the-raw-arguments
    (CHECK eq? (recipe-asks-for-version? '("--version")) #t)
    (CHECK eq? (recipe-asks-for-version? '("-i" "a.txt" "--version")) #t)
    (CHECK eq? (recipe-asks-for-version? '("-i" "a.txt")) #f)
    (CHECK eq? (recipe-asks-for-version? '("--" "--version")) #f)
    (CHECK eq? (recipe-asks-for-version? '()) #f))

  (define-test test-recipe-the-parser-alone-cannot-answer-version-without-the-required-option
    ;; this is why the check is made before the parse: the parser stops on the missing option
    (CHECK eq? (command-line-error? (raised (lambda () (recipe-needs-input '("--version"))))) #t))

  ;; a default from the environment, with the call-site default of the accessor
  (define-command-line-options recipe-output
    [:short "-o" :long "--output" :description "output file"])

  (define (recipe-output-file option lookup)
    (option "output" (or (lookup "CP_OUTPUT") "a.out")))

  (define-test test-recipe-environment-gives-the-default
    (let ([environment (lambda (name) (and (string=? name "CP_OUTPUT") "env.out"))]
          [empty (lambda (name) #f)])
      (CHECK equal? (recipe-output-file (recipe-output '()) empty) "a.out")
      (CHECK equal? (recipe-output-file (recipe-output '()) environment) "env.out")
      (CHECK equal? (recipe-output-file (recipe-output '("-o" "cli.out")) environment) "cli.out")))

  ;; options that exclude each other, checked after the parse
  (define-command-line-options recipe-format
    [:long "--json" :arity 0 :description "write json"]
    [:long "--text" :arity 0 :description "write text"])

  (define (recipe-exclusive-conflict? option)
    (and (option "json") (option "text")))

  (define-test test-recipe-exclusive-options
    (CHECK eq? (recipe-exclusive-conflict? (recipe-format '())) #f)
    (CHECK eq? (recipe-exclusive-conflict? (recipe-format '("--json"))) #f)
    (CHECK eq? (recipe-exclusive-conflict? (recipe-format '("--text"))) #f)
    (CHECK eq? (recipe-exclusive-conflict? (recipe-format '("--json" "--text"))) #t))

  ;; subcommands: dispatch on the first word, one parser per command
  (define-command-line-options recipe-copy-command
    [:short "-v" :arity 0 :description "print each file"]
    [:positional "source" :arity (1 +)]
    [:positional "dest"])

  (define-command-line-options recipe-remove-command
    [:long "--force" :arity 0 :description "do not ask"]
    [:positional "file" :arity (1 +)])

  (define (recipe-run arguments)
    (cond
     [(null? arguments) '(usage)]
     [(string=? (car arguments) "copy")
      (let ([option (recipe-copy-command (cdr arguments))])
        (list 'copy (option "source") (option "dest")))]
     [(string=? (car arguments) "remove")
      (let ([option (recipe-remove-command (cdr arguments))])
        (list 'remove (option "force") (option "file")))]
     [else (list 'unknown-command (car arguments))]))

  (define-test test-recipe-subcommands
    (CHECK equal? (recipe-run '()) '(usage))
    (CHECK equal? (recipe-run '("copy" "a" "b" "dest/")) '(copy ("a" "b") "dest/"))
    (CHECK equal? (recipe-run '("remove" "--force" "x" "y")) '(remove #t ("x" "y")))
    (CHECK equal? (recipe-run '("remove" "x")) '(remove #f ("x")))
    (CHECK equal? (recipe-run '("frobnicate")) '(unknown-command "frobnicate"))
    ;; each command checks its own arguments
    (CHECK equal? (error-message (lambda () (recipe-run '("remove")))) "too few positional arguments")
    (CHECK equal? (error-message (lambda () (recipe-run '("copy" "a")))) "too few positional arguments"))

  ;; a verbosity level: -v 3, and 0 when it is not given
  (define-command-line-options recipe-verbose
    [:short "-v" :long "--verbose" :type int :metavar "level" :description "how much to print, 0 to 3"])

  (define-test test-recipe-verbosity-level
    (CHECK eqv? ((recipe-verbose '()) "verbose" 0) 0)
    (CHECK eqv? ((recipe-verbose '("-v" "3")) "verbose" 0) 3)
    (CHECK eqv? ((recipe-verbose '("--verbose=2")) "verbose" 0) 2)
    (CHECK equal? (error-message (lambda () (recipe-verbose '("-v")))) "too few arguments for option")
    (CHECK eq? (contains? ((recipe-verbose '()) "usage") "-v, --verbose <level>") #t))

  ;; the compact short forms are ordinary words: write -j 4 and -v -q
  (define-command-line-options recipe-short-forms
    [:short "-j" :long "--jobs" :type int :description "number of jobs"]
    [:short "-v" :arity 0 :description "verbose"]
    [:short "-q" :arity 0 :description "quiet"]
    [:positional "file" :arity (0 +)])

  (define-test test-recipe-short-forms-are-written-separately
    (let ([separate (recipe-short-forms '("-j" "4" "-v" "-q" "a.txt"))]
          [compact (recipe-short-forms '("-j4" "-vq" "a.txt"))])
      (CHECK eqv? (separate "jobs") 4)
      (CHECK eq? (separate "v") #t)
      (CHECK eq? (separate "q") #t)
      (CHECK equal? (separate "file") '("a.txt"))
      ;; the compact forms are not read: they are words, and the flags are not set
      (CHECK eq? (compact "jobs") #f)
      (CHECK eq? (compact "v") #f)
      (CHECK equal? (compact "file") '("-j4" "-vq" "a.txt"))))

  ;; catching a wrong name early: the program reads every name it uses once, right after the parse
  (define-command-line-options recipe-names
    [:short "-i" :long "--input" :description "file to read"]
    [:short "-c" :long "--count" :type int :description "repeat count"])

  (define (recipe-read-every-name option names)
    (for-each (lambda (name) (option name)) names))

  (define-test test-recipe-a-wrong-name-fails-at-once-with-the-names-that-exist
    (let ([option (recipe-names '("-i" "a.txt"))])
      (recipe-read-every-name option '("input" "count"))
      (CHECK equal? (error-message (lambda () (recipe-read-every-name option '("input" "cuont"))))
             "unknown option")
      (CHECK equal? (error-irritants (lambda () (recipe-read-every-name option '("input" "cuont"))))
             '("cuont" ("i" "input" "c" "count")))))

  ;; ========================================
  ;; definition errors: which rule is broken, and where
  ;; ========================================
  ;; These tests carry what the unit tests of the AST and of the parser used to carry. A definition
  ;; is expanded for real, and the message of the syntax violation tells which rule was broken.

  (define definition-environment (environment '(rnrs (6)) '(rime command-line-options)))

  ;; (definition-error clause ...) => the message of the syntax violation of the definition,
  ;; #f when the definition is fine, and the symbol other-error for anything else
  (define (definition-error . clauses)
    (guard (e [(syntax-violation? e) (condition-message e)]
              [else 'other-error])
      (eval `(let () (define-command-line-options p ,@clauses) p) definition-environment)
      #f))

  ;; (definition-error-form clause ...) => the part of the definition the violation points at, as a datum
  (define (definition-error-form . clauses)
    (guard (e [(syntax-violation? e) (syntax->datum (syntax-violation-form e))]
              [else 'other-error])
      (eval `(let () (define-command-line-options p ,@clauses) p) definition-environment)
      #f))

  (define (starts-with? text prefix)
    (and (>= (string-length text) (string-length prefix))
         (string=? (substring text 0 (string-length prefix)) prefix)))

  ;; the message has to begin with `expected` (the text after it may list the fields that exist);
  ;; #f as `expected` means that the definition has to be fine
  (define (message-matches? expected actual)
    (if expected
        (and (string? actual) (starts-with? actual expected))
        (not actual)))

  ;; rows are (expected-message clause ...); a mismatch shows the clauses and the message that came
  (define (check-definition-rows rows)
    (for-each
     (lambda (row)
       (let* ([expected (car row)]
              [clauses (cdr row)]
              [actual (apply definition-error clauses)])
         (CHECK equal?
                (list clauses (if (message-matches? expected actual) expected actual))
                (list clauses expected))))
     rows))

  (define-test test-definition-errors-of-the-names
    (check-definition-rows
     '(("an option needs a :short or a :long name" [])
       ("an option needs a :short or a :long name" [:description "x"])
       ("an option needs a :short or a :long name" [:arity 2])
       (":short name must look like" [:short "x"])
       (":short name must look like" [:short "--abc"])
       (":short name must look like" [:short "-"])
       (":short name must look like" [:short "-a b"])
       (":short name must look like" [:short "-a=b"])
       (":short name must look like" [:short "-a,b"])
       (":long name must look like" [:long "x"])
       (":long name must look like" [:long "-x"])
       (":long name must look like" [:long "--"])
       (":long name must look like" [:long "---x"])
       (":long name must look like" [:long "--a b"])
       (":long name must look like" [:long "--a=b"])
       (":short name must be a string or a symbol" [:short 42])
       (":long name must be a string or a symbol" [:long 42])
       (#f [:short "-a"])
       (#f [:long "--abc"])
       (#f [:short "-emit" :long "--emit"])
       (#f [:short "-ab"])
       (#f [:long "--a-b"]))))

  (define-test test-definition-errors-of-the-names-that-are-taken
    (check-definition-rows
     '(("option name is defined twice" [:short "-a"] [:short "-a"])
       ("option name is defined twice" [:long "--x"] [:long "--x"])
       ("option name is defined twice" [:short "-a" :long "--x"] [:short "-b" :long "--x"])
       ("option name is defined twice" [:short "-x"] [:long "--x"])
       ("option name is defined twice" [:long "--x"] [:short "-x"])
       ("-h, --help and the name usage are reserved for the built-in help" [:short "-h"])
       ("-h, --help and the name usage are reserved for the built-in help" [:long "--help"])
       ("-h, --help and the name usage are reserved for the built-in help" [:short "-a" :long "--help"])
       ("-h, --help and the name usage are reserved for the built-in help" [:long "--h"])
       ("-h, --help and the name usage are reserved for the built-in help" [:long "--usage"])
       ("-h, --help and the name usage are reserved for the built-in help" [:short "-usage"])
       (#f [:short "-a"] [:short "-b"] [:long "--c"])
       (#f [:short "-emit" :long "--emit"] [:short "-opt" :long "--opt"]))))

  (define-test test-definition-errors-of-the-arity
    (check-definition-rows
     '(("arity min must not exceed max" [:short "-a" :arity (3 2)])
       ("arity must be n, (min max) or (min +)" [:short "-a" :arity -1])
       ("arity must be n, (min max) or (min +)" [:short "-a" :arity (1 2 3)])
       ("arity must be n, (min max) or (min +)" [:short "-a" :arity many])
       ("arity must be n, (min max) or (min +)" [:short "-a" :arity 1.5])
       ("arity must be n, (min max) or (min +)" [:short "-a" :arity (1 x)])
       ("arity must be n, (min max) or (min +)" [:short "-a" :arity (-1 +)])
       (#f [:short "-a" :arity 0])
       (#f [:short "-a" :arity 3])
       (#f [:short "-a" :arity (2 2)])
       (#f [:short "-a" :arity (0 5)])
       (#f [:short "-a" :arity (0 +)])
       (#f [:short "-a" :arity (3 +)]))))

  (define-test test-definition-errors-of-the-types
    (check-definition-rows
     '((":type and :choices must not be given when arity is 0" [:short "-a" :arity 0 :type int])
       (":type and :choices must not be given when arity is 0" [:short "-a" :arity (0 0) :type int])
       (":type and :choices must not be given when arity is 0" [:short "-a" :arity 0 :choices ("x")])
       ("the converter is given twice" [:short "-a" :type int :choices ("x")])
       ("the converter is given twice" [:short "-a" :choices ("x") :type int])
       ("the converter is given twice" [:short "-a" :type int :type float])
       (":choices needs at least one choice" [:short "-a" :choices ()])
       (":choices must be a list of strings or integers" [:short "-a" :choices "x"])
       (":choices must be a list of strings or integers" [:short "-a" :choices x])
       ("a choice must be a string or an integer" [:short "-a" :choices (x)])
       ("a choice must be a string or an integer" [:short "-a" :choices (1.5)])
       ("a choice must be a string or an integer" [:short "-a" :choices (1.0)])
       ("a choice must be a string or an integer" [:short "-a" :choices ("a" x)])
       (":choices must be all strings or all integers" [:short "-a" :choices (1 "2")])
       (":choices must be all strings or all integers" [:short "-a" :choices ("a" 1)])
       (":choices must be all strings or all integers" [:short "-a" :choices ("auto" 1 2)])
       (":choices must be all strings or all integers" [:short "-a" :choices (1 "1")])
       (":choices must be all strings or all integers" [:short "-a" :choices ("1" 1)])
       ("duplicate choice" [:short "-a" :choices ("x" "x")])
       ("duplicate choice" [:short "-a" :choices ("1" "1")])
       ("duplicate choice" [:short "-a" :choices (1 1)])
       (":description must be a string" [:short "-a" :description 42])
       (":description must be a string" [:short "-a" :description x])
       (#f [:short "-a" :type int])
       (#f [:short "-a" :type float])
       (#f [:short "-a" :type bool])
       (#f [:short "-a" :type string])
       (#f [:short "-a" :type string-upcase])
       (#f [:short "-a" :type (lambda (s) s)])
       (#f [:short "-a" :choices ("x" "y")])
       (#f [:short "-a" :choices (1 2)])
       (#f [:short "-a" :choices (1)])
       (#f [:short "-a" :choices ("x")])
       (#f [:short "-a" :arity (1 +) :choices ("x")])
       (#f [:short "-a" :description ""]))))

  (define-test test-definition-errors-of-required
    (check-definition-rows
     '(("a flag (arity 0) cannot be :required" [:short "-a" :arity 0 :required])
       ("a flag (arity 0) cannot be :required" [:short "-a" :arity (0 0) :required])
       ("duplicate field" [:short "-a" :required :required])
       ("unknown field, or field without a value" [:short "-a" :required #t])
       (#f [:short "-a" :required])
       (#f [:required :long "--abc"])
       (#f [:short "-a" :arity (0 +) :required]))))

  (define-test test-definition-errors-of-the-metavar
    (check-definition-rows
     '((":metavar must be a string or a symbol" [:short "-a" :metavar 42])
       ("a flag (arity 0) cannot have a :metavar" [:short "-a" :arity 0 :metavar "x"])
       ("a flag (arity 0) cannot have a :metavar" [:short "-a" :arity (0 0) :metavar "x"])
       ("duplicate field" [:short "-a" :metavar "x" :metavar "y"])
       ("unknown field, or field without a value" [:short "-a" :metavar])
       ("unknown field, or field without a value" [:positional "a" :metavar "x"])
       (#f [:short "-a" :metavar "file"])
       (#f [:short "-a" :metavar file])
       (#f [:metavar "n" :short "-a" :arity (1 +)])
       (#f [:short "-a" :metavar "n" :choices ("x" "y")])
       (#f [:short "-a" :metavar "n" :type int :arity 2])
       (#f [:short "-a" :metavar "-x"]))))

  (define-test test-definition-errors-of-the-clause-grammar
    (check-definition-rows
     '(("an option clause is a list of :key value pairs" "-a")
       ("an option clause is a list of :key value pairs" 42)
       ("an option clause is a list of :key value pairs" [:short "-a" . 5])
       ("unknown field, or field without a value" [:short "-a" :long . 5])
       ("unknown field, or field without a value" [:short "-a" 42])
       ("unknown field, or field without a value" [:short "-a" "--long" "--x"])
       ("unknown field, or field without a value" [:short "-a" :colour red])
       ("unknown field, or field without a value" [:short "-a" :long])
       ("unknown field, or field without a value" ["-n" :long "--count"])
       (":long name must look like" [:short "-a" :long :arity :arity 1])
       ("duplicate field" [:short "-a" :short "-b"])
       ("duplicate field" [:long "--aa" :long "--bb"])
       ("duplicate field" [:short "-a" :arity 1 :arity 2])
       ("duplicate field" [:arity 1 :short "-a" :arity 1])
       ("duplicate field" [:short "-a" :description "x" :description "y"])
       ("duplicate field" [:short "-a" :description "x" :long "--bb" :description "y"]))))

  (define-test test-definition-errors-of-the-whole-definition
    (CHECK equal? (definition-error) #f)
    (CHECK eq? (guard (e [(syntax-violation? e) #t] [else #f])
                 (eval '(define-command-line-options "p" [:short "-a"]) definition-environment)
                 #f)
           #t)
    (CHECK eq? (guard (e [(syntax-violation? e) #t] [else #f])
                 (eval '(define-command-line-options) definition-environment)
                 #f)
           #t))

  (define-test test-definition-errors-of-the-positionals
    (check-definition-rows
     '(("a positional name must not start with -" [:positional "-a"])
       ("a positional name must not start with -" [:positional "--a"])
       ("a positional name must not be empty or contain" [:positional ""])
       ("a positional name must not be empty or contain" [:positional "a b"])
       ("a positional name must not be empty or contain" [:positional "a=b"])
       ("a positional name must not be empty or contain" [:positional "a,b"])
       (":positional name must be a string or a symbol" [:positional 42])
       ("unknown field, or field without a value" [:positional])
       ("a clause is a list of :key value pairs" [:positional "a" . 5])
       ("a positional argument must take at least one word" [:positional "a" :arity 0])
       ("a positional argument must take at least one word" [:positional "a" :arity (0 0)])
       ("arity min must not exceed max" [:positional "a" :arity (3 2)])
       ("arity must be n, (min max) or (min +)" [:positional "a" :arity many])
       ("duplicate field" [:positional "a" :positional "b"])
       ("duplicate field" [:positional "a" :arity 1 :arity 2])
       ("duplicate field" [:positional "a" :description "x" :description "y"])
       ("the converter is given twice" [:positional "a" :type int :choices ("x")])
       (":choices needs at least one choice" [:positional "a" :choices ()])
       ("duplicate choice" [:positional "a" :choices ("x" "x")])
       (":description must be a string" [:positional "a" :description 42])
       ("unknown field, or field without a value" [:positional "a" :colour red])
       ("unknown field, or field without a value" [:positional "a" :arity])
       (":short is a field of an option, not of a :positional clause" [:positional "a" :short "-a"])
       (":long is a field of an option, not of a :positional clause" [:positional "a" :long "--aa"])
       (":required is a field of an option, not of a :positional clause" [:positional "a" :required])
       ("-h, --help and the name usage are reserved for the built-in help" [:positional "h"])
       ("-h, --help and the name usage are reserved for the built-in help" [:positional "help"])
       ("-h, --help and the name usage are reserved for the built-in help" [:positional "usage"])
       ("positional name clashes with an option name" [:short "-v" :arity 0] [:positional "v"])
       ("positional name clashes with an option name" [:long "--file"] [:positional "file"])
       ("positional name clashes with an option name" [:positional "emit"] [:short "-emit" :long "--emit"])
       ("positional name is defined twice" [:positional "a"] [:positional "a"])
       ("positional name is defined twice" [:positional "a" :arity 2] [:positional "b"] [:positional "a" :arity (0 +)])
       ("only one positional argument can take a variable number of words" [:positional "a" :arity (1 +)] [:positional "b" :arity (1 +)])
       ("only one positional argument can take a variable number of words" [:positional "a" :arity (0 1)] [:positional "b" :arity (0 1)])
       ("only one positional argument can take a variable number of words" [:positional "a" :arity (1 +)] [:positional "b" :arity (1 2)])
       ("only one positional argument can take a variable number of words" [:positional "a" :arity (1 2)] [:positional "b"] [:positional "c" :arity (3 4)])
       (#f [:positional "a"])
       (#f [:positional "file" :arity (1 +) :type int :description "files"])
       (#f [:arity 2 :description "d" :positional "p" :choices ("a" "b")])
       (#f [:positional "a"] [:positional "b" :arity 2])
       (#f [:positional "source" :arity (1 +)] [:positional "dest"])
       (#f [:positional "first"] [:positional "middle" :arity (0 3)] [:positional "last" :arity 2])
       (#f [:short "-v" :arity 0] [:positional "file" :arity (0 +)] [:long "--out"])
       (#f [:positional "emit"] [:short "-e" :long "--exit"]))))

  (define-test test-a-definition-error-points-at-the-offending-part
    ;; the clause for a rule of the whole clause, the value or the field for a mistake in it
    (CHECK equal? (definition-error-form '[:short "-a" :arity (3 2)]) '(:short "-a" :arity (3 2)))
    (CHECK equal? (definition-error-form '[:short "-a" 42]) 42)
    (CHECK equal? (definition-error-form '[:short "-a" :description 42]) 42)
    (CHECK equal? (definition-error-form '[:short "-a"] '[:short "-a"]) '(:short "-a"))
    (CHECK equal? (definition-error-form '[:short "-a"] '[:long "--b"]) #f))

  ;; ========================================
  ;; the converters of a definition
  ;; ========================================

  (define-command-line-options parse-identifier
    [:short "-a" :type string-upcase])

  (define-test test-a-custom-type-may-be-a-bare-procedure-name
    (CHECK equal? ((parse-identifier '("-a" "abc")) "a") "ABC"))

  (define-test test-a-type-named-like-a-builtin-is-the-builtin
    (let ([parse-int (eval '(let ()
                              (define-command-line-options p [:short "-a" :type int])
                              p)
                           definition-environment)])
      (CHECK eqv? ((parse-int '("-a" "12")) "a") 12)))
  )
