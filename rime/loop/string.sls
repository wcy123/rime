#!r6rs
(library (rime loop string)
  (export loop/core/string)
  (import (rnrs (6))
          (rime loop keywords))
  (define (make-string-plugin s-var s-expr s-offset)
    (let ()
      (lambda (method . args)
        (with-syntax ([expr s-expr]
                      [var s-var]
                      [offset s-offset]
                      [expr-var (new-var s-var "-string-expr")]
                      [var-index (new-var s-var "-string-index")])
          (case method
            [(debug)
             (object-to-string
              ":for " (syntax->datum #'var) " :in-string "
              (cons '~s (syntax->datum #'expr)))]
            [(setup)
             (list #'(expr-var expr))]
            [(recur)
             (list)]
            [(before-loop-begin)
             (list)]
            [(init)
             (list #'[var-index offset])]
            [(loop-entry)
             (list #'[var (string-ref expr-var var-index)])]
            [(continue-condition)
             #'(< var-index (string-length expr-var))]
            [(loop-body)
             (car args)]
            [(step)
             (list #'(+ 1 var-index))]
            [(finally)
             '()]
            [else (syntax-violation #'make-string-plugin "never goes here" method)])))))

  (define (loop/core/string e)
    (syntax-case e (:for  :in-string :offset)
      [(k :for var :in-string expr :offset offset rest ...)
       (begin
         (values (make-string-plugin #'var #'expr #'offset)
                 #'(k rest ...)))]
      [(k :for var :in-string expr rest ...)
       (begin
         (values (make-string-plugin #'var #'expr 0)
                 #'(k rest ...)))]
      [(k rest ...)
       (values #f e)
       ])))