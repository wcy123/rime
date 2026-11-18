#!r6rs
;; Phase 1: clause syntax -> option-ast. Only the AST is looked at, no code is generated.
(library (test rime command-line-options __parse-test)
  (export main)
  (import (rnrs (6))
          (rime unit-test)
          (rime command-line-options __ast)
          (rime command-line-options __parse))

  (define (main)
    (run-all-tests))

  (define (raises-syntax-violation? thunk)
    (guard (e [(syntax-violation? e) #t]
              [else #f])
      (thunk)
      #f))

  ;; names given as symbols, which strict R6RS readers cannot read as literals
  (define (sym s) (string->symbol s))

  (define (clause . datums) (datum->syntax #'here datums))

  ;; the single option of one clause
  (define (parse . datums) (car (parse-options (list (apply clause datums)))))

  (define (parse-fails? . datums)
    (raises-syntax-violation? (lambda () (apply parse datums))))

  ;; ========================================
  ;; what a clause means
  ;; ========================================

  (define-test test-minimal-clause-defaults
    (let ([o (parse "-m")])
      (CHECK equal? (option-ast-short o) "-m")
      (CHECK equal? (option-ast-long o) #f)
      (CHECK equal? (option-ast-min o) 1)
      (CHECK equal? (option-ast-max o) 1)
      (CHECK equal? (option-ast-type o) #f)
      (CHECK equal? (option-ast-converter o) #f)
      (CHECK equal? (option-ast-description o) "")))

  (define-test test-full-clause
    (let ([o (parse "-n" '(:long "--count") '(:arity (0 2)) '(:type int) '(:description "repeat"))])
      (CHECK equal? (option-ast-short o) "-n")
      (CHECK equal? (option-ast-long o) "--count")
      (CHECK equal? (option-ast-min o) 0)
      (CHECK equal? (option-ast-max o) 2)
      (CHECK equal? (option-ast-type o) 'int)
      (CHECK equal? (option-ast-converter o) #f)
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

  (define-test test-source-is-the-clause
    (let ([o (parse "-a" '(:arity 2))])
      (CHECK equal? (syntax->datum (option-ast-source o)) '("-a" (:arity 2)))))

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
       (let ([o (parse "-a" (list ':type type))])
         (CHECK eq? (option-ast-type o) type)
         (CHECK eq? (option-ast-converter o) #f)))
     '(string int float bool)))

  (define-test test-custom-type-keeps-its-expression
    (let ([o (parse "-a" '(:type (lambda (s) s)))])
      (CHECK eq? (option-ast-type o) 'custom)
      (CHECK equal? (syntax->datum (option-ast-converter o)) '(lambda (s) s))))

  (define-test test-custom-type-may-be-an-identifier
    (let ([o (parse "-a" '(:type string-upcase))])
      (CHECK eq? (option-ast-type o) 'custom)
      (CHECK equal? (syntax->datum (option-ast-converter o)) 'string-upcase)))

  (define-test test-flag-has-no-type
    (CHECK eq? (option-ast-type (parse "-a" '(:arity 0))) #f))

  (define-test test-several-clauses-keep-their-order
    (let ([options (parse-options (list (clause "-a") (clause "-b") (clause "-c")))])
      (CHECK equal? (map option-ast-short options) '("-a" "-b" "-c"))))

  (define-test test-no-clauses
    (CHECK equal? (parse-options '()) '()))

  ;; ========================================
  ;; what is not a well formed clause
  ;; ========================================

  (define-test test-name-must-be-a-string-or-a-symbol
    (CHECK eq? (parse-fails? 42) #t)
    (CHECK eq? (parse-fails? '(a)) #t)
    (CHECK eq? (parse-fails? "-a" '(:long 42)) #t))

  (define-test test-arity-shapes
    (for-each
     (lambda (bad)
       (CHECK eq? (parse-fails? "-a" (list ':arity bad)) #t))
     '(-1 many (1 2 3) (1) () (-1 2) (1 -2) (1 many) 1.5)))

  (define-test test-description-must-be-a-string
    (CHECK eq? (parse-fails? "-a" '(:description 42)) #t)
    (CHECK eq? (parse-fails? "-a" '(:description desc)) #t))

  (define-test test-unknown-field
    (CHECK eq? (parse-fails? "-a" '(:colour red)) #t))

  (define-test test-duplicate-field
    (CHECK eq? (parse-fails? "-a" '(:arity 1) '(:arity 2)) #t)
    (CHECK eq? (parse-fails? "-a" '(:long "--x") '(:long "--y")) #t)
    (CHECK eq? (parse-fails? "-a" '(:type int) '(:type bool)) #t)
    (CHECK eq? (parse-fails? "-a" '(:description "a") '(:description "b")) #t))

  ;; ========================================
  ;; semantic errors are reported through the syntax
  ;; ========================================

  (define-test test-semantic-rules-surface-as-syntax-violations
    (CHECK eq? (parse-fails? "-a" '(:arity (3 2))) #t)
    (CHECK eq? (parse-fails? "a") #t)
    (CHECK eq? (parse-fails? "-a" '(:long "x")) #t)
    (CHECK eq? (parse-fails? "-a" '(:arity 0) '(:type int)) #t)
    (CHECK eq? (parse-fails? "-h") #t)
    (CHECK eq? (parse-fails? "-a" '(:long "--help")) #t))

  (define-test test-duplicates-across-clauses
    (CHECK eq? (raises-syntax-violation?
                (lambda () (parse-options (list (clause "-a") (clause "-a")))))
           #t)
    (CHECK eq? (raises-syntax-violation?
                (lambda () (parse-options (list (clause (sym "-a")) (clause "-a")))))
           #t)
    (CHECK eq? (raises-syntax-violation?
                (lambda () (parse-options (list (clause "-a" '(:long "--x"))
                                                (clause "-b" '(:long "--x"))))))
           #t))

  (define-test test-violation-points-at-the-clause
    (guard (e [(syntax-violation? e)
               (CHECK equal? (syntax->datum (syntax-violation-form e)) '("-a" (:arity (3 2))))])
      (parse "-a" '(:arity (3 2)))
      (assert #f)))

  ;; ========================================
  ;; syntax-list
  ;; ========================================

  (define-test test-syntax-list
    (CHECK eqv? (length (syntax-list #'(a b c))) 3)
    (CHECK equal? (syntax-list #'()) '())))
