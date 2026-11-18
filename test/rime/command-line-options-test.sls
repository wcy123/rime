#!r6rs
(library (test rime command-line-options-test)
  (export main)
  (import (rnrs (6))
          (rnrs eval (6))
          (rime unit-test)
          (rime command-line-options)
          (rime command-line-options __parser))

  (define (main)
    (run-all-tests))

  (define-command-line-options parse
    ["-v" :long "--verbose" :arity 0 :description "verbose output"]
    ["-q" :arity 0 :description "quiet"]
    ["-n" :long "--count" :arity 1 :type int :description "repeat count"]
    ["-x" :long "--ratio" :type float :description "ratio"]
    ["-b" :long "--flag" :type bool :description "a flag"]
    ["-s" :long "--name" :description "name"]
    ["-f" :long "--files" :arity (1 +) :type string :description "input files"]
    ["-r" :long "--range" :arity (0 2) :type int :description "range"]
    ["-p" :long "--pair" :arity 2 :type int :description "pair"]
    ["-u" :long "--upper" :type (lambda (s) (string-upcase s)) :description "custom"]
    ["-o" :long "--opt-list" :arity (0 +) :description "zero or more"])

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
      (CHECK eq? (option "-v") 'present)
      (CHECK eq? (option "--verbose") 'present)
      (CHECK eq? (option "-q") 'present)))

  (define-test test-arity-0-absent
    (let ([option (parse '())])
      (CHECK eq? (option "-v") 'absent)
      (CHECK eq? (option "--verbose") 'absent)
      (CHECK eq? (option "-q") 'absent)))

  (define-test test-arity-0-long-name
    (let ([option (parse '("--verbose"))])
      (CHECK eq? (option "-v") 'present)
      (CHECK eq? (option "-q") 'absent)))

  (define-test test-arity-0-does-not-consume-next
    (let ([option (parse '("-v" "file"))])
      (CHECK eq? (option "-v") 'present)
      (CHECK equal? (option 0) "file")))

  ;; ========================================
  ;; types
  ;; ========================================

  (define-test test-type-int
    (let ([option (parse '("-n" "42"))])
      (CHECK eqv? (option "-n") 42)
      (CHECK eqv? (option "--count") 42)))

  (define-test test-type-int-signed-escaped
    (let ([option (parse '("-n" "\\-7"))])
      (CHECK eqv? (option "-n") -7)))

  (define-test test-type-float
    (let ([option (parse '("-x" "2.5"))])
      (CHECK eqv? (option "-x") 2.5)))

  (define-test test-type-float-from-integer-text
    (let ([option (parse '("--ratio" "3"))])
      (CHECK eqv? (option "-x") 3.0)))

  (define-test test-type-bool-true-words
    (for-each
     (lambda (word)
       (CHECK eq? ((parse (list "-b" word)) "-b") #t))
     '("true" "yes" "on" "1" "TRUE" "Yes")))

  (define-test test-type-bool-false-words
    (for-each
     (lambda (word)
       (CHECK eq? ((parse (list "-b" word)) "-b") #f))
     '("false" "no" "off" "0" "FALSE" "No")))

  (define-test test-type-bool-false-value
    (CHECK eq? ((parse '("-b" "off")) "--flag") #f)
    (CHECK eq? ((parse '()) "--flag") #f))

  (define-test test-type-string-default
    (let ([option (parse '("-s" "hello"))])
      (CHECK equal? (option "-s") "hello")
      (CHECK equal? (option "--name") "hello")))

  (define-test test-type-custom-procedure
    (let ([option (parse '("-u" "abc"))])
      (CHECK equal? (option "-u") "ABC")))

  ;; ========================================
  ;; absent values
  ;; ========================================

  (define-test test-absent-single-argument-is-false
    (let ([option (parse '())])
      (CHECK eq? (option "-n") #f)
      (CHECK eq? (option "-s") #f)
      (CHECK eq? (option "--ratio") #f)))

  (define-test test-absent-multiple-argument-is-empty-list
    (let ([option (parse '())])
      (CHECK equal? (option "-f") '())
      (CHECK equal? (option "-r") '())
      (CHECK equal? (option "-p") '())
      (CHECK equal? (option "-o") '())))

  ;; ========================================
  ;; arity
  ;; ========================================

  (define-test test-arity-exact-n
    (let ([option (parse '("-p" "1" "2"))])
      (CHECK equal? (option "-p") '(1 2))))

  (define-test test-arity-min-unbounded
    (let ([option (parse '("-f" "a" "b" "c"))])
      (CHECK equal? (option "--files") '("a" "b" "c"))))

  (define-test test-arity-min-unbounded-with-exactly-min
    (let ([option (parse '("-f" "a"))])
      (CHECK equal? (option "--files") '("a"))))

  (define-test test-arity-range-lower-bound
    (let ([option (parse '("-r"))])
      (CHECK equal? (option "-r") '())
      (CHECK equal? (option 'number-of-positional-argument) 0)))

  (define-test test-arity-range-middle
    (let ([option (parse '("-r" "1"))])
      (CHECK equal? (option "-r") '(1))))

  (define-test test-arity-range-upper-bound
    (let ([option (parse '("-r" "1" "2"))])
      (CHECK equal? (option "-r") '(1 2))))

  (define-test test-arity-range-stops-at-max
    (let ([option (parse '("-r" "1" "2" "3"))])
      (CHECK equal? (option "-r") '(1 2))
      (CHECK equal? (option 0) "3")))

  (define-test test-arity-zero-unbounded-present-without-arguments
    (let ([option (parse '("-o"))])
      (CHECK equal? (option "-o") '())))

  (define-test test-arity-single-stops-at-max
    (let ([option (parse '("-n" "1" "2"))])
      (CHECK eqv? (option "-n") 1)
      (CHECK equal? (option 0) "2")))

  ;; ========================================
  ;; argument forms
  ;; ========================================

  (define-test test-form-long-space
    (let ([option (parse '("--files" "a" "b"))])
      (CHECK equal? (option "-f") '("a" "b"))))

  (define-test test-form-short-space
    (let ([option (parse '("-f" "a" "b"))])
      (CHECK equal? (option "--files") '("a" "b"))))

  (define-test test-form-long-equals-comma
    (let ([option (parse '("--files=a,b,c"))])
      (CHECK equal? (option "-f") '("a" "b" "c"))))

  (define-test test-form-long-equals-single
    (let ([option (parse '("--count=5"))])
      (CHECK eqv? (option "-n") 5)))

  (define-test test-form-short-equals
    (let ([option (parse '("-f=a,b"))])
      (CHECK equal? (option "-f") '("a" "b"))))

  (define-test test-form-equals-converts-each-item
    (let ([option (parse '("--pair=3,4"))])
      (CHECK equal? (option "-p") '(3 4))))

  (define-test test-form-equals-does-not-consume-next
    (let ([option (parse '("--files=a,b" "pos"))])
      (CHECK equal? (option "-f") '("a" "b"))
      (CHECK equal? (option 0) "pos")))

  (define-test test-form-equals-value-may-start-with-dash
    (let ([option (parse '("--name=-weird"))])
      (CHECK equal? (option "-s") "-weird")))

  (define-test test-form-equals-empty-value
    (let ([option (parse '("--name="))])
      (CHECK equal? (option "-s") "")))

  (define-test test-form-mixed
    (let ([option (parse '("-v" "--count=2" "-f" "a" "b" "-s" "n" "--ratio" "0.5"))])
      (CHECK eq? (option "-v") 'present)
      (CHECK eqv? (option "-n") 2)
      (CHECK equal? (option "-f") '("a" "b"))
      (CHECK equal? (option "-s") "n")
      (CHECK eqv? (option "-x") 0.5)))

  ;; ========================================
  ;; repeated option
  ;; ========================================

  (define-test test-repeated-option-last-wins
    (let ([option (parse '("-n" "1" "-n" "2"))])
      (CHECK eqv? (option "-n") 2))
    (let ([option (parse '("-f" "a" "-f" "b" "c"))])
      (CHECK equal? (option "-f") '("b" "c"))))

  ;; ========================================
  ;; escape with backslash
  ;; ========================================

  (define-test test-escape-dash-argument
    (let ([option (parse '("-s" "\\-x"))])
      (CHECK equal? (option "-s") "-x")))

  (define-test test-escape-double-dash-argument
    (let ([option (parse '("-s" "\\--long"))])
      (CHECK equal? (option "-s") "--long")))

  (define-test test-escape-in-multiple-arguments
    (let ([option (parse '("-f" "a" "\\-b" "\\--c"))])
      (CHECK equal? (option "-f") '("a" "-b" "--c"))))

  (define-test test-escape-positional
    (let ([option (parse '("\\-x" "y"))])
      (CHECK equal? (option 0) "-x")
      (CHECK equal? (option 1) "y")))

  (define-test test-escape-in-equals-form
    (let ([option (parse '("--files=\\-a,b"))])
      (CHECK equal? (option "-f") '("-a" "b"))))

  (define-test test-backslash-not-before-dash-is-kept
    (let ([option (parse '("-s" "a\\-b"))])
      (CHECK equal? (option "-s") "a\\-b"))
    (let ([option (parse '("-s" "\\x"))])
      (CHECK equal? (option "-s") "\\x")))

  (define-test test-lone-dash-is-a-value
    (let ([option (parse '("-s" "-"))])
      (CHECK equal? (option "-s") "-"))
    (let ([option (parse '("-"))])
      (CHECK equal? (option 0) "-")))

  (define-test test-unescaped-dash-argument-is-an-option
    (CHECK equal? (error-message (lambda () (parse '("-s" "-x"))))
           "too few arguments for option"))

  ;; ========================================
  ;; positional arguments
  ;; ========================================

  (define-test test-positional-only
    (let ([option (parse '("a" "b" "c"))])
      (CHECK eqv? (option 'number-of-positional-argument) 3)
      (CHECK equal? (option 0) "a")
      (CHECK equal? (option 1) "b")
      (CHECK equal? (option 2) "c")))

  (define-test test-positional-none
    (let ([option (parse '("-v"))])
      (CHECK eqv? (option 'number-of-positional-argument) 0)))

  (define-test test-positional-after-options
    (let ([option (parse '("-v" "-n" "3" "in.txt" "out.txt"))])
      (CHECK eq? (option "-v") 'present)
      (CHECK eqv? (option "-n") 3)
      (CHECK eqv? (option 'number-of-positional-argument) 2)
      (CHECK equal? (option 0) "in.txt")
      (CHECK equal? (option 1) "out.txt")))

  (define-test test-positional-after-double-dash
    (let ([option (parse '("-v" "--" "a" "b"))])
      (CHECK eq? (option "-v") 'present)
      (CHECK eqv? (option 'number-of-positional-argument) 2)
      (CHECK equal? (option 0) "a")
      (CHECK equal? (option 1) "b")))

  (define-test test-double-dash-terminates-variable-arity
    (let ([option (parse '("-f" "a" "b" "--" "c"))])
      (CHECK equal? (option "-f") '("a" "b"))
      (CHECK equal? (option 0) "c")
      (CHECK eqv? (option 'number-of-positional-argument) 1)))

  (define-test test-double-dash-then-option-like-is-literal
    (let ([option (parse '("--" "-v" "--count" "\\-x"))])
      (CHECK eq? (option "-v") 'absent)
      (CHECK eqv? (option 'number-of-positional-argument) 3)
      (CHECK equal? (option 0) "-v")
      (CHECK equal? (option 1) "--count")
      (CHECK equal? (option 2) "\\-x")))

  (define-test test-double-dash-twice-second-is-literal
    (let ([option (parse '("--" "--" "a"))])
      (CHECK eqv? (option 'number-of-positional-argument) 2)
      (CHECK equal? (option 0) "--")))

  (define-test test-everything-after-first-positional-is-positional
    (let ([option (parse '("a" "-v" "--count" "5"))])
      (CHECK eq? (option "-v") 'absent)
      (CHECK eq? (option "-n") #f)
      (CHECK eqv? (option 'number-of-positional-argument) 4)
      (CHECK equal? (option 1) "-v")))

  (define-test test-positional-index-out-of-range
    (let ([option (parse '("a"))])
      (CHECK equal? (error-message (lambda () (option 1)))
             "positional argument index out of range")
      (CHECK equal? (error-message (lambda () (option -1)))
             "positional argument index out of range")))

  (define-test test-positional-index-with-no-positional
    (let ([option (parse '())])
      (CHECK equal? (error-message (lambda () (option 0)))
             "positional argument index out of range")))

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
    ["-k" :arity 1 :type (lambda (s) (if (string=? s "ok") s (raise 'bad)))])

  (define-test test-error-custom-converter-failure
    (CHECK equal? ((strict '("-k" "ok")) "-k") "ok")
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
      (CHECK equal? (error-message (lambda () (option "-z"))) "unknown option")
      (CHECK equal? (error-message (lambda () (option "--nope"))) "unknown option")
      (CHECK equal? (error-message (lambda () (option 'count))) "unknown option")
      (CHECK equal? (error-message (lambda () (option "count"))) "unknown option")
      (CHECK equal? (error-message (lambda () (option "-h"))) "unknown option")))

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
      (CHECK eqv? (option (sym "-n")) 4)
      (CHECK eqv? (option (sym "--count")) 4)
      (CHECK eq? (option (sym "--verbose")) 'present)
      (CHECK eq? (option (sym "-q")) 'absent)))

  (define-test test-accessor-unknown-symbol-option
    (let ([option (parse '())])
      (CHECK equal? (error-message (lambda () (option (sym "-z")))) "unknown option")))

  (define-test test-definition-accepts-symbols
    (let* ([form `(let ()
                    (define-command-line-options p
                      [,(sym "-a") :long ,(sym "--alpha") :arity 1 :type int])
                    p)]
           [p (eval form (environment '(rnrs (6)) '(rime command-line-options)))]
           [option (p '("--alpha" "5"))])
      (CHECK eqv? (option "-a") 5)
      (CHECK eqv? (option "--alpha") 5)
      (CHECK eqv? (option (sym "-a")) 5)))

  (define-test test-definition-symbol-and-string-conflict-is-duplicate
    (CHECK eq? (syntax-error?
                `(let ()
                   (define-command-line-options p
                     [,(sym "-a")] ["-a"])
                   p))
           #t))

  ;; ========================================
  ;; independent parsers
  ;; ========================================

  (define-test test-two-parse-results-are-independent
    (let ([a (parse '("-n" "1"))]
          [b (parse '("-n" "2" "x"))])
      (CHECK eqv? (a "-n") 1)
      (CHECK eqv? (b "-n") 2)
      (CHECK eqv? (a 'number-of-positional-argument) 0)
      (CHECK eqv? (b 'number-of-positional-argument) 1)))

  (define-command-line-options other
    ["-n" :long "--number" :arity 1 :type string :description "string number"])

  (define-test test-second-definition-is-independent
    (CHECK equal? ((other '("-n" "7")) "--number") "7")
    (CHECK eqv? ((parse '("-n" "7")) "--count") 7))

  ;; ========================================
  ;; defaults in the definition
  ;; ========================================

  (define-command-line-options shuffled
    ["-a" :description "d" :type int :arity 1 :long "--alpha"])
  (define-command-line-options minimal
    ["-m"])
  (define-command-line-options three
    ["-t" :arity 3 :type int])
  (define-command-line-options exactly-one
    ["-e" :arity (1 1) :type int])
  (define-command-line-options flag
    ["-g" :arity (0 0)])
  (define-command-line-options none)

  (define-test test-clause-fields-in-any-order
    (CHECK eqv? ((shuffled '("--alpha" "9")) "-a") 9))

  (define-test test-clause-minimal
    (CHECK equal? ((minimal '("-m" "x")) "-m") "x"))

  (define-test test-arity-shorthand-n
    (CHECK equal? ((three '("-t" "1" "2" "3")) "-t") '(1 2 3)))

  (define-test test-arity-pair-same-min-max-is-exact
    (CHECK eqv? ((exactly-one '("-e" "5")) "-e") 5)
    (CHECK eq? ((exactly-one '()) "-e") #f))

  (define-test test-arity-pair-0-0-is-flag
    (CHECK eq? ((flag '("-g")) "-g") 'present)
    (CHECK eq? ((flag '()) "-g") 'absent))

  (define-test test-no-options-defined
    (let ([option (none '("a" "b"))])
      (CHECK eqv? (option 'number-of-positional-argument) 2)))

  ;; ========================================
  ;; definition errors, detected at expansion time
  ;; ========================================

  (define-test test-syntax-error-type-with-arity-0
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p ["-a" :arity 0 :type int])
                   p))
           #t))

  (define-test test-syntax-error-type-with-implicit-arity-0-pair
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p ["-a" :arity (0 0) :type int])
                   p))
           #t))

  (define-test test-syntax-error-min-greater-than-max
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p ["-a" :arity (3 2)])
                   p))
           #t))

  (define-test test-syntax-error-negative-arity
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p ["-a" :arity -1])
                   p))
           #t))

  (define-test test-syntax-error-bad-arity-form
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p ["-a" :arity (1 2 3)])
                   p))
           #t)
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p ["-a" :arity many])
                   p))
           #t))

  (define-test test-syntax-error-duplicate-short-name
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p ["-a"] ["-a"])
                   p))
           #t))

  (define-test test-syntax-error-duplicate-long-name
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p ["-a" :long "--x"] ["-b" :long "--x"])
                   p))
           #t))

  (define-test test-syntax-error-reserved-help
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p ["-h"])
                   p))
           #t)
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p ["-a" :long "--help"])
                   p))
           #t))

  (define-test test-syntax-error-bad-short-name
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p ["a"])
                   p))
           #t)
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p ["--abc"])
                   p))
           #t))

  (define-test test-syntax-error-bad-long-name
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p ["-a" :long "x"])
                   p))
           #t)
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p ["-a" :long "-x"])
                   p))
           #t))

  (define-test test-syntax-error-unknown-field
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p ["-a" :colour red])
                   p))
           #t))

  (define-test test-syntax-error-field-without-value
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p ["-a" :long])
                   p))
           #t))

  (define-test test-syntax-error-duplicate-field
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p ["-a" :arity 1 :arity 2])
                   p))
           #t))

  (define-test test-syntax-error-description-not-string
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p ["-a" :description 42])
                   p))
           #t))

  (define-test test-syntax-error-option-name-is-not-string-or-symbol
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p [42])
                   p))
           #t)
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p ["-a" :long 42])
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
                   (define-command-line-options "p" ["-a"])
                   1))
           #t))

  (define-test test-valid-definition-is-not-syntax-error
    (CHECK eq? (syntax-error?
                '(let ()
                   (define-command-line-options p ["-a" :long "--alpha" :arity (1 +) :type int])
                   p))
           #f))

  ;; ========================================
  ;; help
  ;; ========================================

  (define (spaces n) (make-string n #\space))

  (define usage-specs
    (list
     (make-option-spec "-v" "--verbose" 0 0 #f convert-string "verbose output")
     (make-option-spec "-n" "--count" 1 1 'int convert-int "repeat count")
     (make-option-spec "-f" "--files" 1 (greatest-fixnum) 'string convert-string "input files")
     (make-option-spec "-r" "--range" 0 2 'int convert-int "range")
     (make-option-spec "-q" #f 0 0 #f convert-string "quiet")
     (make-option-spec "-u" "--upper" 1 1 #f string-upcase "first line\nsecond line")))

  (define-test test-format-usage
    (CHECK string=?
           (format-usage usage-specs "prog")
           (string-append
            "Usage: prog [options] [--] [arguments...]\n"
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
                   (make-option-spec "-a" #f 2 2 'int convert-int "d")
                   (make-option-spec "-b" #f 0 (greatest-fixnum) 'string convert-string "d")
                   (make-option-spec "-c" #f 1 3 'float convert-float "d"))
                  "p")])
      (CHECK eq? (and (contains? usage "-a <int> <int>") #t) #t)
      (CHECK eq? (and (contains? usage "-b [<string>...]") #t) #t)
      (CHECK eq? (and (contains? usage "-c <float> [<float>] [<float>]") #t) #t)))

  (define-test test-format-usage-without-options
    (CHECK string=?
           (format-usage '() "p")
           (string-append
            "Usage: p [options] [--] [arguments...]\n"
            "\n"
            "Options:\n"
            "  -h, --help  show this help message and exit\n")))

  (define-test test-help-short-calls-handler
    (let* ([shown #f]
           [option (parse-command-line usage-specs '("-h")
                                       (lambda (text) (set! shown text)))])
      (CHECK equal? shown (format-usage usage-specs (program-name)))
      (CHECK eqv? (option 'number-of-positional-argument) 0)))

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
      (CHECK equal? (option 0) "-h")))

  (define-test test-help-after-positional-is-positional
    (let* ([shown #f]
           [option (parse-command-line usage-specs '("a" "--help")
                                       (lambda (text) (set! shown text)))])
      (CHECK eq? shown #f)
      (CHECK equal? (option 1) "--help")))

  (define-test test-help-as-option-argument-is-escapable
    (let* ([shown #f]
           [option (parse-command-line usage-specs '("-u" "\\-h")
                                       (lambda (text) (set! shown text)))])
      (CHECK eq? shown #f)
      (CHECK equal? (option "-u") "-H")))

  ;; The real -h path of a macro-defined parser prints usage and calls (exit 0).
  ;; Chez only: exit-handler and current-output-port are intercepted through eval
  ;; (cf. rime/rime-0/__feature-registry.sls); on other implementations the test is skipped.
  (define chez-environment
    (guard (e [else #f]) (environment '(chezscheme))))

  ;; (run-capturing-exit thunk) => (exit-code . printed-text), or #f when not on Chez
  (define run-capturing-exit
    (and chez-environment
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
               chez-environment)))

  (define-command-line-options helpful
    ["-v" :long "--verbose" :arity 0 :description "verbose output"]
    ["-n" :long "--count" :arity 1 :type int :description "repeat count"]
    ["-f" :long "--files" :arity (1 +) :description "input files"])

  (define helpful-usage
    (string-append
     "Usage: " (program-name) " [options] [--] [arguments...]\n"
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
                   (define-command-line-options p ["-h" :long "--help"])
                   p))
           #t))

  (define-test test-program-name-is-a-string
    (CHECK eq? (string? (program-name)) #t))

  ;; ========================================
  ;; converters
  ;; ========================================

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
    (CHECK equal? (convert-string "x y") "x y")))
