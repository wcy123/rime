#!r6rs
;; Phase 1: clause syntax -> option-ast. Only the AST is looked at, no code is generated.
(library (test rime command-line-options __parse-test)
  (export main)
  (import (rnrs (6))
          (rime unit-test)
          (rime command-line-options __keywords)
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

  ;; a clause as the user writes it: :key value :key value ...
  ;; `short` becomes the :short field, #f means none; each field is given as a list, (:long "--x");
  ;; the keywords are bound by the import above
  (define (clause short . fields)
    (append (if short (list ':short short) '()) (apply append fields)))

  ;; the syntax of a list of clauses, as define-command-line-options receives them
  (define (clauses . clauses) (datum->syntax #'here clauses))

  ;; the single option of one clause
  (define (parse . datums) (car (parse-options (clauses (apply clause datums)))))

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
      (CHECK equal? (option-ast-converter o) #f)
      (CHECK equal? (option-ast-description o) "")))

  (define-test test-full-clause
    (let ([o (parse "-n" '(:long "--count") '(:arity (0 2)) '(:type int) '(:description "repeat"))])
      (CHECK equal? (option-ast-short o) "-n")
      (CHECK equal? (option-ast-long o) "--count")
      (CHECK equal? (option-ast-min o) 0)
      (CHECK equal? (option-ast-max o) 2)
      (CHECK equal? (syntax->datum (option-ast-converter o)) '(builtin-converter 'int))
      (CHECK equal? (option-ast-description o) "repeat")))

  (define-test test-fields-in-any-order
    (let ([o (parse "-n" '(:description "d") '(:type float) '(:long "--n-long"))])
      (CHECK equal? (option-ast-long o) "--n-long")
      (CHECK equal? (syntax->datum (option-ast-converter o)) '(builtin-converter 'float))
      (CHECK equal? (option-ast-description o) "d")))

  (define-test test-short-only
    (let ([o (parse "-a")])
      (CHECK equal? (option-ast-short o) "-a")
      (CHECK equal? (option-ast-long o) #f)))

  (define-test test-long-only
    (let ([o (parse #f '(:long "--alpha"))])
      (CHECK equal? (option-ast-short o) #f)
      (CHECK equal? (option-ast-long o) "--alpha")))

  (define-test test-short-and-long-given-in-either-order
    (let ([a (parse "-a" '(:long "--alpha"))]
          [b (parse-options (clauses '(:long "--alpha" :short "-a")))])
      (CHECK equal? (option-ast-short a) "-a")
      (CHECK equal? (option-ast-long a) "--alpha")
      (CHECK equal? (option-ast-short (car b)) "-a")
      (CHECK equal? (option-ast-long (car b)) "--alpha")))

  (define-test test-no-name-at-all-is-a-violation
    (CHECK eq? (parse-fails? #f) #t)
    (CHECK eq? (parse-fails? #f '(:arity 0)) #t)
    (CHECK eq? (parse-fails? #f '(:description "d")) #t))

  (define-test test-short-and-long-fields-are-checked
    (CHECK eq? (parse-fails? #f '(:short 42)) #t)
    (CHECK eq? (parse-fails? #f '(:short "x")) #t)
    (CHECK eq? (parse-fails? "-a" '(:short "-b")) #t)
    (CHECK eq? (parse-fails? #f '(:long "--a") '(:long "--b")) #t))

  (define-test test-options-with-only-a-long-name-may-share-nothing
    (CHECK eq? (raises-syntax-violation?
                (lambda () (parse-options (clauses (clause #f '(:long "--x"))
                                                   (clause #f '(:long "--x"))))))
           #t)
    (CHECK equal? (map option-ast-long
                       (parse-options (clauses (clause #f '(:long "--x")) (clause #f '(:long "--y")))))
           '("--x" "--y")))

  (define-test test-names-as-symbols
    (let ([o (parse (sym "-a") (list ':long (sym "--alpha")))])
      (CHECK equal? (option-ast-short o) "-a")
      (CHECK equal? (option-ast-long o) "--alpha")))

  (define-test test-source-is-the-clause
    (let ([o (parse "-a" '(:arity 2))])
      (CHECK equal? (syntax->datum (option-ast-source o)) '(:short "-a" :arity 2))))

  (define (min+max . arity)
    (let ([o (apply parse "-a" (if (null? arity) '() (list (list ':arity (car arity)))))])
      (cons (option-ast-min o) (option-ast-max o))))

  (define-test test-arity-forms
    (CHECK equal? (min+max) '(1 . 1))
    (CHECK equal? (min+max 0) '(0 . 0))
    (CHECK equal? (min+max 3) '(3 . 3))
    (CHECK equal? (min+max '(1 2)) '(1 . 2))
    (CHECK equal? (min+max '(2 2)) '(2 . 2))
    (CHECK equal? (min+max '(0 +)) (cons 0 unlimited))
    (CHECK equal? (min+max '(2 +)) (cons 2 unlimited)))

  (define-test test-builtin-types-become-a-lookup-of-the-converter
    (for-each
     (lambda (type)
       (let ([o (parse "-a" (list ':type type))])
         (CHECK equal? (syntax->datum (option-ast-converter o))
                (list 'builtin-converter (list 'quote type)))))
     '(string int float bool)))

  (define-test test-custom-converter-keeps-its-expression
    (let ([o (parse "-a" '(:type (lambda (s) s)))])
      (CHECK equal? (syntax->datum (option-ast-converter o))
           '(procedure->converter (lambda (s) s)))))

  (define-test test-custom-converter-may-be-an-identifier
    (let ([o (parse "-a" '(:type string-upcase))])
      ;; the identifier as it is, not a lookup by name: only string int float bool are builtin
      (CHECK equal? (syntax->datum (option-ast-converter o))
             '(procedure->converter string-upcase))))

  ;; ========================================
  ;; :choices
  ;; ========================================

  (define (choice-converter-of . choices)
    (syntax->datum (option-ast-converter (apply parse "-a" choices))))

  (define-test test-choices-set-a-choice-converter
    (CHECK equal? (choice-converter-of '(:choices ("json" "text")))
           '(make-choice-converter '("json" "text")))
    (CHECK equal? (choice-converter-of '(:choices ("only")))
           '(make-choice-converter '("only"))))

  (define-test test-choices-may-be-integers-or-a-mix
    (CHECK equal? (choice-converter-of '(:choices (1 2 4)))
           '(make-choice-converter '(1 2 4)))
    (CHECK equal? (choice-converter-of '(:choices ("auto" 1 -2)))
           '(make-choice-converter '("auto" 1 -2))))

  (define-test test-choices-keep-their-order
    (CHECK equal? (choice-converter-of '(:choices ("c" "a" "b")))
           '(make-choice-converter '("c" "a" "b"))))

  (define-test test-choices-are-the-only-converter-field
    ;; there is no second field: the converter is the one place that says how an argument is read
    (let ([o (parse "-a" '(:choices ("x" "y")) '(:description "d"))])
      (CHECK equal? (option-ast-description o) "d")
      (CHECK equal? (option-ast-min o) 1)))

  (define-test test-choices-must-be-a-non-empty-list-of-strings-or-integers
    (for-each
     (lambda (bad)
       (CHECK eq? (parse-fails? "-a" (list ':choices bad)) #t))
     (list "json"            ; not a list
           '()               ; empty
           '(json)           ; a symbol
           '(1.5)            ; not an integer
           '(1.0)            ; an integer, but not an exact one
           '(1/2)            ; not an integer
           '(#\a)            ; a character
           '(("a"))          ; a list in the list
           '("a" json)       ; one bad literal among good ones
           '("a" . "b")      ; improper list
           42)))

  (define-test test-choices-must-not-repeat
    (CHECK eq? (parse-fails? "-a" '(:choices ("a" "b" "a"))) #t)
    (CHECK eq? (parse-fails? "-a" '(:choices (1 2 1))) #t))

  (define-test test-choices-that-match-the-same-text-are-duplicates
    ;; "1" and 1 are different literals, but the argument 1 would match both: the second is unreachable
    (CHECK eq? (parse-fails? "-a" '(:choices ("1" 1))) #t)
    (CHECK eq? (parse-fails? "-a" '(:choices (7 "7"))) #t)
    (CHECK equal? (choice-converter-of '(:choices ("1" 2)))
           '(make-choice-converter '("1" 2))))

  (define (violation-message thunk)
    (guard (e [(syntax-violation? e) (condition-message e)]
              [else #f])
      (thunk)
      #f))

  (define-test test-choices-and-type-both-set-the-converter
    (let ([message "the converter is given twice, use only one of :type and :choices"])
      (CHECK equal? (violation-message (lambda () (parse "-a" '(:type int) '(:choices ("a")))))
             message)
      (CHECK equal? (violation-message (lambda () (parse "-a" '(:choices ("a")) '(:type int))))
             message)))

  (define-test test-choices-twice-is-a-duplicate
    (CHECK eq? (parse-fails? "-a" '(:choices ("a")) '(:choices ("b"))) #t))

  (define-test test-choices-on-a-flag-is-a-violation
    (CHECK eq? (parse-fails? "-a" '(:arity 0) '(:choices ("a"))) #t)
    (CHECK eq? (parse-fails? "-a" '(:arity (0 0)) '(:choices ("a"))) #t))

  (define-test test-choices-are-fine-with-other-arities
    (CHECK eq? (parse-fails? "-a" '(:arity (1 +)) '(:choices ("a" "b"))) #f)
    (CHECK eq? (parse-fails? "-a" '(:arity (0 2)) '(:choices ("a" "b"))) #f))

  (define-test test-flag-has-no-converter
    (CHECK eq? (option-ast-converter (parse "-a" '(:arity 0))) #f))

  (define-test test-several-clauses-keep-their-order
    (let ([options (parse-options (clauses (clause "-a") (clause "-b") (clause "-c")))])
      (CHECK equal? (map option-ast-short options) '("-a" "-b" "-c"))))

  (define-test test-no-clauses
    (CHECK equal? (parse-options (clauses)) '()))

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
     '(-1 many (1 2 3) (1) () (-1 2) (1 -2) (1 many) 1.5 (+ 1) (+ +) (1 . 2) +)))

  (define-test test-description-must-be-a-string
    (CHECK eq? (parse-fails? "-a" '(:description 42)) #t)
    (CHECK eq? (parse-fails? "-a" '(:description desc)) #t))

  (define-test test-unknown-field
    (CHECK eq? (parse-fails? "-a" '(:colour red)) #t))

  (define-test test-field-without-a-value
    (CHECK eq? (parse-fails? "-a" '(:long)) #t)
    (CHECK eq? (parse-fails? "-a" '(:arity 1) '(:type)) #t))

  (define-test test-something-that-is-not-a-keyword-in-field-position
    (CHECK eq? (raises-syntax-violation?
                (lambda () (parse-options (clauses '(:short "-a" 42)))))
           #t)
    (CHECK eq? (raises-syntax-violation?
                (lambda () (parse-options (clauses '(:short "-a" "--long" "--x")))))
           #t))

  (define-test test-improper-clause-or-fields
    ;; the tail of the clause is not a list of fields
    (CHECK eq? (raises-syntax-violation?
                (lambda () (parse-options (clauses (cons ':short (cons "-a" 5))))))
           #t)
    (CHECK eq? (raises-syntax-violation?
                (lambda () (parse-options (clauses (cons ':short (cons "-a" (cons ':long 5)))))))
           #t))

  (define-test test-duplicate-field-is-reported-whatever-the-order
    (CHECK eq? (parse-fails? "-a" '(:long "--x") '(:arity 1) '(:long "--y")) #t)
    (CHECK eq? (parse-fails? "-a" '(:description "d") '(:type int) '(:description "e")) #t))

  (define-test test-arity-forms-with-a-literal-plus
    (CHECK equal? (min+max '(0 +)) (cons 0 unlimited))
    (CHECK equal? (min+max '(10 +)) (cons 10 unlimited))
    (CHECK equal? (min+max '(0 0)) '(0 . 0)))

  (define-test test-clause-must-be-a-list-of-fields
    (CHECK eq? (raises-syntax-violation? (lambda () (parse-options (clauses "-a")))) #t)
    (CHECK eq? (raises-syntax-violation? (lambda () (parse-options (clauses 42)))) #t))

  (define-test test-empty-clause-has-no-name
    (CHECK eq? (raises-syntax-violation? (lambda () (parse-options (clauses '())))) #t))

  (define-test test-old-syntax-with-a-leading-name-is-rejected
    ;; ["-n" :long "--count"]: the name must be given with :short
    (CHECK eq? (raises-syntax-violation?
                (lambda () (parse-options (clauses '("-n" :long "--count")))))
           #t))

  (define-test test-a-keyword-given-as-a-value-is-just-a-value
    ;; :long takes the next word, :arity, as its value, and that is not a valid long name
    (CHECK eq? (parse-fails? "-a" '(:long :arity) '(:arity 1)) #t))

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
                (lambda () (parse-options (clauses (clause "-a") (clause "-a")))))
           #t)
    (CHECK eq? (raises-syntax-violation?
                (lambda () (parse-options (clauses (clause (sym "-a")) (clause "-a")))))
           #t)
    (CHECK eq? (raises-syntax-violation?
                (lambda () (parse-options (clauses (clause "-a" '(:long "--x"))
                                                   (clause "-b" '(:long "--x"))))))
           #t))

  (define-test test-violation-points-at-the-clause
    (guard (e [(syntax-violation? e)
               (CHECK equal? (syntax->datum (syntax-violation-form e)) '(:short "-a" :arity (3 2)))])
      (parse "-a" '(:arity (3 2)))
      (assert #f))))
