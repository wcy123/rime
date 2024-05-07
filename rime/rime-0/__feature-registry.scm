#!r6rs
(library (rime rime-0 __feature-registry)
  (export check-library check-feature)
  (import (rnrs (6))
          (rnrs eval (6)))

  (define-syntax import-spec-exists?
    (syntax-rules ()
      [(_ import-spec)
       (guard
           (exn
            [else #f])
         (eval #t (environment import-spec)))]))

  (define-syntax define-feature-if-import-set
    (syntax-rules ()
      [(_ feature-id import-spec)
       (cons (quote feature-id)
             (import-spec-exists? 'import-spec))]))

  (define feature-registry
    (list
     (define-feature-if-import-set guile (guile))
     (define-feature-if-import-set chezscheme (chezscheme))
     ))

  (define (check-feature feature-id)
    (cond
     [(assq feature-id feature-registry) => cdr]
     [else #f]) )

  (define (check-library import-spec)
    (import-spec-exists? import-spec)))
