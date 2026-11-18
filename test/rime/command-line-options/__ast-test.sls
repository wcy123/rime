#!r6rs
;; The semantic rules for options, on records built by hand: no syntax involved.
(library (test rime command-line-options __ast-test)
  (export main)
  (import (rnrs (6))
          (rnrs eval (6))
          (rime unit-test)
          (rime command-line-options __ast))

  (define (main)
    (run-all-tests))

  ;; an option with the given parts, `tag` stands for its source
  (define (opt tag short long min max type)
    (make-option-ast short long min max type "" tag))

  ;; the on-duplicate of a field that must not be given twice
  (define (never) (error 'test "field given twice"))

  (define (range n)
    (let loop ([i (- n 1)] [acc '()])
      (if (< i 0) acc (loop (- i 1) (cons i acc)))))

  ;; list of (message . tag), one per broken rule
  (define (problems . options)
    (let ([found '()])
      (check-options options
                     (lambda (message option)
                       (set! found (cons (cons message (option-ast-source option)) found))))
      (reverse found)))

  (define short-message ":short name must look like \"-x\"")
  (define no-name-message "an option needs a :short or a :long name")
  (define long-message ":long name must look like \"--name\"")
  (define arity-message "arity min must not exceed max")
  (define flag-message ":type must not be given when arity is 0")
  (define twice-message "option name is defined twice")
  (define reserved-message "-h and --help are reserved for the built-in help")

  (define-test test-record-fields
    (let ([o (make-option-ast "-n" "--count" 0 2 'int "repeat" 'src)])
      (CHECK equal? (option-ast-short o) "-n")
      (CHECK equal? (option-ast-long o) "--count")
      (CHECK equal? (option-ast-min o) 0)
      (CHECK equal? (option-ast-max o) 2)
      (CHECK equal? (option-ast-converter o) 'int)
      (CHECK equal? (option-ast-description o) "repeat")
      (CHECK equal? (option-ast-source o) 'src)))

  ;; ========================================
  ;; the unbound state, while a clause is being read
  ;; ========================================

  (define (all-fields option)
    (list (option-ast-short option) (option-ast-long option) (option-ast-min option) (option-ast-max option)
          (option-ast-converter option) (option-ast-description option)))

  (define-test test-unbound-is-not-a-value
    (CHECK eq? (unbound? unbound) #t)
    (for-each
     (lambda (value) (CHECK eq? (unbound? value) #f))
     (list #f '() 0 "" 'unbound '(unbound))))

  (define-test test-a-new-option-only-has-its-source
    (let ([o (make-unbound-option-ast 'src)])
      (CHECK equal? (option-ast-source o) 'src)
      (CHECK equal? (map unbound? (all-fields o)) '(#t #t #t #t #t #t))))

  (define-test test-fields-are-set-in-place
    (let ([o (make-unbound-option-ast 'src)])
      (option-ast-short-set-if-not-given-yet! o "-n" never)
      (option-ast-long-set-if-not-given-yet! o "--count" never)
      (option-ast-min-set-if-not-given-yet! o 0 never)
      (option-ast-max-set-if-not-given-yet! o unlimited never)
      (option-ast-converter-set-if-not-given-yet! o 'expr never)
      (option-ast-description-set-if-not-given-yet! o "repeat" never)
      (CHECK equal? (all-fields o) (list "-n" "--count" 0 unlimited 'expr "repeat"))
      (CHECK equal? (map unbound? (all-fields o)) '(#f #f #f #f #f #f))))

  ;; (field setter getter first second): the setter sets `first`, then calls on-duplicate for `second`
  (define wrappers
    (list (list "short" option-ast-short-set-if-not-given-yet! option-ast-short "-a" "-b")
          (list "long" option-ast-long-set-if-not-given-yet! option-ast-long "--a" "--b")
          (list "min" option-ast-min-set-if-not-given-yet! option-ast-min 1 2)
          (list "max" option-ast-max-set-if-not-given-yet! option-ast-max 3 4)
          (list "converter" option-ast-converter-set-if-not-given-yet! option-ast-converter 'e1 'e2)
          (list "description" option-ast-description-set-if-not-given-yet! option-ast-description "d1" "d2")))

  (define-test test-set-if-not-given-yet-sets-an-unbound-field
    (for-each
     (lambda (w)
       (let ([o (make-unbound-option-ast 'src)]
             [calls 0])
         ((cadr w) o (list-ref w 3) (lambda () (set! calls (+ calls 1))))
         (CHECK equal? ((caddr w) o) (list-ref w 3))
         (CHECK eqv? calls 0)))
     wrappers))

  (define-test test-set-if-not-given-yet-reports-a-field-given-twice-and-keeps-the-first
    (for-each
     (lambda (w)
       (let ([o (make-unbound-option-ast 'src)]
             [calls 0])
         ((cadr w) o (list-ref w 3) never)
         ((cadr w) o (list-ref w 4) (lambda () (set! calls (+ calls 1))))
         (CHECK eqv? calls 1)
         (CHECK equal? ((caddr w) o) (list-ref w 3))))
     wrappers))

  (define-test test-set-if-not-given-yet-counts-false-as-given
    ;; #f is a value (no long name, unbounded max), so giving it twice is a duplicate
    (let ([o (make-unbound-option-ast 'src)]
          [calls 0])
      (option-ast-long-set-if-not-given-yet! o #f never)
      (option-ast-long-set-if-not-given-yet! o "--x" (lambda () (set! calls (+ calls 1))))
      (CHECK eqv? calls 1)
      (CHECK equal? (option-ast-long o) #f)))

  (define-test test-fields-are-independent
    (let ([o (make-unbound-option-ast 'src)])
      (option-ast-long-set-if-not-given-yet! o "--x" never)
      (CHECK eq? (unbound? (option-ast-short o)) #t)
      (CHECK eq? (unbound? (option-ast-min o)) #t)
      (CHECK equal? (option-ast-long o) "--x")))

  (define-test test-plain-setters-are-not-exported
    (for-each
     (lambda (name)
       (CHECK eq?
              (guard (e [else #f])
                (environment `(only (rime command-line-options __ast) ,name))
                #t)
              #f))
     '(option-ast-short-set! option-ast-long-set! option-ast-min-set! option-ast-max-set!
       option-ast-converter-set! option-ast-description-set!))
    (CHECK eq?
           (guard (e [else #f])
             (environment '(only (rime command-line-options __ast)
                                 option-ast-long-set-if-not-given-yet!))
             #t)
           #t))

  (define-test test-false-is-a-set-value-not-unbound
    ;; #f is a value (no short name, no long name, no converter), not "not given"
    (let ([o (make-unbound-option-ast 'src)])
      (option-ast-short-set-if-not-given-yet! o #f never)
      (option-ast-long-set-if-not-given-yet! o #f never)
      (option-ast-converter-set-if-not-given-yet! o #f never)
      (CHECK eq? (unbound? (option-ast-short o)) #f)
      (CHECK eq? (unbound? (option-ast-long o)) #f)
      (CHECK eq? (unbound? (option-ast-converter o)) #f)
      (option-ast-fill-defaults! o)
      (CHECK equal? (all-fields o) '(#f #f 1 1 #f ""))))

  (define-test test-defaults-for-a-bare-option
    (let ([o (make-unbound-option-ast 'src)])
      (option-ast-fill-defaults! o)
      (CHECK equal? (all-fields o) '(#f #f 1 1 #f ""))
      (CHECK equal? (option-ast-source o) 'src)))

  (define-test test-defaults-keep-what-was-given
    (let ([o (make-unbound-option-ast 'src)])
      (option-ast-short-set-if-not-given-yet! o "-n" never)
      (option-ast-long-set-if-not-given-yet! o "--count" never)
      (option-ast-min-set-if-not-given-yet! o 2 never)
      (option-ast-max-set-if-not-given-yet! o 5 never)
      (option-ast-converter-set-if-not-given-yet! o 'int never)
      (option-ast-fill-defaults! o)
      (CHECK equal? (all-fields o) '("-n" "--count" 2 5 int ""))))

  (define-test test-defaults-are-idempotent
    (let ([o (make-unbound-option-ast 'src)])
      (option-ast-fill-defaults! o)
      (option-ast-fill-defaults! o)
      (CHECK equal? (all-fields o) '(#f #f 1 1 #f ""))))

  (define-test test-unlimited-is-the-largest-possible-max
    (CHECK equal? unlimited (greatest-fixnum))
    (CHECK equal? (problems (opt 'a "-a" #f 0 unlimited #f)) '())
    (CHECK equal? (problems (opt 'a "-a" #f unlimited unlimited #f)) '())
    (CHECK equal? (problems (opt 'a "-a" #f (+ 1 0) unlimited #f)) '()))

  (define-test test-valid-options
    (CHECK equal? (problems) '())
    (CHECK equal? (problems (opt 'a "-a" #f 1 1 #f)) '())
    (CHECK equal? (problems (opt 'a "-a" "--alpha" 0 0 #f)
                            (opt 'b "-b" "--beta" 1 1 'int)
                            (opt 'c "-c" #f 0 unlimited 'custom)
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

  (define-test test-an-option-needs-a-short-or-a-long-name
    (CHECK equal? (problems (opt 'a #f #f 1 1 #f)) (list (cons no-name-message 'a)))
    (CHECK equal? (problems (opt 'a "-a" #f 1 1 #f)) '())
    (CHECK equal? (problems (opt 'a #f "--alpha" 1 1 #f)) '())
    (CHECK equal? (problems (opt 'a "-a" "--alpha" 1 1 #f)) '()))

  (define-test test-short-name-is-optional
    (CHECK equal? (problems (opt 'a #f "--alpha" 1 1 #f) (opt 'b #f "--beta" 0 0 #f)) '()))

  (define-test test-names-of-options-without-a-short-name-must-still-be-unique
    (CHECK equal? (problems (opt 'a #f "--x" 1 1 #f) (opt 'b #f "--x" 1 1 #f))
           (list (cons twice-message 'b)))
    (CHECK equal? (problems (opt 'a #f "--help" 1 1 #f)) (list (cons reserved-message 'a))))

  (define-test test-many-options-without-short-names
    ;; there is no limit of one option per letter
    (CHECK equal?
           (apply problems
                  (map (lambda (i) (opt i #f (string-append "--option-" (number->string i)) 1 1 #f))
                       (range 200)))
           '()))

  (define-test test-long-name-is-optional
    (CHECK equal? (problems (opt 'a "-a" #f 1 1 #f)) '()))

  ;; ========================================
  ;; arity and type
  ;; ========================================

  (define-test test-arity-min-must-not-exceed-max
    (CHECK equal? (problems (opt 'a "-a" #f 3 2 #f)) (list (cons arity-message 'a)))
    (CHECK equal? (problems (opt 'a "-a" #f 2 2 #f)) '())
    (CHECK equal? (problems (opt 'a "-a" #f 2 3 #f)) '())
    (CHECK equal? (problems (opt 'a "-a" #f 9 unlimited #f)) '()))

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
       (CHECK equal? (problems (opt 'a "-a" #f 0 unlimited type)) '()))
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
