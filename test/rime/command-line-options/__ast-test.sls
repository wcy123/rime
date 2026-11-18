#!r6rs
;; The semantic rules for options, on records built by hand: no syntax involved.
(library (test rime command-line-options __ast-test)
  (export main)
  (import (rnrs (6))
          (rime unit-test)
          (rime command-line-options __ast))

  (define (main)
    (run-all-tests))

  ;; an option with the given parts, `tag` stands for its source
  (define (opt tag short long min max type)
    (make-option-ast short long min max type #f "" tag))

  ;; list of (message . tag), one per broken rule
  (define (problems . options)
    (let ([found '()])
      (check-options options
                     (lambda (message option)
                       (set! found (cons (cons message (option-ast-source option)) found))))
      (reverse found)))

  (define short-message "option name must look like \"-x\"")
  (define long-message ":long name must look like \"--name\"")
  (define arity-message "arity min must not exceed max")
  (define flag-message ":type must not be given when arity is 0")
  (define twice-message "option name is defined twice")
  (define reserved-message "-h and --help are reserved for the built-in help")

  (define-test test-record-fields
    (let ([o (make-option-ast "-n" "--count" 0 2 'int #f "repeat" 'src)])
      (CHECK equal? (option-ast-short o) "-n")
      (CHECK equal? (option-ast-long o) "--count")
      (CHECK equal? (option-ast-min o) 0)
      (CHECK equal? (option-ast-max o) 2)
      (CHECK equal? (option-ast-type o) 'int)
      (CHECK equal? (option-ast-converter o) #f)
      (CHECK equal? (option-ast-description o) "repeat")
      (CHECK equal? (option-ast-source o) 'src)))

  (define-test test-valid-options
    (CHECK equal? (problems) '())
    (CHECK equal? (problems (opt 'a "-a" #f 1 1 #f)) '())
    (CHECK equal? (problems (opt 'a "-a" "--alpha" 0 0 #f)
                            (opt 'b "-b" "--beta" 1 1 'int)
                            (opt 'c "-c" #f 0 #f 'custom)
                            (opt 'd "-dd" #f 2 5 'bool))
           '()))

  ;; ========================================
  ;; names
  ;; ========================================

  (define-test test-short-name-rules
    (for-each
     (lambda (bad)
       (CHECK equal? (problems (opt 'a bad #f 1 1 #f)) (list (cons short-message 'a))))
     '("a" "--a" "-" "" "-a=b" "-a,b" "-a b"))
    (CHECK equal? (problems (opt 'a "-ab" #f 1 1 #f)) '()))

  (define-test test-long-name-rules
    (for-each
     (lambda (bad)
       (CHECK equal? (problems (opt 'a "-a" bad 1 1 #f)) (list (cons long-message 'a))))
     '("x" "-x" "--" "---x" "--a=b" "--a,b" "--a b"))
    (CHECK equal? (problems (opt 'a "-a" "--a-b-c" 1 1 #f)) '()))

  (define-test test-long-name-is-optional
    (CHECK equal? (problems (opt 'a "-a" #f 1 1 #f)) '()))

  ;; ========================================
  ;; arity and type
  ;; ========================================

  (define-test test-arity-min-must-not-exceed-max
    (CHECK equal? (problems (opt 'a "-a" #f 3 2 #f)) (list (cons arity-message 'a)))
    (CHECK equal? (problems (opt 'a "-a" #f 2 2 #f)) '())
    (CHECK equal? (problems (opt 'a "-a" #f 2 3 #f)) '())
    (CHECK equal? (problems (opt 'a "-a" #f 9 #f #f)) '()))

  (define-test test-flag-must-not-have-a-type
    (for-each
     (lambda (type)
       (CHECK equal? (problems (opt 'a "-a" #f 0 0 type)) (list (cons flag-message 'a))))
     '(string int float bool custom))
    (CHECK equal? (problems (opt 'a "-a" #f 0 0 #f)) '()))

  (define-test test-type-is-fine-when-not-a-flag
    (for-each
     (lambda (type)
       (CHECK equal? (problems (opt 'a "-a" #f 1 1 type)) '())
       (CHECK equal? (problems (opt 'a "-a" #f 0 1 type)) '())
       (CHECK equal? (problems (opt 'a "-a" #f 0 #f type)) '()))
     '(string int float bool custom)))

  ;; ========================================
  ;; across options
  ;; ========================================

  (define-test test-duplicate-short-name
    (CHECK equal? (problems (opt 'a "-a" #f 1 1 #f) (opt 'b "-a" #f 1 1 #f))
           (list (cons twice-message 'b))))

  (define-test test-duplicate-long-name
    (CHECK equal? (problems (opt 'a "-a" "--x" 1 1 #f) (opt 'b "-b" "--x" 1 1 #f))
           (list (cons twice-message 'b))))

  (define-test test-short-and-long-names-do-not-clash-with-each-other
    (CHECK equal? (problems (opt 'a "-a" "--a" 1 1 #f) (opt 'b "-b" "--b" 1 1 #f)) '()))

  (define-test test-reserved-help-names
    (CHECK equal? (problems (opt 'a "-h" #f 1 1 #f)) (list (cons reserved-message 'a)))
    (CHECK equal? (problems (opt 'a "-a" "--help" 1 1 #f)) (list (cons reserved-message 'a))))

  (define-test test-every-broken-rule-is-reported-for-its-option
    (CHECK equal? (problems (opt 'a "a" #f 3 2 #f)
                            (opt 'b "-b" #f 0 0 'int)
                            (opt 'c "-b" #f 1 1 #f))
           (list (cons short-message 'a)
                 (cons arity-message 'a)
                 (cons flag-message 'b)
                 (cons twice-message 'c)))))
