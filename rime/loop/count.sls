(library (rime loop count)
  (export loop/core/count)
  (import (rnrs (6))
          (rime loop plugin)
          (rime loop keywords))

  ;; Plugin for :count with proper :into, :by, and :if support
  (define (make-count-plugin props)
    (let ([s-var (assq-id ':into props #f)]
          [s-by (assq-id ':by props #'1)]  ; default increment is 1
          [s-cond-expr (assq-id ':if props #t)])

      (with-syntax ([var s-var]
                    [by-expr s-by]
                    [cond-expr s-cond-expr])
        (lambda (method . args)
          (case method
            [(debug)
             (object-to-string
              ":count"
              (if s-var (list " :into " (syntax->datum s-var)) "")
              (if s-by (list " :by " (syntax->datum s-by)) "")
              " :if " (syntax->datum s-cond-expr))]

            [(setup)
             (list #'(var 0))]

            [(iteration-body)
             (cons
              #'(when cond-expr
                  (set! var (fx+ var by-expr)))
              (car args))]

            [else (apply default-plugin #'make-count-plugin method args)])))))

  (define (loop/core/count original-e)
    (let loop ([e original-e])
      (syntax-case e (:count :if :when :unless :into :by)
        ;; :count without :into defaults to :return-value
        [(k :count rest ...)
         (with-syntax ([return-value (loop-return-value #'k)])
           (loop #'(k (:count (:into . return-value)) rest ...)))]

        ;; :count with :into
        [(k (:count (prop . value) ...) :into var rest ...)
         (loop #'(k (:count (:into . var) (prop . value) ...) rest ...))]

        ;; :count with :by (step/increment)
        [(k (:count (prop . value) ...) :by by-expr rest ...)
         (loop #'(k (:count (:by . by-expr) (prop . value) ...) rest ...))]

        ;; :count with :if
        [(k (:count (prop . value) ...) :if cond-expr rest ...)
         (loop #'(k (:count (:if . cond-expr) (prop . value) ...) rest ...))]

        ;; :count with :when (alias for :if)
        [(k (:count (prop . value) ...) :when cond-expr rest ...)
         (loop #'(k (:count (:if . cond-expr) (prop . value) ...) rest ...))]

        ;; :count with :unless
        [(k (:count (prop . value) ...) :unless cond-expr rest ...)
         (loop #'(k (:count (:if . (not cond-expr)) (prop . value) ...) rest ...))]

        ;; Final: create the plugin
        [(k (:count (prop . value) ...) rest ...)
         (values (make-count-plugin #'((prop . value) ...))
                 #'(k rest ...))]

        [(k rest ...)
         (values #f e)]))))
