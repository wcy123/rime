#!r6rs
(library (test rime command-line-options-test)
  (export main)
  (import (rnrs (6))
          (rnrs eval (6))
          (rime unit-test)
          (rime command-line-options)
          (rime command-line-options __ast)
          (rime command-line-options __runtime))

  (define (main)
    (run-all-tests))

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
    (CHECK equal? (error-message (lambda () (parse '("--pair=")))) "too few arguments for option")
    (CHECK equal? (error-message (lambda () (parse '("--count=")))) "invalid argument value"))

  (define-test test-form-mixed
    (let ([option (parse '("-v" "--count=2" "-f" "a" "b" "-s" "n" "--ratio" "0.5"))])
      (CHECK eq? (option "v") #t)
      (CHECK eqv? (option "n") 2)
      (CHECK equal? (option "f") '("a" "b"))
      (CHECK equal? (option "s") "n")
      (CHECK eqv? (option "x") 0.5)))

  ;; ========================================
  ;; repeated option
  ;; ========================================

  (define-test test-repeated-option-last-wins
    (let ([option (parse '("-n" "1" "-n" "2"))])
      (CHECK eqv? (option "n") 2))
    (let ([option (parse '("-f" "a" "-f" "b" "c"))])
      (CHECK equal? (option "f") '("b" "c"))))

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

  ;; a word is an option only when it is the name of a defined option. An undefined word that starts
  ;; with a single dash is an ordinary word (a positional word, or an argument of the option before
  ;; it); an undefined word that starts with -- is a mistyped option, see below
  (define-test test-an-undefined-dash-word-is-a-positional-word
    (CHECK equal? ((parse '("-z")) "args") '("-z"))
    (CHECK equal? ((parse '("-z=1")) "args") '("-z=1"))
    (CHECK equal? ((parse '("-vq")) "args") '("-vq"))
    (CHECK equal? ((parse '("-j4")) "args") '("-j4"))
    (CHECK equal? ((parse '("a" "-z" "b")) "args") '("a" "-z" "b")))

  (define-test test-an-undefined-dash-word-is-an-error-when-there-is-no-positional
    (CHECK equal? (error-message (lambda () (parse-none '("-z")))) "unexpected positional argument")
    (CHECK equal? (error-irritants (lambda () (parse-none '("-z=1")))) '("-z=1")))

  (define-test test-an-undefined-dash-word-is-an-argument-of-the-option-before-it
    (CHECK equal? ((parse '("-f" "a" "-z" "b")) "f") '("a" "-z" "b"))
    (CHECK equal? ((parse '("-s" "-z")) "s") "-z"))

  (define-test test-an-unknown-long-option-is-an-error
    (CHECK equal? (error-message (lambda () (parse '("--nope")))) "unknown option")
    (CHECK equal? (error-irritants (lambda () (parse '("--nope")))) '("--nope"))
    (CHECK equal? (error-irritants (lambda () (parse '("--nope=1")))) '("--nope=1"))
    (CHECK equal? (error-message (lambda () (parse '("a" "--nope" "b")))) "unknown option")
    (CHECK equal? (error-message (lambda () (parse '("---x")))) "unknown option")
    (CHECK equal? (error-message (lambda () (parse '("--5")))) "unknown option"))

  (define-test test-a-mistyped-long-option-is-not-a-file-name
    ;; the program has a variadic positional: "--verbos" used to become one of the files
    (CHECK equal? (error-irritants (lambda () (parse '("--verbos" "a.txt")))) '("--verbos"))
    (CHECK equal? (error-irritants (lambda () (parse '("--colour" "red" "a.txt")))) '("--colour")))

  (define-test test-an-unknown-long-option-is-a-command-line-error-with-the-usage
    (let ([e (raised (lambda () (parse '("--verbos" "a.txt"))))])
      (CHECK eq? (command-line-error? e) #t)
      (CHECK equal? (command-line-error-usage e) ((parse '()) "help"))))

  (define-test test-an-unknown-long-option-without-positional-words-is-unknown-not-unexpected
    (CHECK equal? (error-message (lambda () (parse-none '("--nope")))) "unknown option"))

  (define-test test-an-unknown-long-option-stops-the-arguments-of-an-option
    ;; -f takes one or more arguments; it stops at the mistyped option, as it stops at an option name
    (CHECK equal? (error-message (lambda () (parse '("-f" "a" "--nope" "b")))) "unknown option")
    (CHECK equal? (error-message (lambda () (parse '("-s" "--nope")))) "too few arguments for option"))

  (define-test test-a-value-that-starts-with-two-dashes
    ;; after =, after --, or with the escape
    (CHECK equal? ((parse '("-s=--nope")) "s") "--nope")
    (CHECK equal? ((parse '("--name=--nope")) "s") "--nope")
    (CHECK equal? ((parse '("-s" "\\--nope")) "s") "--nope")
    (CHECK equal? ((parse '("\\--nope")) "args") '("--nope"))
    (CHECK equal? ((parse '("--" "--nope")) "args") '("--nope"))
    (CHECK equal? ((parse '("-v" "--" "--nope" "--other")) "args") '("--nope" "--other")))

  (define-test test-defined-long-options-are-not-unknown
    (CHECK eqv? ((parse '("--count=3")) "n") 3)
    (CHECK eqv? ((parse '("--count" "3")) "n") 3)
    (CHECK eq? ((parse '("--verbose")) "v") #t))

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
     '("-5a" "-0x10" "-1/2" "-inf" "-e5" "-1e" "-1." "-." "-1.2.3" "-+5" "-5-" "-1e+" "-i")))

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
    ;; --pair needs two arguments, = gives one
    (CHECK equal? (error-message (lambda () (parse '("--pair=1,2,3"))))
           "too few arguments for option"))

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
    (let ([usage ((parse '()) "help")])
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
      (CHECK equal? (command-line-error-usage e) ((parse-required '("-i" "a")) "help"))))

  (define-test test-positional-errors-carry-the-usage
    (let ([few (raised (lambda () (parse-one '())))]
          [many (raised (lambda () (parse-one '("a" "b"))))]
          [none (raised (lambda () (parse-none '("a"))))])
      (CHECK equal? (condition-message few) "too few positional arguments")
      (CHECK equal? (command-line-error-usage few) ((parse-one '("a")) "help"))
      (CHECK equal? (condition-message many) "too many positional arguments")
      (CHECK equal? (command-line-error-usage many) ((parse-one '("a")) "help"))
      (CHECK equal? (condition-message none) "unexpected positional argument")
      (CHECK equal? (command-line-error-usage none) ((parse-none '()) "help"))))

  (define-test test-a-failing-custom-type-is-a-command-line-error-with-the-usage
    (let ([e (raised (lambda () (strict '("-k" "no"))))])
      (CHECK eq? (command-line-error? e) #t)
      (CHECK equal? (condition-message e) "invalid argument value")
      (CHECK equal? (command-line-error-usage e) ((strict '("-k" "ok")) "help"))))

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

  (define-test test-the-report-is-the-message-the-irritants-and-the-usage
    (let ([e (raised (lambda () (parse '("-n" "abc"))))])
      (CHECK equal? (format-command-line-error e)
             (string-append (program-name) ": invalid argument value: \"-n\" \"abc\"\n\n"
                            ((parse '()) "help"))))
    (let ([e (raised (lambda () (parse-required '())))])
      (CHECK equal? (format-command-line-error e)
             (string-append (program-name) ": missing required option: \"--input\"\n\n"
                            ((parse-required '("-i" "a")) "help")))))

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

  (define-test test-help-ignores-the-default
    (let ([option (parse '())])
      (CHECK equal? (option "help" 'x) (option "help"))))

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

  (define-test test-format-usage-aligns-long-only-names
    (CHECK string=?
           (format-usage
            (list (make-option-ast "-a" "--alpha" 1 1 (builtin-converter 'int) "both" #f #f #f)
                  (make-option-ast #f "--beta" 0 0 (builtin-converter 'string) "long only" #f #f #f)
                  (make-option-ast "-c" #f 0 0 (builtin-converter 'string) "short only" #f #f #f))
            "prog")
           (string-append
            "Usage: prog [options]\n"
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
    [:long "--mixed" :choices ("auto" 1 2)]
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

  (define-test test-mixed-choices
    (CHECK equal? ((with-choices '("--mixed" "auto")) "mixed") "auto")
    (CHECK eqv? ((with-choices '("--mixed" "2")) "mixed") 2))

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

  (define-test test-choices-in-the-usage-text
    (let ([usage (format-usage
                  (list (make-option-ast "-f" "--format" 1 1
                                         (make-choice-converter '("json" "text" "yaml"))
                                         "output format" #f #f #f)
                        (make-option-ast #f "--level" 1 1
                                         (make-choice-converter '(1 2 4)) "verbosity level" #f #f #f)
                        (make-option-ast "-m" "--mode" 1 unlimited
                                         (make-choice-converter '("a" "b" "c")) "mode" #f #f #f)
                        (make-option-ast "-n" "--num" 0 2
                                         (make-choice-converter '("x" "y")) "number" #f #f #f))
                  "prog")])
      (CHECK eq? (and (contains? usage "-f, --format {json,text,yaml}  output format") #t) #t)
      (CHECK eq? (and (contains? usage "    --level {1,2,4}") #t) #t)
      (CHECK eq? (and (contains? usage "-m, --mode {a,b,c}...") #t) #t)
      (CHECK eq? (and (contains? usage "-n, --num [{x,y}] [{x,y}]") #t) #t)
      (CHECK eq? (and (contains? usage "<string>") #t) #f)))

  (define-test test-choices-are-aligned-with-the-other-options
    (CHECK string=?
           (format-usage
            (list (make-option-ast "-f" "--format" 1 1 (make-choice-converter '("json" "text"))
                                   "output format" #f #f #f)
                  (make-option-ast "-v" "--verbose" 0 0 #f "verbose" #f #f #f))
            "prog")
           (string-append
            "Usage: prog [options]\n"
            "\n"
            "Options:\n"
            "  -f, --format {json,text}  output format\n"
            "  -v, --verbose             verbose\n"
            "  -h, --help                show this help message and exit\n")))

  (define-test test-choices-show-in-the-help-of-a-parser
    (when run-capturing-exit
      (let ([result (run-capturing-exit (lambda () (with-choices '("-h"))))])
        (CHECK eqv? (car result) 0)
        (CHECK eq? (and (contains? (cdr result) "-f, --format {json,text,yaml}") #t) #t)
        (CHECK eq? (and (contains? (cdr result) "--level {1,2,4}") #t) #t)
        (CHECK eq? (and (contains? (cdr result) "-m, --mode {a,b,c}...") #t) #t)
        (CHECK eq? (and (contains? (cdr result) "--delta {-1,0,1}") #t) #t))))

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

  (define usage-specs
    (list
     (make-option-ast "-v" "--verbose" 0 0 (builtin-converter 'string) "verbose output" #f #f #f)
     (make-option-ast "-n" "--count" 1 1 (builtin-converter 'int) "repeat count" #f #f #f)
     (make-option-ast "-f" "--files" 1 unlimited (builtin-converter 'string) "input files" #f #f #f)
     (make-option-ast "-r" "--range" 0 2 (builtin-converter 'int) "range" #f #f #f)
     (make-option-ast "-q" #f 0 0 (builtin-converter 'string) "quiet" #f #f #f)
     (make-option-ast "-u" "--upper" 1 1 (procedure->converter string-upcase) "first line\nsecond line" #f #f #f)))

  (define-test test-format-usage
    (CHECK string=?
           (format-usage usage-specs "prog")
           (string-append
            "Usage: prog [options]\n"
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

  (define-test test-format-usage-column-is-aligned
    ;; every row has its description at column 31
    (let ([rows (filter (lambda (l) (and (> (string-length l) 31)
                                         (char=? (string-ref l 2) #\-)))
                        (split-lines (format-usage usage-specs "prog")))])
      (CHECK eqv? (length rows) 7)
      (for-each
       (lambda (row)
         (CHECK equal? (substring row 29 31) "  ")
         (CHECK eq? (char=? (string-ref row 31) #\space) #f))
       rows)))

  (define-test test-format-usage-placeholders
    (let ([usage (format-usage
                  (list
                   (make-option-ast "-a" #f 2 2 (builtin-converter 'int) "d" #f #f #f)
                   (make-option-ast "-b" #f 0 unlimited (builtin-converter 'string) "d" #f #f #f)
                   (make-option-ast "-c" #f 1 3 (builtin-converter 'float) "d" #f #f #f))
                  "p")])
      (CHECK eq? (and (contains? usage "-a <int> <int>") #t) #t)
      (CHECK eq? (and (contains? usage "-b [<string>...]") #t) #t)
      (CHECK eq? (and (contains? usage "-c <float> [<float>] [<float>]") #t) #t)))

  (define-test test-format-usage-without-options
    (CHECK string=?
           (format-usage '() "p")
           (string-append
            "Usage: p [options]\n"
            "\n"
            "Options:\n"
            "  -h, --help  show this help message and exit\n")))

  (define-test test-help-short-calls-handler
    (let* ([shown #f]
           [option (parse-command-line usage-specs '("-h")
                                       (lambda (text) (set! shown text)))])
      (CHECK equal? shown (format-usage usage-specs (program-name)))
      (CHECK eq? (option "v") #f)))

  (define-test test-help-long-calls-handler
    (let ([shown #f])
      (parse-command-line usage-specs '("-v" "--help")
                          (lambda (text) (set! shown text)))
      (CHECK eq? (string? shown) #t)))

  (define-test test-help-after-double-dash-is-positional
    (let* ([shown #f]
           [option (parse-command-line usage-specs '("--" "-h")
                                       (lambda (text) (set! shown text))
                                       (list (make-positional-ast "args" 0 unlimited #f "" #f)))])
      (CHECK eq? shown #f)
      (CHECK equal? (option "args") '("-h"))))

  (define-test test-help-after-positional-shows-the-usage
    (let ([shown #f])
      (parse-command-line usage-specs '("a" "--help")
                          (lambda (text) (set! shown text)))
      (CHECK eq? (and shown #t) #t)))

  (define-test test-help-as-option-argument-is-escapable
    (let* ([shown #f]
           [option (parse-command-line usage-specs '("-u" "\\-h")
                                       (lambda (text) (set! shown text)))])
      (CHECK eq? shown #f)
      (CHECK equal? (option "u") "-H")))

  ;; ========================================
  ;; the help hook of the defined parser
  ;; ========================================

  (define-test test-the-parser-calls-the-help-hook-instead-of-exiting
    (let* ([shown '()]
           [option (parse '("-v" "-h" "-n" "5") (lambda (text) (set! shown (cons text shown))))])
      ;; called once, with the usage text, and the parse goes on to return an accessor
      (CHECK equal? shown (list ((parse '()) "help")))
      (CHECK eq? (procedure? option) #t)
      ;; what came before -h was read, what came after was not
      (CHECK eq? (and (not (memq (option "v") '(#f absent))) #t) #t)
      (CHECK equal? (option "n") #f)))

  (define-test test-the-help-hook-is-not-called-when-help-is-not-asked
    (let ([calls 0])
      (parse '("-v" "-n" "5") (lambda (text) (set! calls (+ calls 1))))
      (CHECK eqv? calls 0)))

  (define-test test-the-help-hook-skips-the-required-checks
    (let ([shown #f])
      (parse-required '("--help") (lambda (text) (set! shown text)))
      (CHECK eq? (and shown #t) #t)
      (parse-one '("-h") (lambda (text) (set! shown 'again)))
      (CHECK eq? shown 'again)))

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
     "Usage: " (program-name) " [options]\n"
     "\n"
     "Options:\n"
     "  -v, --verbose" (spaces 12) "verbose output\n"
     "  -n, --count <int>" (spaces 8) "repeat count\n"
     "  -f, --files <string>..." (spaces 2) "input files\n"
     "  -h, --help" (spaces 15) "show this help message and exit\n"))

  (define-test test-help-short-prints-usage-and-exits
    (when run-capturing-exit
      (let ([result (run-capturing-exit (lambda () (helpful '("-h"))))])
        (CHECK eqv? (car result) 0)
        (CHECK string=? (cdr result) helpful-usage))))

  (define-test test-help-long-prints-usage-and-exits
    (when run-capturing-exit
      (let ([result (run-capturing-exit (lambda () (helpful '("-v" "--help"))))])
        (CHECK eqv? (car result) 0)
        (CHECK string=? (cdr result) helpful-usage))))

  (define-test test-help-stops-parsing
    ;; options after -h are not parsed, so a bad one does not raise
    (when run-capturing-exit
      (let ([result (run-capturing-exit (lambda () (helpful '("-h" "--nope"))))])
        (CHECK eqv? (car result) 0))))

  (define-command-line-options takes-words [:positional "words" :arity (0 +)])

  (define-test test-help-after-double-dash-does-not-exit
    (when run-capturing-exit
      (let ([result (run-capturing-exit (lambda () (takes-words '("--" "-h"))))])
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
               (string-append (program-name) ": invalid argument value: \"-n\" \"abc\"\n\n"
                              ((parse '()) "help"))))
      (let ([result (run-capturing-exit-and-error (lambda () (parse-or-exit parse-one '())))])
        (CHECK eqv? (car result) 2)
        (CHECK eq? (contains? (caddr result) "too few positional arguments: \"file\"") #t)
        (CHECK eq? (contains? (caddr result) "Usage: ") #t))))

  (define-test test-parse-or-exit-lets-the-other-errors-through
    (let ([e (raised (lambda () (parse-or-exit (lambda (arguments) (error 'mine "a bug")) '())))])
      (CHECK equal? (condition-message e) "a bug")
      (CHECK eq? (command-line-error? e) #f)))

  (define-test test-parse-or-exit-keeps-the-help-exit-of-the-parser
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

  (define-test test-program-name-is-a-string
    (CHECK eq? (string? (program-name)) #t))

  ;; ========================================
  ;; converters
  ;; ========================================

  (define-test test-builtin-converters-is-an-association-list
    (CHECK equal? (map car builtin-converters) '(string int float bool))
    (CHECK eq? (cdr (assq 'int builtin-converters)) (builtin-converter 'int))
    (CHECK eq? (assq 'lambda builtin-converters) #f))

  (define-test test-builtin-converters-convert
    ;; a converter is given the text and the name of the option
    (CHECK equal? ((converter-convert (builtin-converter 'string)) "x y" "-a") "x y")
    (CHECK eqv? ((converter-convert (builtin-converter 'int)) "12" "-a") 12)
    (CHECK eqv? ((converter-convert (builtin-converter 'float)) "2" "-a") 2.0)
    (CHECK eq? ((converter-convert (builtin-converter 'bool)) "yes" "-a") #t))

  (define-test test-builtin-converters-report-their-own-failure
    (for-each
     (lambda (name)
       (CHECK equal? (error-message (lambda () ((converter-convert (builtin-converter name)) "zz!" "-a")))
              "invalid argument value"))
     '(int float bool))
    (CHECK equal? (error-irritants (lambda () ((converter-convert (builtin-converter 'int)) "zz!" "--count")))
           '("--count" "zz!")))

  (define-test test-choice-converter-reports-its-own-failure
    (let ([convert (converter-convert (make-choice-converter '("a" 2)))])
      (CHECK equal? (convert "a" "-m") "a")
      (CHECK eqv? (convert "2" "-m") 2)
      (CHECK equal? (error-message (lambda () (convert "b" "-m"))) "argument must be one of the choices")
      (CHECK equal? (error-irritants (lambda () (convert "b" "-m"))) '("-m" "b" ("a" 2)))))

  (define-test test-procedure-converter-turns-any-failure-into-an-invalid-argument
    (let ([convert (converter-convert (procedure->converter (lambda (s) (raise 'bad))))])
      (CHECK equal? (error-message (lambda () (convert "v" "-a"))) "invalid argument value")
      (CHECK equal? (error-irritants (lambda () (convert "v" "-a"))) '("-a" "v")))
    (let ([convert (converter-convert (procedure->converter string-upcase))])
      (CHECK equal? (convert "v" "-a") "V")))

  (define-test test-converters-have-a-label
    (CHECK equal? (map (lambda (name) (converter-label (builtin-converter name)))
                       '(string int float bool))
           '("<string>" "<int>" "<float>" "<bool>"))
    (CHECK equal? (converter-label (procedure->converter string-upcase)) "<value>")
    (CHECK equal? (converter-label (make-choice-converter '("a" 2))) "{a,2}"))

  ;; a converter that nothing in the runtime knows about: it brings its label, and it reports
  ;; its own failure, given the text and the name of the option
  (define hex-converter
    (make-converter "<hex>"
                    (lambda (text name)
                      (or (string->number text 16)
                          (error 'opt-parser "not a hexadecimal number" name text)))))

  (define hex-spec (make-option-ast "-x" "--hex" 1 1 hex-converter "a hex number" #f #f #f))

  (define-test test-a-new-kind-of-converter-needs-no-change-in-the-runtime
    (CHECK eqv? ((parse-command-line (list hex-spec) '("--hex" "ff")) "x") 255)
    (CHECK eqv? ((parse-command-line (list hex-spec) '("-x=10")) "hex") 16))

  (define-test test-a-new-kind-of-converter-reports-its-own-failure
    (CHECK equal? (error-message (lambda () (parse-command-line (list hex-spec) '("--hex" "zz"))))
           "not a hexadecimal number")
    (CHECK equal? (error-irritants (lambda () (parse-command-line (list hex-spec) '("--hex" "zz"))))
           '("--hex" "zz")))

  (define-test test-a-new-kind-of-converter-shows-its-own-label
    (CHECK eq? (and (contains? (format-usage (list hex-spec) "p") "-x, --hex <hex>  a hex number") #t) #t))

  (define-test test-a-custom-procedure-fails-with-the-conversion-message
    (let ([spec (make-option-ast "-a" #f 1 1 (procedure->converter (lambda (s) (error 'x "no"))) "d" #f #f #f)])
      (CHECK equal? (error-message (lambda () (parse-command-line (list spec) '("-a" "v"))))
             "invalid argument value")
      (CHECK equal? (error-irritants (lambda () (parse-command-line (list spec) '("-a" "v"))))
             '("-a" "v"))))

  (define-test test-usage-names-a-builtin-converter-and-calls-a-custom-one-a-value
    (let ([usage (format-usage
                  (list (make-option-ast "-a" #f 1 1 (builtin-converter 'int) "d" #f #f #f)
                        (make-option-ast "-b" #f 1 1 (builtin-converter 'float) "d" #f #f #f)
                        (make-option-ast "-c" #f 1 1 (builtin-converter 'bool) "d" #f #f #f)
                        (make-option-ast "-d" #f 1 1 (builtin-converter 'string) "d" #f #f #f)
                        (make-option-ast "-e" #f 1 1 (procedure->converter string-upcase) "d" #f #f #f))
                  "p")])
      (for-each
       (lambda (flag)
         (CHECK eq? (and (contains? usage flag) #t) #t))
       '("-a <int>" "-b <float>" "-c <bool>" "-d <string>" "-e <value>"))))

  (define-test test-no-converter-means-the-text-as-it-is
    (let ([option (parse-command-line
                   (list (make-option-ast "-a" #f 1 1 #f "d" #f #f #f)
                         (make-option-ast "-b" #f 1 unlimited #f "d" #f #f #f))
                   '("-a" "12" "-b" "x" "y"))])
      (CHECK equal? (option "a") "12")
      (CHECK equal? (option "b") '("x" "y"))))

  (define-test test-usage-calls-no-converter-a-string
    (let ([usage (format-usage (list (make-option-ast "-a" #f 1 1 #f "d" #f #f #f)) "p")])
      (CHECK eq? (and (contains? usage "-a <string>") #t) #t)))

  (define-test test-convert-int-direct
    (CHECK eqv? (convert-int "10") 10)
    (CHECK eqv? (convert-int "-10") -10)
    (CHECK eqv? (convert-int "+3") 3)
    (CHECK eqv? (convert-int "0") 0))

  (define-test test-convert-float-direct
    (CHECK eqv? (convert-float "1e3") 1000.0)
    (CHECK eqv? (convert-float "-0.5") -0.5)
    (CHECK eqv? (convert-float ".5") 0.5))

  (define-test test-convert-bool-direct
    (CHECK eq? (convert-bool "yes") #t)
    (CHECK eq? (convert-bool "off") #f))

  (define-test test-convert-string-direct
    (CHECK equal? (convert-string "x y") "x y"))

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
    (CHECK equal? ((parse-mixed '("f" "-nope")) "files") '("f" "-nope")))

  (define-test test-mixed-unknown-long-option-after-positional
    (CHECK equal? (error-message (lambda () (parse-mixed '("f" "--nope")))) "unknown option"))
  ;; ========================================
  ;; (option 'help), the usage as a string
  ;; ========================================

  (define-command-line-options parse-small
    [:short "-v" :long "--verbose" :arity 0 :description "verbose output"])

  (define-test test-help-key-returns-the-usage
    (CHECK equal? ((parse-small '()) 'help)
           (string-append "Usage: " (program-name) " [options]\n"
                          "\n"
                          "Options:\n"
                          "  -v, --verbose  verbose output\n"
                          "  -h, --help     show this help message and exit\n")))

  (define-test test-help-key-is-the-same-text-as-the-help-option
    (let ([shown #f])
      (parse-command-line usage-specs '("-h") (lambda (text) (set! shown text)))
      (CHECK equal? ((parse-command-line usage-specs '()) 'help) shown)))

  (define-test test-help-key-does-not-start-the-help
    (CHECK eq? (string? ((parse '("-v")) 'help)) #t)
    (CHECK eq? (contains? ((parse '()) 'help) "--count") #t))

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
    (let ([shown #f])
      (parse-command-line (list (make-option-ast "-i" "--input" 1 1 #f "" #f #t #f))
                          '("--help")
                          (lambda (text) (set! shown text)))
      (CHECK eq? (and shown #t) #t)))

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

  (define-test test-help-is-an-option-name
    (let ([option (parse-small '())])
      (CHECK equal? (option "help") (option 'help))
      (CHECK eq? (contains? (option "help") "--verbose") #t)))

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
    (let ([shown #f])
      (parse-command-line (list (make-option-ast "-v" #f 0 0 #f "" #f #f #f))
                          '("--help")
                          (lambda (text) (set! shown text))
                          (list (make-positional-ast "file" 1 1 #f "" #f)))
      (CHECK eq? (and shown #t) #t)))

  ;; ========================================
  ;; usage with a positional
  ;; ========================================

  (define-command-line-options parse-documented
    [:short "-v" :arity 0 :description "verbose"]
    [:positional "file" :arity (1 +) :description "files to read"])

  (define-test test-usage-lists-the-positional
    (CHECK equal? ((parse-documented '("a")) 'help)
           (string-append "Usage: " (program-name) " [options] [--] <file>...\n"
                          "\n"
                          "Arguments:\n"
                          "  <file>...  files to read\n"
                          "\n"
                          "Options:\n"
                          "  -v          verbose\n"
                          "  -h, --help  show this help message and exit\n")))

  (define-test test-usage-placeholders-of-a-positional
    (for-each
     (lambda (case)
       (let ([usage (format-usage '() "p" (list (make-positional-ast "f" (car case) (cadr case) #f "" #f)))])
         (CHECK eq? (contains? usage (string-append "p [options] [--] " (caddr case) "\n")) #t)))
     (list (list 1 1 "<f>")
           (list 0 1 "[<f>]")
           (list 1 unlimited "<f>...")
           (list 0 unlimited "[<f>...]")
           (list 2 2 "<f> <f>"))))

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
    (CHECK equal? ((parse-metavar '()) 'help)
           (string-append "Usage: " (program-name) " [options]\n"
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
    (CHECK equal? ((parse-metavar-choices '()) 'help)
           (string-append "Usage: " (program-name) " [options]\n"
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
    (let ([shown #f])
      (parse-command-line (list (make-option-ast #f "--input" 1 1 #f "" #f #t #f))
                          '("-h")
                          (lambda (text) (set! shown text))
                          (list (make-positional-ast "file" 1 1 #f "" #f)))
      (CHECK eq? (and shown #t) #t)))

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

  (define-test test-positional-and-the-equals-form-of-an-option
    (let ([option (parse-mode '("fast" "-v"))])
      (CHECK equal? (option "mode") "fast"))
    (let ([option (parse-command-line
                   (list (make-option-ast "-n" "--count" 1 1 (builtin-converter 'int) "" #f #f #f))
                   '("f" "--count=3")
                   default-on-help
                   (list (make-positional-ast "file" 1 1 #f "" #f)))])
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

  (define-test test-positional-too-few-and-too-many-through-the-runtime
    (let ([parse-with (lambda (min max words)
                        (parse-command-line '() words default-on-help
                                            (list (make-positional-ast "w" min max #f "" #f))))])
      (CHECK equal? (error-message (lambda () (parse-with 2 3 '("a")))) "too few positional arguments")
      (CHECK equal? (error-irritants (lambda () (parse-with 2 3 '("a")))) '("w"))
      (CHECK equal? ((parse-with 2 3 '("a" "b")) "w") '("a" "b"))
      (CHECK equal? ((parse-with 2 3 '("a" "b" "c")) "w") '("a" "b" "c"))
      (CHECK equal? (error-irritants (lambda () (parse-with 2 3 '("a" "b" "c" "d" "e"))))
             '("d" "e"))))


  ;; the positionals shared out as ((name word ...) ...), for the tests below
  (define (shared-out positionals words)
    (map (lambda (pair) (cons (positional-ast-name (car pair)) (cdr pair)))
         (distribute-words positionals words)))

  (define (positional-ast* name min max)
    (make-positional-ast name min max #f "" #f))

  (define-test test-distribute-words-gives-each-positional-its-words-in-order
    (let ([cp (list (positional-ast* "source" 1 unlimited) (positional-ast* "dest" 1 1))]
          [sandwich (list (positional-ast* "first" 1 1) (positional-ast* "middle" 0 unlimited)
                          (positional-ast* "last" 1 1))]
          [bounded (list (positional-ast* "x" 2 2) (positional-ast* "y" 0 2))])
      (CHECK equal? (shared-out cp '("a" "b" "c")) '(("source" "a" "b") ("dest" "c")))
      (CHECK equal? (shared-out cp '("a" "b")) '(("source" "a") ("dest" "b")))
      (CHECK equal? (shared-out sandwich '("a" "z")) '(("first" "a") ("middle") ("last" "z")))
      (CHECK equal? (shared-out sandwich '("a" "m" "n" "z"))
             '(("first" "a") ("middle" "m" "n") ("last" "z")))
      (CHECK equal? (shared-out bounded '("a" "b")) '(("x" "a" "b") ("y")))
      (CHECK equal? (shared-out bounded '("a" "b" "c" "d")) '(("x" "a" "b") ("y" "c" "d")))))

  (define-test test-distribute-words-with-no-positional
    (CHECK equal? (shared-out '() '()) '())
    (CHECK equal? (error-message (lambda () (shared-out '() '("a" "b")))) "unexpected positional argument")
    (CHECK equal? (error-irritants (lambda () (shared-out '() '("a" "b")))) '("a" "b")))

  (define-test test-distribute-words-errors
    (let ([three (list (positional-ast* "a" 1 1) (positional-ast* "b" 1 1) (positional-ast* "c" 1 1))])
      (CHECK equal? (error-irritants (lambda () (shared-out three '()))) '("a"))
      (CHECK equal? (error-irritants (lambda () (shared-out three '("x")))) '("b"))
      (CHECK equal? (error-irritants (lambda () (shared-out three '("x" "y")))) '("c"))
      (CHECK equal? (error-message (lambda () (shared-out three '("x" "y")))) "too few positional arguments")
      (CHECK equal? (error-message (lambda () (shared-out three '("x" "y" "z" "w"))))
             "too many positional arguments")
      (CHECK equal? (error-irritants (lambda () (shared-out three '("x" "y" "z" "w" "v")))) '("w" "v"))
      (CHECK equal? (shared-out three '("x" "y" "z")) '(("a" "x") ("b" "y") ("c" "z")))))

  ;; ========================================
  ;; the steps of the parser, on specs built by hand
  ;; ========================================

  (define scan-specs
    (list (make-option-ast "-v" "--verbose" 0 0 #f "" #f #f #f)
          (make-option-ast "-n" "--count" 1 1 (builtin-converter 'int) "" #f #f #f)
          (make-option-ast "-e" #f 1 unlimited #f "" #f #f #f)))

  ;; (scan tokens) => (words help-asked? help-calls count-entry)
  (define (scan tokens)
    (let* ([calls 0]
           [result (scan-tokens scan-specs (lambda () (set! calls (+ calls 1))) tokens)])
      (list (parse-result-words result)
            (parse-result-help-asked? result)
            calls
            (hashtable-ref (parse-result-table result) (cadr scan-specs) #f))))

  (define-test test-scan-tokens-separates-options-from-words
    (CHECK equal? (scan '("a" "-n" "3" "b")) '(("a" "b") #f 0 (3)))
    (CHECK equal? (scan '("-v" "a")) '(("a") #f 0 #f))
    (CHECK equal? (scan '()) '(() #f 0 #f)))

  (define-test test-scan-tokens-double-dash-ends-the-options
    (CHECK equal? (scan '("a" "--" "-n" "3")) '(("a" "-n" "3") #f 0 #f))
    (CHECK equal? (scan '("--" "--")) '(("--") #f 0 #f)))

  (define-test test-scan-tokens-unescapes-words-before-the-double-dash-only
    (CHECK equal? (scan '("\\-a" "--" "\\-b")) '(("-a" "\\-b") #f 0 #f)))

  (define-test test-scan-tokens-help-keeps-the-words-before-it-and-drops-the-rest
    (CHECK equal? (scan '("a" "--help" "b" "-n" "3")) '(("a") #t 1 #f))
    (CHECK equal? (scan '("-h")) '(() #t 1 #f)))

  (define-test test-scan-tokens-a-word-that-is-not-an-option-is-a-word
    (CHECK equal? (scan '("-nope")) '(("-nope") #f 0 #f))
    (CHECK equal? (scan '("-5" "-n" "-6")) '(("-5") #f 0 (-6))))

  (define-test test-scan-tokens-errors
    (CHECK equal? (error-message (lambda () (scan '("--nope")))) "unknown option")
    (CHECK equal? (error-message (lambda () (scan '("-n")))) "too few arguments for option")
    (CHECK equal? (error-message (lambda () (scan '("-v=1")))) "option does not take arguments"))

  (define-test test-scan-tokens-an-unlimited-option-stops-at-an-option-or-the-double-dash
    (let ([result (scan-tokens scan-specs (lambda () #f) '("-e" "x" "y" "-v" "z" "--" "w"))])
      (CHECK equal? (hashtable-ref (parse-result-table result) (caddr scan-specs) #f) '("x" "y"))
      (CHECK equal? (parse-result-words result) '("z" "w"))))

  (define-test test-check-required-names-the-first-missing-option
    (let ([specs (list (make-option-ast "-a" "--aa" 1 1 #f "" #f #t #f)
                       (make-option-ast "-b" #f 1 1 #f "" #f #t #f)
                       (make-option-ast "-c" #f 1 1 #f "" #f #f #f))]
          [table (make-eq-hashtable)])
      (CHECK equal? (error-irritants (lambda () (check-required specs table))) '("--aa"))
      (hashtable-set! table (car specs) '("x"))
      (CHECK equal? (error-irritants (lambda () (check-required specs table))) '("-b"))
      (hashtable-set! table (cadr specs) '())
      (CHECK equal? (begin (check-required specs table) 'no-error) 'no-error)))
  ;; ========================================
  ;; the usage of a positional
  ;; ========================================

  (define-test test-usage-of-a-positional-without-a-description
    (CHECK equal? (format-usage '() "p" (list (make-positional-ast "file" 1 1 #f "" #f)))
           (string-append "Usage: p [options] [--] <file>\n"
                          "\n"
                          "Arguments:\n"
                          "  <file>\n"
                          "\n"
                          "Options:\n"
                          "  -h, --help  show this help message and exit\n")))

  (define-test test-usage-of-a-positional-with-a-multi-line-description
    (CHECK equal? (format-usage '() "p" (list (make-positional-ast "f" 0 unlimited #f "first\nsecond" #f)))
           (string-append "Usage: p [options] [--] [<f>...]\n"
                          "\n"
                          "Arguments:\n"
                          "  [<f>...]  first\n"
                          "            second\n"
                          "\n"
                          "Options:\n"
                          "  -h, --help  show this help message and exit\n")))

  (define-test test-usage-without-a-positional-has-no-arguments-section
    (CHECK eq? (contains? (format-usage '() "p") "Arguments:") #f)
    (CHECK eq? (contains? (format-usage '() "p") "[--]") #f))
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

  (define-test test-too-many-gives-the-words-that-no-positional-takes
    (CHECK equal? (error-message (lambda () (parse-bounded '("a" "b" "c" "d" "e"))))
           "too many positional arguments")
    (CHECK equal? (error-irritants (lambda () (parse-bounded '("a" "b" "c" "d" "e" "f"))))
           '("e" "f"))
    (CHECK equal? (error-message (lambda () (parse-command-line '() '("a" "b" "c") default-on-help
                                                                (list (make-positional-ast "p" 1 1 #f "" #f)
                                                                      (make-positional-ast "q" 1 1 #f "" #f)))))
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
    (let ([shown #f])
      (parse-command-line '() '("--help") (lambda (text) (set! shown text))
                          (list (make-positional-ast "a" 1 1 #f "" #f)
                                (make-positional-ast "b" 2 2 #f "" #f)))
      (CHECK eq? (and shown #t) #t)))

  (define-test test-usage-lists-every-positional
    (CHECK equal? ((parse-cp '("a" "b")) 'help)
           (string-append "Usage: " (program-name) " [options] [--] <source>... <dest>\n"
                          "\n"
                          "Arguments:\n"
                          "  <source>...  files to copy\n"
                          "  <dest>       where to copy them\n"
                          "\n"
                          "Options:\n"
                          "  -v          verbose\n"
                          "  -h, --help  show this help message and exit\n")))

  (define-test test-usage-of-exact-and-optional-positionals
    (CHECK equal? ((parse-sandwich '("a" "z")) 'help)
           (string-append "Usage: " (program-name) " [options] [--] <first> [<middle>...] <last>\n"
                          "\n"
                          "Arguments:\n"
                          "  <first>\n"
                          "  [<middle>...]\n"
                          "  <last>\n"
                          "\n"
                          "Options:\n"
                          "  -h, --help  show this help message and exit\n")))

  (define-test test-usage-of-a-positional-with-an-exact-arity-above-one
    (CHECK equal? ((parse-bounded '("a" "b")) 'help)
           (string-append "Usage: " (program-name) " [options] [--] <x> <x> [<y>] [<y>]\n"
                          "\n"
                          "Arguments:\n"
                          "  <x> <x>\n"
                          "  [<y>] [<y>]\n"
                          "\n"
                          "Options:\n"
                          "  -h, --help  show this help message and exit\n")))
  ;; ========================================
  ;; the setters of the records, set once
  ;; ========================================

  ;; the setters of the records, one for each field: set a field that is still unbound, and call
  ;; on-duplicate for one that was given already
  (define (check-setters make-unbound field-setters)
    (for-each
     (lambda (entry)
       (let ([setter (car entry)] [getter (cadr entry)] [first (caddr entry)] [second (cadddr entry)]
             [calls 0])
         (let ([record (make-unbound)])
           (setter record first (lambda () (set! calls (+ calls 1))))
           (CHECK equal? (getter record) first)
           (CHECK eqv? calls 0)
           (setter record second (lambda () (set! calls (+ calls 1))))
           (CHECK equal? (getter record) first)
           (CHECK eqv? calls 1))))
     field-setters))

  (define-test test-option-ast-setters-set-a-field-once
    (check-setters
     (lambda () (make-unbound-option-ast 'src))
     (list (list option-ast-short-set-if-not-given-yet! option-ast-short "-a" "-b")
           (list option-ast-long-set-if-not-given-yet! option-ast-long "--a" "--b")
           (list option-ast-min-set-if-not-given-yet! option-ast-min 1 2)
           (list option-ast-max-set-if-not-given-yet! option-ast-max 3 4)
           (list option-ast-converter-set-if-not-given-yet! option-ast-converter 'e1 'e2)
           (list option-ast-description-set-if-not-given-yet! option-ast-description "d1" "d2")
           (list option-ast-required-set-if-not-given-yet! option-ast-required #t #f))))

  (define-test test-positional-ast-setters-set-a-field-once
    (check-setters
     (lambda () (make-unbound-positional-ast 'src))
     (list (list positional-ast-name-set-if-not-given-yet! positional-ast-name "a" "b")
           (list positional-ast-min-set-if-not-given-yet! positional-ast-min 1 2)
           (list positional-ast-max-set-if-not-given-yet! positional-ast-max 3 4)
           (list positional-ast-converter-set-if-not-given-yet! positional-ast-converter 'e1 'e2)
           (list positional-ast-description-set-if-not-given-yet! positional-ast-description "d1" "d2"))))

  (define-test test-a-setter-counts-false-as-given
    (let ([o (make-unbound-option-ast 'src)]
          [calls 0])
      (option-ast-short-set-if-not-given-yet! o #f (lambda () (set! calls (+ calls 1))))
      (option-ast-short-set-if-not-given-yet! o "-a" (lambda () (set! calls (+ calls 1))))
      (CHECK eqv? calls 1)
      (CHECK equal? (option-ast-short o) #f)))

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
       ("-h and --help are reserved for the built-in help" [:short "-h"])
       ("-h and --help are reserved for the built-in help" [:long "--help"])
       ("-h and --help are reserved for the built-in help" [:short "-a" :long "--help"])
       ("-h and --help are reserved for the built-in help" [:long "--h"])
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
       ("duplicate choice" [:short "-a" :choices ("x" "x")])
       ("duplicate choice" [:short "-a" :choices (1 "1")])
       ("duplicate choice" [:short "-a" :choices ("1" 1)])
       (":description must be a string" [:short "-a" :description 42])
       (":description must be a string" [:short "-a" :description x])
       (#f [:short "-a" :type int])
       (#f [:short "-a" :type float])
       (#f [:short "-a" :type bool])
       (#f [:short "-a" :type string])
       (#f [:short "-a" :type string-upcase])
       (#f [:short "-a" :type (lambda (s) s)])
       (#f [:short "-a" :choices ("x" "y")])
       (#f [:short "-a" :choices (1 2 "a")])
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
       ("-h and --help are reserved for the built-in help" [:positional "h"])
       ("-h and --help are reserved for the built-in help" [:positional "help"])
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
