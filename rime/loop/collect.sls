#!r6rs
(library (rime loop collect)
  (export loop/core/collect)
  (import (rnrs (6))
          (rnrs mutable-pairs (6))
          (rime loop plugin)
          (rime loop keywords))
  (define (make-collect-list-plugin s-var s-expr append? s-cond-expr)
    (lambda (method . args)
      (with-syntax ([var s-var]
                    [var-tail (new-sym s-var "collect:tail")]
                    [expr s-expr])
        (define (gen-collect-body a-expr)
          (with-syntax ([expr a-expr])
            #'(if (null? var)
                  (set! var (cons expr '()))
                  (begin
                    (when (null? var-tail)
                      (let find-tail ([var var])
                        (if (not (null? (cdr var)))
                            (find-tail (cdr var))
                            (set! var-tail var))))
                    (set-cdr! var-tail (cons expr '()))
                    (set! var-tail (cdr var-tail))))))
        (case method
          [(debug)
           (object-to-string
            (if append? ":append" ":collect") " "
            (syntax->datum s-expr) " :into " (syntax->datum s-var))
           ]
          [(setup)
           (list
            #'(var '() #t)
            #'(var-tail '()))]

          [(loop-body finally)
           (cons
            (with-syntax ([cond-expr s-cond-expr])
              (if (not append?)
                  #`(when cond-expr
                      #,(gen-collect-body #'expr))
                  (let ([s-tmp (car (generate-temporaries (list #'var)))])
                    (with-syntax ([inner-body (gen-collect-body s-tmp)]
                                  [tmp s-tmp])
                      #'(when cond-expr
                          (let local-loop ([e expr])
                            (if (not (null? e))
                                (let ([tmp (car e)])
                                  inner-body
                                  (local-loop (cdr e))))))))))
            (if (null? args) '() (car args)))
           ]
          [else (apply default-plugin #'make-collect-plugin method args)]))))

  (define (make-collect-hash-table-plugin s-var s-expr s-cond-expr s-ctor)
    (lambda (method . args)
      (syntax-case s-expr ()
        [(key value)
         (with-syntax ([var s-var]
                       [expr s-expr]
                       [cond-expr s-cond-expr]
                       [ctor s-ctor])
           (case method
             [(debug)
              (object-to-string
               ":collect :as :hash-table "
               (syntax->datum s-expr) " :into " (syntax->datum s-var))
              " :ctor "  (syntax->datum s-ctor)
              " :if "  (syntax->datum s-cond-expr)
              ]
             [(setup)
              (list
               #'(var ctor))]

             [(loop-body finally)
              (cons
               #'(when cond-expr
                   (hashtable-set! var key value))
               (if (null? args) '() (car args)))
              ]
             [else (apply default-plugin #'make-collect-plugin method args)]))]
        [else (syntax-violation 'make-collect-hash-table-plugin "expect key value pair" s-expr)])))

  (define (loop/core/collect original-e)
    (let loop ([e original-e])

      (syntax-case e (:collect
                      :append
                      :into
                      :if
                      :when
                      :unless
                      :expr
                      :as
                      :list
                      :hast-able
                      :make-hash-table
                      )
        [(k :collect expr rest ...)
         (loop #'(k (:collect (:append . #f) (:expr . expr)) rest ...))
         ]

        [(k :append expr rest ...)
         (loop #'(k (:collect (:append . #t) (:expr . expr)) rest ...))
         ]

        [(k (:collect (prop . value) ...) :if cond-expr rest ...)
         (loop #'(k (:collect (:if . cond-expr) (prop . value) ...) rest ...))
         ]

        [(k (:collect (prop . value) ...) :when cond-expr rest ...)
         (loop #'(k (:collect (:if . cond-expr) (prop . value) ...) rest ...))
         ]

        [(k (:collect (prop . value) ...) :unless cond-expr rest ...)
         (loop #'(k (:collect (:if . (not cond-expr)) (prop . value) ...) rest ...))
         ]

        [(k (:collect (prop . value) ...) :into var rest ...)
         (loop #'(k (:collect (:into . var) (prop . value) ...) rest ...))
         ]

        [(k (:collect (prop . value) ...) :as :list rest ...)
         (loop #'(k (:collect (:as . :list) (prop . value) ...) rest ...))
         ]

        [(k (:collect (prop . value) ...) :as :hash-table rest ...)
         (loop #'(k (:collect (:as . :hash-table)
                              (prop . value) ...) rest ...))
         ]

        [(k (:collect (prop . value) ...) :make-hash-table expr rest ...)
         (loop #'(k (:collect (:make-hash-table . expr)
                              (prop . value) ...) rest ...))
         ]

        [(k (:collect (prop . value) ...) rest ...)
         (let [(props #'((prop . value) ...))]
           (values (cond
                    [(keyword=? (assq-id ':as props #':list) #':list)
                     (make-collect-list-plugin
                      (assq-id ':into props (loop-return-value #'k))
                      (assq-id ':expr props #f)
                      (syntax->datum (assq-id ':append props #f))
                      (assq-id ':if props #t))]
                    [(keyword=? (assq-id ':as props #':list) #':hash-table)
                     (make-collect-hash-table-plugin
                      (assq-id ':into props (loop-return-value #'k))
                      (assq-id ':expr props #'(#f . #f))
                      (assq-id ':if props #t)
                      (assq-id ':make-hash-table props #'(make-eq-hashtable)))]
                    [else (raise "not go here")])
                   #'(k rest ...)))
         ]

        [(k rest ...)
         (values #f e)
         ]
        ))))
