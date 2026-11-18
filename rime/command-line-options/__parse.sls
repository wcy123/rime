#!r6rs
;; Phase 1 of define-command-line-options: syntax -> AST.
;; This is the only place that looks at the surface syntax of a clause, and the only place that
;; reads syntax objects. It checks that a clause is well formed (known fields, no duplicates,
;; values of the right shape), builds option-ast records, then lets check-options apply the
;; semantic rules. This library is imported `for expand`.
(library (rime command-line-options __parse)
  (export parse-options
          syntax-list)
  (import (rnrs (6))
          (rime command-line-options __ast))

  (define known-fields '(:long :arity :type :description))
  (define builtin-types '(string int float bool))

  (define (violation message form)
    (syntax-violation 'define-command-line-options message form))

  (define (syntax-list form)
    (syntax-case form ()
      [() '()]
      [(x . rest) (cons #'x (syntax-list #'rest))]))

  (define (non-negative-integer? datum)
    (and (integer? datum) (exact? datum) (>= datum 0)))

  ;; a name is written as a string or as a symbol
  (define (name->string form what)
    (let ([datum (syntax->datum form)])
      (cond [(string? datum) datum]
            [(symbol? datum) (symbol->string datum)]
            [else (violation (string-append what " must be a string or a symbol") form)])))

  ;; the value syntax of field `key`, #f if the clause does not have it
  (define (field pairs key)
    (let ([found (filter (lambda (p) (eq? (syntax->datum (car p)) key)) pairs)])
      (cond [(null? found) #f]
            [(null? (cdr found)) (cdr (car found))]
            [else (violation "duplicate field" (car (cadr found)))])))

  ;; n, (min max) or (min +); returns (cons min max), max = #f when unbounded
  (define (parse-arity form)
    (let ([datum (if form (syntax->datum form) 1)])
      (cond
       [(non-negative-integer? datum) (cons datum datum)]
       [(and (pair? datum) (pair? (cdr datum)) (null? (cddr datum))
             (non-negative-integer? (car datum))
             (or (eq? (cadr datum) '+) (non-negative-integer? (cadr datum))))
        (cons (car datum) (if (eq? (cadr datum) '+) #f (cadr datum)))]
       [else (violation "arity must be n, (min max) or (min +)" form)])))

  (define (parse-description form)
    (cond [(not form) ""]
          [(string? (syntax->datum form)) (syntax->datum form)]
          [else (violation ":description must be a string" form)]))

  ;; clause = (name (key value) ...)
  (define (parse-clause clause)
    (syntax-case clause ()
      [(name (key value) ...)
       (let* ([pairs (map cons (syntax-list #'(key ...)) (syntax-list #'(value ...)))]
              [unknown (filter (lambda (p) (not (memq (syntax->datum (car p)) known-fields))) pairs)]
              [long-form (field pairs ':long)]
              [type-form (field pairs ':type)]
              [arity (parse-arity (field pairs ':arity))])
         (unless (null? unknown)
           (violation "unknown field" (car (car unknown))))
         (make-option-ast
          (name->string #'name "option name")
          (and long-form (name->string long-form ":long name"))
          (car arity)
          (cdr arity)
          (cond [(not type-form) #f]
                [(memq (syntax->datum type-form) builtin-types) (syntax->datum type-form)]
                [else 'custom])
          (and type-form (not (memq (syntax->datum type-form) builtin-types)) type-form)
          (parse-description (field pairs ':description))
          clause))]))

  ;; list of clause syntax -> list of option-ast, all checked
  (define (parse-options clauses)
    (let ([options (map parse-clause clauses)])
      (check-options options
                     (lambda (message option)
                       (violation message (option-ast-source option))))
      options)))
