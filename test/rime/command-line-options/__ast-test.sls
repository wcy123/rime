#!r6rs
(library (test rime command-line-options __ast-test)
  (export main)
  (import (rnrs (6))
          (rime unit-test)
          (rime command-line-options __ast))

  (define (main)
    (run-all-tests))

  (define (syntax-violation-raised? thunk)
    (guard (e [(syntax-violation? e) #t]
              [else #f])
      (thunk)
      #f))

  ;; names given as symbols, which strict R6RS readers cannot read as literals
  (define (sym s) (string->symbol s))
  (define (clause . datums) (datum->syntax #'here datums))

  (define (parse . datums) (parse-option (apply clause datums)))

  ;; ========================================
  ;; parse-option
  ;; ========================================

  (define-test test-minimal-clause-defaults
    (let ([o (parse "-m")])
      (CHECK equal? (option-ast-short o) "-m")
      (CHECK equal? (option-ast-long o) #f)
      (CHECK equal? (option-ast-min o) 1)
      (CHECK equal? (option-ast-max o) 1)
      (CHECK equal? (option-ast-type o) 'string)
      (CHECK equal? (option-ast-description o) "")))

  (define-test test-full-clause
    (let ([o (parse "-n" '(:long "--count") '(:arity (0 2)) '(:type int) '(:description "repeat"))])
      (CHECK equal? (option-ast-short o) "-n")
      (CHECK equal? (option-ast-long o) "--count")
      (CHECK equal? (option-ast-min o) 0)
      (CHECK equal? (option-ast-max o) 2)
      (CHECK equal? (option-ast-type o) 'int)
      (CHECK equal? (option-ast-description o) "repeat")))

  (define-test test-fields-in-any-order
    (let ([o (parse "-n" '(:description "d") '(:type float) '(:long "--n-long"))])
      (CHECK equal? (option-ast-long o) "--n-long")
      (CHECK equal? (option-ast-type o) 'float)
      (CHECK equal? (option-ast-description o) "d")))

  (define-test test-names-as-symbols
    (let ([o (parse (sym "-a") (list ':long (sym "--alpha")))])
      (CHECK equal? (option-ast-short o) "-a")
      (CHECK equal? (option-ast-long o) "--alpha")))

  (define (min+max . arity)
    (let ([o (apply parse "-a" (if (null? arity) '() (list (list ':arity (car arity)))))])
      (cons (option-ast-min o) (option-ast-max o))))

  (define-test test-arity-forms
    (CHECK equal? (min+max) '(1 . 1))
    (CHECK equal? (min+max 0) '(0 . 0))
    (CHECK equal? (min+max 3) '(3 . 3))
    (CHECK equal? (min+max '(1 2)) '(1 . 2))
    (CHECK equal? (min+max '(2 2)) '(2 . 2))
    (CHECK equal? (min+max '(0 +)) '(0 . #f))
    (CHECK equal? (min+max '(2 +)) '(2 . #f)))

  (define-test test-builtin-types
    (for-each
     (lambda (type)
       (CHECK eq? (option-ast-type (parse "-a" (list ':type type))) type))
     '(string int float bool)))

  (define-test test-custom-type-keeps-its-syntax
    (let ([type (option-ast-type (parse "-a" '(:type (lambda (s) s))))])
      (CHECK eq? (symbol? type) #f)
      (CHECK equal? (syntax->datum type) '(lambda (s) s))))

  (define-test test-type-of-flag-defaults-to-string
    (CHECK eq? (option-ast-type (parse "-a" '(:arity 0))) 'string))

  (define-test test-errors
    (for-each
     (lambda (bad)
       (CHECK eq? (syntax-violation-raised? (lambda () (apply parse bad))) #t))
     (list
      '("a")                                  ; short name without dash
      '("--a")                                ; long name where short is expected
      '("-")                                  ; too short
      '("-a=b")                               ; = in a name
      '("-a b")                               ; whitespace in a name
      '(42)                                   ; not a string or symbol
      '("-a" (:long "x"))                     ; long name without dashes
      '("-a" (:long "-x"))                    ; long name with one dash
      '("-a" (:long "--"))                    ; empty long name
      '("-a" (:long 42))
      '("-a" (:arity -1))
      '("-a" (:arity many))
      '("-a" (:arity (1 2 3)))
      '("-a" (:arity (3 2)))
      '("-a" (:arity (-1 2)))
      '("-a" (:arity 0) (:type int))          ; type on a flag
      '("-a" (:arity (0 0)) (:type int))
      '("-a" (:description 42))
      '("-a" (:colour red))                   ; unknown field
      '("-a" (:arity 1) (:arity 2))           ; duplicate field
      '("-a" (:long "--x") (:long "--y")))))

  ;; ========================================
  ;; check-options
  ;; ========================================

  (define (check . clauses)
    (check-options (map (lambda (c) (apply parse c)) clauses)))

  (define-test test-check-options-accepts-distinct-names
    (check '("-a" (:long "--alpha")) '("-b" (:long "--beta")) '("-c"))
    (check))

  (define-test test-check-options-rejects-duplicate-short
    (CHECK eq? (syntax-violation-raised? (lambda () (check '("-a") '("-a")))) #t))

  (define-test test-check-options-rejects-duplicate-long
    (CHECK eq? (syntax-violation-raised? (lambda () (check '("-a" (:long "--x")) '("-b" (:long "--x"))))) #t))

  (define-test test-check-options-rejects-duplicate-within-mixed-forms
    (CHECK eq? (syntax-violation-raised? (lambda ()
                             (check-options (list (parse (sym "-a")) (parse "-a")))))
           #t))

  (define-test test-check-options-rejects-reserved-help-names
    (CHECK eq? (syntax-violation-raised? (lambda () (check '("-h")))) #t)
    (CHECK eq? (syntax-violation-raised? (lambda () (check '("-a" (:long "--help"))))) #t))

  (define-test test-syntax-list
    (CHECK eqv? (length (syntax-list #'(a b c))) 3)
    (CHECK equal? (syntax-list #'()) '())))
