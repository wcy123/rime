#!r6rs
(library (rime command-line-options)
  (export define-command-line-options)
  (import (rnrs (6))
          (for (rnrs (6)) expand)
          (rime command-line-options __parser))

  ;; (define-command-line-options parser clause ...)
  ;;   clause = [name field ...]   name = "-x" or -x
  ;;   field  = :long name | :arity n | (min max) | (min +) | :type type | :description "text"
  ;; defines (parser arguments) => accessor procedure
  (define-syntax define-command-line-options
    (lambda (stx)
      (syntax-case stx ()
        [(_ parser clause ...)
         (identifier? #'parser)
         #'(collect-clauses parser () clause ...)]
        [_ (syntax-violation 'define-command-line-options
                             "expected (define-command-line-options name clause ...)"
                             stx)])))

  ;; Walks the clauses one by one, accumulating (name (key value) ...) per clause.
  (define-syntax collect-clauses
    (lambda (stx)
      (syntax-case stx ()
        [(_ parser (spec ...))
         #'(finish-definition parser spec ...)]
        [(_ parser specs [name field ...] clause ...)
         #'(collect-fields parser specs (clause ...) name () field ...)]
        [(_ parser specs bad . _)
         (syntax-violation 'define-command-line-options
                           "option clause must look like [name field ...]"
                           #'bad)])))

  ;; Walks the fields of one clause, accumulating (key value) pairs.
  (define-syntax collect-fields
    (lambda (stx)
      (syntax-case stx (:long :arity :type :description)
        [(_ parser (spec ...) (clause ...) name (pair ...))
         #'(collect-clauses parser (spec ... (name pair ...)) clause ...)]
        [(_ parser specs clauses name (pair ...) :long value . rest)
         #'(collect-fields parser specs clauses name (pair ... (:long value)) . rest)]
        [(_ parser specs clauses name (pair ...) :arity value . rest)
         #'(collect-fields parser specs clauses name (pair ... (:arity value)) . rest)]
        [(_ parser specs clauses name (pair ...) :type value . rest)
         #'(collect-fields parser specs clauses name (pair ... (:type value)) . rest)]
        [(_ parser specs clauses name (pair ...) :description value . rest)
         #'(collect-fields parser specs clauses name (pair ... (:description value)) . rest)]
        [(_ parser specs clauses name pairs bad . _)
         (syntax-violation 'define-command-line-options
                           "unknown field, or field without a value (expected :long :arity :type :description)"
                           #'bad)])))

  ;; Validates all collected clauses and emits the definition.
  (define-syntax finish-definition
    (lambda (stx)
      (define (violation message form)
        (syntax-violation 'define-command-line-options message form))

      (define (syntax-list form)
        (syntax-case form ()
          [() '()]
          [(x . rest) (cons #'x (syntax-list #'rest))]))

      (define (field-pairs keys values)
        (map cons (syntax-list keys) (syntax-list values)))

      (define (name->string form what)
        (let ([datum (syntax->datum form)])
          (cond [(string? datum) datum]
                [(symbol? datum) (symbol->string datum)]
                [else (violation (string-append what " must be a string or a symbol") form)])))

      (define (well-formed? name)
        (for-all (lambda (c) (not (or (char=? c #\=) (char=? c #\,) (char-whitespace? c))))
                 (string->list name)))

      (define (short-name? name)
        (and (> (string-length name) 1)
             (char=? (string-ref name 0) #\-)
             (not (char=? (string-ref name 1) #\-))
             (well-formed? name)))

      (define (long-name? name)
        (and (> (string-length name) 2)
             (string=? (substring name 0 2) "--")
             (not (char=? (string-ref name 2) #\-))
             (well-formed? name)))

      (define (non-negative-integer? datum)
        (and (integer? datum) (exact? datum) (>= datum 0)))

      ;; the value form of field `key`, #f if absent
      (define (field pairs key)
        (let ([found (filter (lambda (p) (eq? (syntax->datum (car p)) key)) pairs)])
          (cond [(null? found) #f]
                [(null? (cdr found)) (cdr (car found))]
                [else (violation "duplicate field" (car (cadr found)))])))

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
              (if (and max (> min max))
                  (violation "arity min must not exceed max" form)
                  (cons min max)))]
           [else (violation "arity must be n, (min max) or (min +)" form)])))

      ;; returns (list short long) as strings, long may be #f
      (define (names spec)
        (syntax-case spec ()
          [(name (key value) ...)
           (let* ([short (name->string #'name "option name")]
                  [long-form (field (field-pairs #'(key ...) #'(value ...)) ':long)]
                  [long (and long-form (name->string long-form ":long name"))])
             (unless (short-name? short)
               (violation "option name must look like \"-x\"" #'name))
             (when (and long (not (long-name? long)))
               (violation ":long name must look like \"--name\"" long-form))
             (list short long))]))

      (define (analyze spec)
        (syntax-case spec ()
          [(name (key value) ...)
           (let* ([pairs (field-pairs #'(key ...) #'(value ...))]
                  [short-and-long (names spec)]
                  [arity (parse-arity (field pairs ':arity))]
                  [type (field pairs ':type)]
                  [description (field pairs ':description)])
             (when (and type (= 0 (car arity)) (eqv? 0 (cdr arity)))
               (violation ":type must not be given when arity is 0" type))
             (when (and description (not (string? (syntax->datum description))))
               (violation ":description must be a string" description))
             (let-values ([(type-name converter)
                           (cond
                            [(or (not type) (eq? (syntax->datum type) 'string))
                             (values 'string #'convert-string)]
                            [(eq? (syntax->datum type) 'int) (values 'int #'convert-int)]
                            [(eq? (syntax->datum type) 'float) (values 'float #'convert-float)]
                            [(eq? (syntax->datum type) 'bool) (values 'bool #'convert-bool)]
                            [else (values #f type)])])
               (with-syntax ([short (datum->syntax #'here (car short-and-long))]
                             [long (datum->syntax #'here (cadr short-and-long))]
                             [min (datum->syntax #'here (car arity))]
                             [max (if (cdr arity)
                                      (datum->syntax #'here (cdr arity))
                                      #'(greatest-fixnum))]
                             [type-name (datum->syntax #'here type-name)]
                             [converter converter]
                             [description (or description (datum->syntax #'here ""))])
                 #'(make-option-spec short long min max 'type-name converter description))))]))

      (define (check-names specs)
        (let loop ([specs specs] [seen '("-h" "--help")])
          (unless (null? specs)
            (let ([used (filter values (names (car specs)))])
              (for-each
               (lambda (name)
                 (when (member name seen)
                   (violation (if (member name '("-h" "--help"))
                                  "-h and --help are reserved for the built-in help"
                                  "option name is defined twice")
                              (car specs))))
               used)
              (loop (cdr specs) (append used seen))))))

      (syntax-case stx ()
        [(_ parser spec ...)
         (let ([specs (syntax-list #'(spec ...))])
           (check-names specs)
           (with-syntax ([(make-spec ...) (map analyze specs)])
             #'(define parser
                 (let ([specs (list make-spec ...)])
                   (lambda (arguments)
                     (parse-command-line specs arguments))))))]))))
