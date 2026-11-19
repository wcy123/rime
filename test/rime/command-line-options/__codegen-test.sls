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

  (define (opt short long min max converter description)
    (make-option-ast short long min max converter description #f))

  ;; the generated definition, as a datum
  (define (generate parser . options)
    (syntax->datum (generate-definition parser options #f)))

  ;; what the definition looks like around the list of specs
  (define (definition parser . specs)
    (definition* #f parser specs))

  (define (definition* intermixed? parser specs)
    `(define ,parser
       (let ([specs (list ,@specs)])
         (lambda (arguments)
           (parse-command-line specs arguments default-on-help ,intermixed?)))))

  (define-test test-intermixed-is-passed-to-the-runtime
    (CHECK equal?
           (syntax->datum (generate-definition #'p (list (opt "-a" #f 1 1 #f "")) #t))
           (definition* #t 'p '((make-option-ast "-a" #f 1 1 #f "" #f)))))

  (define-test test-no-options
    (CHECK equal? (generate #'parser) (definition 'parser)))

  (define-test test-the-defined-name-is-the-given-identifier
    (CHECK equal? (generate #'my-parser) (definition 'my-parser)))

  (define-test test-short-and-long-name-description
    (CHECK equal?
           (generate #'p (opt "-n" "--count" 1 1 #'(builtin-converter 'int) "repeat count"))
           (definition 'p '(make-option-ast "-n" "--count" 1 1 (builtin-converter 'int) "repeat count" #f))))

  (define-test test-missing-long-name
    (CHECK equal?
           (generate #'p (opt "-n" #f 1 1 #'(builtin-converter 'int) ""))
           (definition 'p '(make-option-ast "-n" #f 1 1 (builtin-converter 'int) "" #f))))

  (define-test test-long-name-only
    (CHECK equal?
           (generate #'p (opt #f "--count" 1 1 #'(builtin-converter 'int) ""))
           (definition 'p '(make-option-ast #f "--count" 1 1 (builtin-converter 'int) "" #f))))

  (define-test test-short-name-only-and-both
    (CHECK equal?
           (generate #'p (opt "-a" #f 1 1 #f "") (opt "-b" "--beta" 1 1 #f ""))
           (definition 'p
             '(make-option-ast "-a" #f 1 1 #f "" #f)
             '(make-option-ast "-b" "--beta" 1 1 #f "" #f))))

  (define-test test-the-converter-expression-is-emitted-as-is
    (for-each
     (lambda (expression)
       (CHECK equal?
              (generate #'p (opt "-a" #f 1 1 (datum->syntax #'here expression) ""))
              (definition 'p `(make-option-ast "-a" #f 1 1 ,expression "" #f))))
     '((builtin-converter 'int)
       (builtin-converter 'bool)
       string-upcase
       (lambda (s) (string-upcase s)))))

  (define-test test-no-converter-means-the-text-as-it-is
    (CHECK equal?
           (generate #'p (opt "-a" #f 1 1 #f ""))
           (definition 'p '(make-option-ast "-a" #f 1 1 #f "" #f))))

  (define-test test-flag
    (CHECK equal?
           (generate #'p (opt "-v" "--verbose" 0 0 #f "verbose"))
           (definition 'p '(make-option-ast "-v" "--verbose" 0 0 #f "verbose" #f))))

  (define-test test-custom-type-uses-the-given-expression
    (CHECK equal?
           (generate #'p (opt "-a" #f 1 1 #'(lambda (s) (string-upcase s)) ""))
           (definition 'p '(make-option-ast "-a" #f 1 1 (lambda (s) (string-upcase s)) "" #f))))

  (define-test test-bounded-and-unbounded-arity
    (CHECK equal?
           (generate #'p (opt "-a" #f 0 2 #f "") (opt "-b" #f 1 unlimited #f ""))
           (definition 'p
             '(make-option-ast "-a" #f 0 2 #f "" #f)
             `(make-option-ast "-b" #f 1 ,unlimited #f "" #f))))

  (define-test test-options-keep-their-order
    (CHECK equal?
           (generate #'p
                     (opt "-c" #f 1 1 #f "")
                     (opt "-a" #f 1 1 #f "")
                     (opt "-b" #f 1 1 #f ""))
           (definition 'p
             '(make-option-ast "-c" #f 1 1 #f "" #f)
             '(make-option-ast "-a" #f 1 1 #f "" #f)
             '(make-option-ast "-b" #f 1 1 #f "" #f))))

  (define-test test-the-source-is-not-needed
    (CHECK eq? (pair? (generate #'p (make-option-ast "-a" #f 1 1 #f "" 'anything))) #t)))
