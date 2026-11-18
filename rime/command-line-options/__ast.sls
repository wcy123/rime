#!r6rs
;; Phase 1 of define-command-line-options: the syntax of one option clause is parsed and
;; validated into an option-ast record. Code generation (phase 2) only reads these records.
;; This library is imported `for expand`.
(library (rime command-line-options __ast)
  (export syntax-list
          parse-option
          check-options
          option-ast-short
          option-ast-long
          option-ast-min
          option-ast-max
          option-ast-type
          option-ast-description)
  (import (rnrs (6)))

  ;; short, long: strings, long may be #f
  ;; min, max: non-negative integers, max is #f when unbounded
  ;; type: 'string 'int 'float 'bool, or the syntax of a procedure expression
  ;; description: a string
  ;; form: the clause syntax, for error messages
  (define-record-type option-ast
    (fields short long min max type description form))

  (define reserved-names '("-h" "--help"))
  (define known-fields '(:long :arity :type :description))

  (define (violation message form)
    (syntax-violation 'define-command-line-options message form))

  (define (syntax-list form)
    (syntax-case form ()
      [() '()]
      [(x . rest) (cons #'x (syntax-list #'rest))]))

  (define (non-negative-integer? datum)
    (and (integer? datum) (exact? datum) (>= datum 0)))

  (define (well-formed? name)
    (for-all (lambda (c) (not (or (char=? c #\=) (char=? c #\,) (char-whitespace? c))))
             (string->list name)))

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

  (define (parse-short form)
    (let ([name (name->string form "option name")])
      (unless (and (> (string-length name) 1)
                   (char=? (string-ref name 0) #\-)
                   (not (char=? (string-ref name 1) #\-))
                   (well-formed? name))
        (violation "option name must look like \"-x\"" form))
      name))

  (define (parse-long form)
    (and form
         (let ([name (name->string form ":long name")])
           (unless (and (> (string-length name) 2)
                        (string=? (substring name 0 2) "--")
                        (not (char=? (string-ref name 2) #\-))
                        (well-formed? name))
             (violation ":long name must look like \"--name\"" form))
           name)))

  ;; returns (cons min max), max = #f when unbounded
  (define (parse-arity form)
    (let ([datum (if form (syntax->datum form) 1)])
      (cond
       [(non-negative-integer? datum) (cons datum datum)]
       [(and (pair? datum) (pair? (cdr datum)) (null? (cddr datum))
             (non-negative-integer? (car datum))
             (or (eq? (cadr datum) '+) (non-negative-integer? (cadr datum))))
        (let ([min (car datum)]
              [max (if (eq? (cadr datum) '+) #f (cadr datum))])
          (when (and max (> min max))
            (violation "arity min must not exceed max" form))
          (cons min max))]
       [else (violation "arity must be n, (min max) or (min +)" form)])))

  (define (parse-type form)
    (cond [(not form) 'string]
          [(memq (syntax->datum form) '(string int float bool)) (syntax->datum form)]
          [else form]))

  (define (parse-description form)
    (cond [(not form) ""]
          [(string? (syntax->datum form)) (syntax->datum form)]
          [else (violation ":description must be a string" form)]))

  ;; clause = (name (key value) ...)
  (define (parse-option clause)
    (syntax-case clause ()
      [(name (key value) ...)
       (let* ([pairs (map cons (syntax-list #'(key ...)) (syntax-list #'(value ...)))]
              [unused (for-each (lambda (p)
                                  (unless (memq (syntax->datum (car p)) known-fields)
                                    (violation "unknown field" (car p))))
                                pairs)]
              [short (parse-short #'name)]
              [long (parse-long (field pairs ':long))]
              [arity (parse-arity (field pairs ':arity))]
              [type-form (field pairs ':type)]
              [description (parse-description (field pairs ':description))])
         (when (and type-form (eqv? 0 (car arity)) (eqv? 0 (cdr arity)))
           (violation ":type must not be given when arity is 0" type-form))
         (make-option-ast short long (car arity) (cdr arity)
                          (parse-type type-form) description clause))]))

  ;; names must be unique across all options and must not use the built-in help names
  (define (check-options options)
    (let loop ([options options] [seen reserved-names])
      (unless (null? options)
        (let* ([option (car options)]
               [names (if (option-ast-long option)
                          (list (option-ast-short option) (option-ast-long option))
                          (list (option-ast-short option)))])
          (for-each
           (lambda (name)
             (when (member name seen)
               (violation (if (member name reserved-names)
                              "-h and --help are reserved for the built-in help"
                              "option name is defined twice")
                          (option-ast-form option))))
           names)
          (loop (cdr options) (append names seen)))))))
