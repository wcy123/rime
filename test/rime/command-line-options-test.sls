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
      (CHECK eq? (option "v") 'present)
      (CHECK eq? (option "verbose") 'present)
      (CHECK eq? (option "q") 'present)))

  (define-test test-arity-0-absent
    (let ([option (parse '())])
      (CHECK eq? (option "v") 'absent)
      (CHECK eq? (option "verbose") 'absent)
      (CHECK eq? (option "q") 'absent)))

  (define-test test-arity-0-long-name
    (let ([option (parse '("--verbose"))])
      (CHECK eq? (option "v") 'present)
      (CHECK eq? (option "q") 'absent)))

  (define-test test-arity-0-does-not-consume-next
    (let ([option (parse '("-v" "file"))])
      (CHECK eq? (option "v") 'present)
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

  (define-test test-form-long-equals-comma
    (let ([option (parse '("--files=a,b,c"))])
      (CHECK equal? (option "f") '("a" "b" "c"))))

  (define-test test-form-long-equals-single
    (let ([option (parse '("--count=5"))])
      (CHECK eqv? (option "n") 5)))

  (define-test test-form-short-equals
    (let ([option (parse '("-f=a,b"))])
      (CHECK equal? (option "f") '("a" "b"))))

  (define-test test-form-equals-converts-each-item
    (let ([option (parse '("--pair=3,4"))])
      (CHECK equal? (option "p") '(3 4))))

  (define-test test-form-equals-does-not-consume-next
    (let ([option (parse '("--files=a,b" "pos"))])
      (CHECK equal? (option "f") '("a" "b"))
      (CHECK equal? (positional option 0) "pos")))

  (define-test test-form-equals-value-may-start-with-dash
    (let ([option (parse '("--name=-weird"))])
      (CHECK equal? (option "s") "-weird")))

  (define-test test-form-equals-empty-value
    (let ([option (parse '("--name="))])
      (CHECK equal? (option "s") "")))

  (define-test test-form-mixed
    (let ([option (parse '("-v" "--count=2" "-f" "a" "b" "-s" "n" "--ratio" "0.5"))])
      (CHECK eq? (option "v") 'present)
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
      (CHECK equal? (option "f") '("-a" "b"))))

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
      (CHECK eq? (option "v") 'present)
      (CHECK eqv? (option "n") 3)
      (CHECK eqv? (positional-count option) 2)
      (CHECK equal? (positional option 0) "in.txt")
      (CHECK equal? (positional option 1) "out.txt")))

  (define-test test-positional-after-double-dash
    (let ([option (parse '("-v" "--" "a" "b"))])
      (CHECK eq? (option "v") 'present)
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
      (CHECK eq? (option "v") 'absent)
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
      (CHECK eq? (option "v") 'present)
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

  (define-test test-error-unknown-short-option
    (CHECK equal? (error-message (lambda () (parse '("-z"))))
           "unknown option"))

  (define-test test-error-unknown-long-option
    (CHECK equal? (error-message (lambda () (parse '("--nope"))))
           "unknown option"))

  (define-test test-error-unknown-long-option-with-equals
    (CHECK equal? (error-message (lambda () (parse '("--nope=1"))))
           "unknown option"))

  (define-test test-error-clustered-short-options-unsupported
    (CHECK equal? (error-message (lambda () (parse '("-vq"))))
           "unknown option"))

  (define-test test-error-negative-number-needs-escape
    (CHECK equal? (error-message (lambda () (parse '("-n" "-5"))))
           "too few arguments for option"))

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

  (define-test test-error-too-many-in-equals-form
    (CHECK equal? (error-message (lambda () (parse '("--count=1,2"))))
           "too many arguments for option")
    (CHECK equal? (error-message (lambda () (parse '("--range=1,2,3"))))
           "too many arguments for option"))

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
  ;; accessor errors
  ;; ========================================

  (define-test test-accessor-unknown-option
    (let ([option (parse '())])
      (CHECK equal? (error-message (lambda () (option "z"))) "unknown option")
      (CHECK equal? (error-message (lambda () (option "nope"))) "unknown option")
      (CHECK equal? (error-message (lambda () (option 'count))) "unknown option")
      (CHECK equal? (error-message (lambda () (option "count"))) "unknown option")
      (CHECK equal? (error-message (lambda () (option "h"))) "unknown option")))

  (define-test test-accessor-invalid-key
    (let ([option (parse '())])
      (CHECK equal? (error-message (lambda () (option 1.5))) "invalid option key")
      (CHECK equal? (error-message (lambda () (option #\a))) "invalid option key")
      (CHECK equal? (error-message (lambda () (option '(1)))) "invalid option key")))

  ;; ========================================
  ;; names may also be given as symbols
  ;; ========================================
  ;; strict R6RS readers (Chez .sls) cannot read -v or --long as symbols, so build them

  (define (sym s) (string->symbol s))

  (define-test test-accessor-accepts-symbols
    (let ([option (parse '("-n" "4" "-v"))])
      (CHECK eqv? (option (sym "n")) 4)
      (CHECK eqv? (option (sym "count")) 4)
      (CHECK eq? (option (sym "verbose")) 'present)
      (CHECK eq? (option (sym "q")) 'absent)))

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
      (CHECK eqv? (a 'number-of-positional-argument) 0)
      (CHECK eqv? (b 'number-of-positional-argument) 1)))

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
    (CHECK eq? ((flag '("-g")) "g") 'present)
    (CHECK eq? ((flag '()) "g") 'absent))

  (define-test test-no-options-defined
    (let ([option (none '("a" "b"))])
      (CHECK eqv? (positional-count option) 2)))

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
      (CHECK eq? (option "s") 'absent)))

  (define-test test-long-only-option-with-equals
    (let ([option (mixed-names '("--long-only=4"))])
      (CHECK eqv? (option "long-only") 4)))

  (define-test test-long-only-flag
    (let ([option (mixed-names '("--flag-only"))])
      (CHECK eq? (option "flag-only") 'present)
      (CHECK eq? ((mixed-names '()) "flag-only") 'absent)))

  (define-test test-long-only-option-absent
    (CHECK eq? ((mixed-names '()) "long-only") #f))

  (define-test test-short-only-option
    (let ([option (mixed-names '("-s"))])
      (CHECK eq? (option "s") 'present)))

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
      (CHECK eq? (option "flag-only") 'present)
      (CHECK eq? (option "s") 'absent)
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
            (list (make-option-ast "-a" "--alpha" 1 1 (builtin-converter 'int) "both" #f #f)
                  (make-option-ast #f "--beta" 0 0 (builtin-converter 'string) "long only" #f #f)
                  (make-option-ast "-c" #f 0 0 (builtin-converter 'string) "short only" #f #f))
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

  (define-test test-negative-integer-choice-needs-the-escape
    (CHECK eqv? ((with-choices '("--delta" "\\-1")) "delta") -1)
    (CHECK eqv? ((with-choices '("--delta" "0")) "delta") 0))

  (define-test test-every-argument-is-checked
    (CHECK equal? ((with-choices '("-m" "a" "c" "b")) "mode") '("a" "c" "b"))
    (CHECK equal? ((with-choices '("--mode=a,b")) "m") '("a" "b"))
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
                                         "output format" #f #f)
                        (make-option-ast #f "--level" 1 1
                                         (make-choice-converter '(1 2 4)) "verbosity level" #f #f)
                        (make-option-ast "-m" "--mode" 1 unlimited
                                         (make-choice-converter '("a" "b" "c")) "mode" #f #f)
                        (make-option-ast "-n" "--num" 0 2
                                         (make-choice-converter '("x" "y")) "number" #f #f))
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
                                   "output format" #f #f)
                  (make-option-ast "-v" "--verbose" 0 0 #f "verbose" #f #f))
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
    (CHECK eq? ((with-choices '("-v" "--format" "json")) "v") 'present))

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
     (make-option-ast "-v" "--verbose" 0 0 (builtin-converter 'string) "verbose output" #f #f)
     (make-option-ast "-n" "--count" 1 1 (builtin-converter 'int) "repeat count" #f #f)
     (make-option-ast "-f" "--files" 1 unlimited (builtin-converter 'string) "input files" #f #f)
     (make-option-ast "-r" "--range" 0 2 (builtin-converter 'int) "range" #f #f)
     (make-option-ast "-q" #f 0 0 (builtin-converter 'string) "quiet" #f #f)
     (make-option-ast "-u" "--upper" 1 1 (procedure->converter string-upcase) "first line\nsecond line" #f #f)))

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
                   (make-option-ast "-a" #f 2 2 (builtin-converter 'int) "d" #f #f)
                   (make-option-ast "-b" #f 0 unlimited (builtin-converter 'string) "d" #f #f)
                   (make-option-ast "-c" #f 1 3 (builtin-converter 'float) "d" #f #f))
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
      (CHECK eqv? (positional-count option) 0)))

  (define-test test-help-long-calls-handler
    (let ([shown #f])
      (parse-command-line usage-specs '("-v" "--help")
                          (lambda (text) (set! shown text)))
      (CHECK eq? (string? shown) #t)))

  (define-test test-help-after-double-dash-is-positional
    (let* ([shown #f]
           [option (parse-command-line usage-specs '("--" "-h")
                                       (lambda (text) (set! shown text)))])
      (CHECK eq? shown #f)
      (CHECK equal? (positional option 0) "-h")))

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

  (define-test test-help-after-double-dash-does-not-exit
    (when run-capturing-exit
      (let ([result (run-capturing-exit (lambda () (helpful '("--" "-h"))))])
        (CHECK eq? (car result) 'exit-not-called)
        (CHECK equal? (cdr result) ""))))

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

  (define hex-spec (make-option-ast "-x" "--hex" 1 1 hex-converter "a hex number" #f #f))

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
    (let ([spec (make-option-ast "-a" #f 1 1 (procedure->converter (lambda (s) (error 'x "no"))) "d" #f #f)])
      (CHECK equal? (error-message (lambda () (parse-command-line (list spec) '("-a" "v"))))
             "invalid argument value")
      (CHECK equal? (error-irritants (lambda () (parse-command-line (list spec) '("-a" "v"))))
             '("-a" "v"))))

  (define-test test-usage-names-a-builtin-converter-and-calls-a-custom-one-a-value
    (let ([usage (format-usage
                  (list (make-option-ast "-a" #f 1 1 (builtin-converter 'int) "d" #f #f)
                        (make-option-ast "-b" #f 1 1 (builtin-converter 'float) "d" #f #f)
                        (make-option-ast "-c" #f 1 1 (builtin-converter 'bool) "d" #f #f)
                        (make-option-ast "-d" #f 1 1 (builtin-converter 'string) "d" #f #f)
                        (make-option-ast "-e" #f 1 1 (procedure->converter string-upcase) "d" #f #f))
                  "p")])
      (for-each
       (lambda (flag)
         (CHECK eq? (and (contains? usage flag) #t) #t))
       '("-a <int>" "-b <float>" "-c <bool>" "-d <string>" "-e <value>"))))

  (define-test test-no-converter-means-the-text-as-it-is
    (let ([option (parse-command-line
                   (list (make-option-ast "-a" #f 1 1 #f "d" #f #f)
                         (make-option-ast "-b" #f 1 unlimited #f "d" #f #f))
                   '("-a" "12" "-b" "x" "y"))])
      (CHECK equal? (option "a") "12")
      (CHECK equal? (option "b") '("x" "y"))))

  (define-test test-usage-calls-no-converter-a-string
    (let ([usage (format-usage (list (make-option-ast "-a" #f 1 1 #f "d" #f #f)) "p")])
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
    (CHECK equal? (mixed '("--emit=ast" "example.toy")) '("ast" absent #f ("example.toy"))))

  (define-test test-mixed-option-after-positional
    (CHECK equal? (mixed '("example.toy" "--emit=ast")) '("ast" absent #f ("example.toy"))))

  (define-test test-mixed-lone-dash-is-positional
    (CHECK equal? (mixed '("-" "--emit=ast")) '("ast" absent #f ("-"))))

  (define-test test-mixed-option-argument-after-positional
    (CHECK equal? (mixed '("example.toy" "-emit" "ast")) '("ast" absent #f ("example.toy"))))

  (define-test test-mixed-flag-after-positional
    (CHECK equal? (mixed '("example.toy" "-emit=mlir" "-opt")) '("mlir" present #f ("example.toy"))))

  (define-test test-mixed-option-before-and-after-positional
    (CHECK equal? (mixed '("-x" "mlir" "driver-input.txt" "-emit=mlir"))
           '("mlir" absent "mlir" ("driver-input.txt")))
    (CHECK equal? (mixed '("driver-input.txt" "-x" "mlir" "-emit=mlir"))
           '("mlir" absent "mlir" ("driver-input.txt"))))

  (define-test test-mixed-positional-only
    (CHECK equal? (mixed '("example.toy")) '(#f absent #f ("example.toy"))))

  (define-test test-mixed-double-dash-ends-options
    (CHECK equal? (mixed '("example.toy" "--" "--emit=ast")) '(#f absent #f ("example.toy" "--emit=ast")))
    (CHECK equal? (mixed '("-opt" "--" "-x")) '(#f present #f ("-x")))
    (CHECK equal? (mixed '("a" "--" "b" "-opt")) '(#f absent #f ("a" "b" "-opt"))))

  (define-test test-mixed-positional-order-is-kept
    (let ([option (parse-mixed '("a" "-v" "b" "-v" "c"))])
      (CHECK eq? (option "v") 'present)
      (CHECK equal? (positionals option) '("a" "b" "c"))
      (CHECK eqv? (positional-count option) 3)))

  (define-test test-mixed-escaped-word-is-positional
    (CHECK equal? (positionals (parse-mixed '("a" "\\-x" "b"))) '("a" "-x" "b")))

  (define-test test-mixed-option-with-unlimited-arity-takes-ordinary-words
    (let ([option (parse-mixed '("a" "-e" "x" "y" "b"))])
      (CHECK equal? (option "e") '("x" "y" "b"))
      (CHECK equal? (positionals option) '("a"))))

  (define-test test-mixed-unlimited-arity-stops-at-an-option
    (let ([option (parse-mixed '("-e" "x" "y" "-v" "b"))])
      (CHECK equal? (option "e") '("x" "y"))
      (CHECK eq? (option "v") 'present)
      (CHECK equal? (positionals option) '("b"))))

  (define-test test-mixed-last-occurrence-wins
    (CHECK equal? (mixed '("-emit=a" "f" "-emit=b")) '("b" absent #f ("f"))))

  (define-test test-mixed-unknown-option-after-positional
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
    [:short "-v" :arity 0 :description "verbose"])

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
      (CHECK equal? (positional option 0) "f")))

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
      (parse-command-line (list (make-option-ast "-i" "--input" 1 1 #f "" #f #t))
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
      (CHECK eq? (option "v") 'present)
      (CHECK eqv? (option "level") 3)
      (CHECK eqv? (option 'level) 3)))

  (define-test test-lookup-names-with-dashes-are-unknown
    (let ([option (parse-names '())])
      (CHECK equal? (error-message (lambda () (option "-v"))) "unknown option")
      (CHECK equal? (error-message (lambda () (option "--level"))) "unknown option")
      (CHECK equal? (error-irritants (lambda () (option "--level"))) '("--level"))))

  (define-test test-lookup-of-an-undefined-name
    (CHECK equal? (error-message (lambda () ((parse-names '()) "nope"))) "unknown option"))

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
    (CHECK eq? ((parse-mode '("-v" "fast")) "v") 'present)
    (CHECK equal? ((parse-mode '("fast" "-v")) "mode") "fast")
    (CHECK eq? ((parse-mode '("fast" "-v")) "v") 'present))

  (define-test test-positional-after-double-dash-and-escaped
    (CHECK equal? ((parse-files '("--" "-a" "-b")) "files") '("-a" "-b"))
    (CHECK equal? ((parse-files '("\\-a")) "files") '("-a")))

  (define-test test-positional-word-without-a-clause-is-an-error
    (CHECK equal? (error-message (lambda () (parse-none '("a")))) "unexpected positional argument")
    (CHECK equal? (error-irritants (lambda () (parse-none '("a" "b")))) '("a" "b"))
    (CHECK equal? (error-message (lambda () (parse-none '("--" "x")))) "unexpected positional argument"))

  (define-test test-no-positional-word-and-no-clause-is-fine
    (CHECK eq? ((parse-none '("-v")) "v") 'present))

  (define-test test-help-needs-no-positional-word
    (let ([shown #f])
      (parse-command-line (list (make-option-ast "-v" #f 0 0 #f "" #f #f))
                          '("--help")
                          (lambda (text) (set! shown text))
                          (make-positional-ast "file" 1 1 #f "" #f))
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
       (let ([usage (format-usage '() "p" (make-positional-ast "f" (car case) (cadr case) #f "" #f))])
         (CHECK eq? (contains? usage (string-append "p [options] [--] " (caddr case) "\n")) #t)))
     (list (list 1 1 "<f>")
           (list 0 1 "[<f>]")
           (list 1 unlimited "<f>...")
           (list 0 unlimited "[<f>...]")
           (list 2 2 "<f> <f>"))))

  ;; ========================================
  ;; definition errors of :positional
  ;; ========================================

  (define-test test-syntax-error-two-positional-clauses
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p [:positional "a"] [:positional "b"])
                   p))
           #t))

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
           #t)))
