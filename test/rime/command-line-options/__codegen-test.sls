#!r6rs
;; Phase 2: option-ast -> code. The records are built by hand, no syntax is parsed.
(library (test rime command-line-options __codegen-test)
  (export main)
  (import (rnrs (6))
          (rime unit-test)
          (rime command-line-options __ast)
          (rime command-line-options __codegen))

  (define (main)
    (run-all-tests))

  (define (opt short long min max type converter description)
    (make-option-ast short long min max type converter description #f))

  ;; the generated definition, as a datum
  (define (generate parser . options)
    (syntax->datum (generate-definition parser options)))

  ;; what the definition looks like around the list of specs
  (define (definition parser . specs)
    `(define ,parser
       (let ([specs (list ,@specs)])
         (lambda (arguments)
           (parse-command-line specs arguments)))))

  (define-test test-no-options
    (CHECK equal? (generate #'parser) (definition 'parser)))

  (define-test test-the-defined-name-is-the-given-identifier
    (CHECK equal? (generate #'my-parser) (definition 'my-parser)))

  (define-test test-short-and-long-name-description
    (CHECK equal?
           (generate #'p (opt "-n" "--count" 1 1 'int #f "repeat count"))
           (definition 'p '(make-option-spec "-n" "--count" 1 1 'int convert-int "repeat count"))))

  (define-test test-missing-long-name
    (CHECK equal?
           (generate #'p (opt "-n" #f 1 1 'int #f ""))
           (definition 'p '(make-option-spec "-n" #f 1 1 'int convert-int ""))))

  (define-test test-converters-of-builtin-types
    (for-each
     (lambda (pair)
       (CHECK equal?
              (generate #'p (opt "-a" #f 1 1 (car pair) #f ""))
              (definition 'p `(make-option-spec "-a" #f 1 1 ',(car pair) ,(cdr pair) ""))))
     '((string . convert-string)
       (int . convert-int)
       (float . convert-float)
       (bool . convert-bool))))

  (define-test test-no-type-means-string
    (CHECK equal?
           (generate #'p (opt "-a" #f 1 1 #f #f ""))
           (definition 'p '(make-option-spec "-a" #f 1 1 'string convert-string ""))))

  (define-test test-flag
    (CHECK equal?
           (generate #'p (opt "-v" "--verbose" 0 0 #f #f "verbose"))
           (definition 'p '(make-option-spec "-v" "--verbose" 0 0 'string convert-string "verbose"))))

  (define-test test-custom-type-uses-the-given-expression
    (CHECK equal?
           (generate #'p (opt "-a" #f 1 1 'custom #'(lambda (s) (string-upcase s)) ""))
           (definition 'p '(make-option-spec "-a" #f 1 1 '#f (lambda (s) (string-upcase s)) ""))))

  (define-test test-bounded-and-unbounded-arity
    (CHECK equal?
           (generate #'p (opt "-a" #f 0 2 #f #f "") (opt "-b" #f 1 #f #f #f ""))
           (definition 'p
             '(make-option-spec "-a" #f 0 2 'string convert-string "")
             '(make-option-spec "-b" #f 1 (greatest-fixnum) 'string convert-string ""))))

  (define-test test-options-keep-their-order
    (CHECK equal?
           (generate #'p
                     (opt "-c" #f 1 1 #f #f "")
                     (opt "-a" #f 1 1 #f #f "")
                     (opt "-b" #f 1 1 #f #f ""))
           (definition 'p
             '(make-option-spec "-c" #f 1 1 'string convert-string "")
             '(make-option-spec "-a" #f 1 1 'string convert-string "")
             '(make-option-spec "-b" #f 1 1 'string convert-string ""))))

  (define-test test-the-source-is-not-needed
    (CHECK eq? (pair? (generate #'p (make-option-ast "-a" #f 1 1 #f #f "" 'anything))) #t)))
