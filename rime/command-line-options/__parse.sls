#!r6rs
;; Phase 1 of define-command-line-options: read the syntax, produce the AST. Nothing is generated.
;; This is the only place that looks at the surface syntax of a clause, and the only place that
;; reads syntax objects. It walks the clauses and the fields of each clause by pattern matching,
;; checks that they are well formed (known fields, no duplicates, values of the right shape),
;; builds option-ast records, then lets check-options apply the semantic rules.
;; This library is imported `for expand`.
(library (rime command-line-options __parse)
  (export parse-options)
  (import (rnrs (6))
          (rime command-line-options __keywords)
          (rime command-line-options __ast)
          (only (rime command-line-options __runtime)
                builtin-converters builtin-converter make-choice-converter procedure->converter))

  ;; (parse-options clauses) => list of option-ast
  ;;   input   clauses: the syntax of `clause ...` in (define-command-line-options parser clause ...),
  ;;           exactly as the user wrote them
  ;;   output  one option-ast per clause, in the same order, already checked (fields: see __ast.sls)
  ;;   errors  a syntax violation, at the clause or at the offending part of it
  ;;
  ;;   (parse-options #'([:short "-v" :arity 0 :description "verbose"]
  ;;                     [:long "--count" :type int]
  ;;                     [:short "-f" :long "--files" :arity (1 +) :type (lambda (s) s)]))
  ;;
  ;;   => short  long      min  max        converter                                  description
  ;;      "-v"   #f        0    0          #f                                         "verbose"
  ;;      #f     "--count" 1    1          (builtin-converter 'int)                   ""
  ;;      "-f"   "--files" 1    unlimited  (procedure->converter (lambda (s) s))      ""
  ;;
  ;;   (each record also keeps its clause as `source`)
  ;;
  ;;   (parse-options #'([:short "-n" :arity (3 2)]))  => violation: arity min must not exceed max
  ;;   (parse-options #'([:short "-a"] [:short "-a"])) => violation: option name is defined twice
  ;;   (parse-options #'([:colour red]))               => violation: unknown field, ... (at :colour)
  ;;   (parse-options #'([]))                          => violation: an option needs a :short or a :long name
  (define (parse-options clauses)
    (let ([options (read-clauses clauses)])
      (check-options options
                     (lambda (message option)
                       (violation message (option-ast-source option))))
      options))

  ;; the clauses, one after the other -> list of option-ast in the same order, not yet checked
  ;;   (read-clauses #'(c1 c2 c3)) = (list (read-clause #'c1) (read-clause #'c2) (read-clause #'c3))
  (define (read-clauses clauses)
    (syntax-case clauses ()
      [() '()]
      [(clause . rest) (cons (read-clause #'clause) (read-clauses #'rest))]))

  ;; (read-clause clause) => option-ast
  ;;   input   clause: the syntax of one clause, as the user wrote it: a list of :key value pairs
  ;;   output  one option-ast; `clause` itself is kept in it as `source`
  ;;
  ;;   clause = [:short "-n" :long "--count" :type int :description "repeat"]
  ;;
  ;;   => short  long      min  max  converter                 description
  ;;      "-n"   "--count" 1    1    (builtin-converter 'int)  "repeat"
  ;;
  ;;   [:long "--count"]  => short #f, long "--count", min 1, max 1, no converter, description ""
  ;;   "-n"               => violation: an option clause is a list of :key value pairs
  ;;   ["-n" :long "--x"] => violation: unknown field ... (at "-n")
  ;;   [:short 42]        => violation: :short name must be a string or a symbol
  ;; Whether the option has a name at all is a semantic rule, checked later (__ast.sls).
  (define (read-clause clause)
    (let ([option (read-fields clause (make-unbound-option-ast clause))])
      (option-ast-fill-defaults! option)
      option))

  ;; (read-fields fields option) sets the fields that the clause gives, in place
  ;;   input   fields: the syntax of the :key value pairs of one clause, in any order
  ;;           option: an option-ast whose fields are still unbound
  ;;   output  `option` itself, updated
  ;;
  ;; The keywords are literals of the pattern. Each pattern reads and checks its value, sets the
  ;; field with option-ast-<field>-set-if-not-given-yet! (a field that is already set was given
  ;; before, so its keyword is a duplicate), and goes on with the rest.
  ;;
  ;;   (read-fields #'(:type int :long "--count") option)
  ;;   => long = "--count", converter = (builtin-converter 'int); the other fields are still unbound
  (define (read-fields fields option)
    (syntax-case fields (:short :long :arity :type :choices :description :required)
      [() option]
      [(:short value . rest)
       (begin
         (option-ast-short-set-if-not-given-yet!
          option (name->string #'value ":short name") (duplicate #'value))
         (read-fields #'rest option))]
      [(:long value . rest)
       (begin
         (option-ast-long-set-if-not-given-yet!
          option (name->string #'value ":long name") (duplicate #'value))
         (read-fields #'rest option))]
      [(:arity value . rest)
       (let-values ([(min max) (read-arity #'value)])
         (option-ast-min-set-if-not-given-yet! option min (duplicate #'value))
         (option-ast-max-set-if-not-given-yet! option max (duplicate #'value))
         (read-fields #'rest option))]
      [(:type value . rest)
       (begin
         (option-ast-converter-set-if-not-given-yet!
          option (read-converter #'value) (converter-given-twice #'value))
         (read-fields #'rest option))]
      [(:choices value . rest)
       (begin
         (option-ast-converter-set-if-not-given-yet!
          option (read-choices #'value) (converter-given-twice #'value))
         (read-fields #'rest option))]
      [(:description value . rest)
       (begin
         (option-ast-description-set-if-not-given-yet!
          option (read-description #'value) (duplicate #'value))
         (read-fields #'rest option))]
      [(:required . rest)
       (begin
         (option-ast-required-set-if-not-given-yet! option #t (duplicate fields))
         (read-fields #'rest option))]
      [(bad . _)
       (violation "unknown field, or field without a value (expected :short :long :arity :type :choices :description :required)"
                  #'bad)]
      [_ (violation "an option clause is a list of :key value pairs" fields)]))

  ;; what to do when a field is given twice: a syntax violation at the second value
  (define (duplicate value)
    (lambda () (violation "duplicate field" value)))

  ;; :type and :choices both set the one converter, so they exclude each other
  (define (converter-given-twice value)
    (lambda ()
      (violation "the converter is given twice, use only one of :type and :choices" value)))

  ;; the :arity value -> (values min max), max is `unlimited` for (min +)
  ;;   n => (values n n)    (min max) => (values min max)    (min +) => (values min unlimited)
  (define (read-arity form)
    (syntax-case form (+)
      [n (count? #'n)
         (values (syntax->datum #'n) (syntax->datum #'n))]
      [(min +) (count? #'min)
       (values (syntax->datum #'min) unlimited)]
      [(min max) (and (count? #'min) (count? #'max))
       (values (syntax->datum #'min) (syntax->datum #'max))]
      [_ (violation "arity must be n, (min max) or (min +)" form)]))

  (define (count? form)
    (let ([datum (syntax->datum form)])
      (and (integer? datum) (exact? datum) (>= datum 0))))

  ;; a name is written as a string or as a symbol
  (define (name->string form what)
    (let ([datum (syntax->datum form)])
      (cond [(string? datum) datum]
            [(symbol? datum) (symbol->string datum)]
            [else (violation (string-append what " must be a string or a symbol") form)])))

  ;; the :type value -> the expression of a converter, whether it is builtin or custom
  ;;   int            => #'(builtin-converter 'int), the lookup by name in the runtime
  ;;                     (see builtin-converters in __runtime.sls)
  ;;   (lambda (s) s) => #'(procedure->converter (lambda (s) s)), the procedure becomes a converter
  (define (read-converter form)
    (if (assq (syntax->datum form) builtin-converters)
        (with-syntax ([name form])
          #'(builtin-converter 'name))
        (with-syntax ([procedure form])
          #'(procedure->converter procedure))))

  ;; the :choices value, a list of literals -> a converter expression
  ;;   ("json" "text") => #'(make-choice-converter '("json" "text"))
  ;; each choice is a string or an exact integer, there is at least one, and no two of them have the
  ;; same text (the argument 1 would match both "1" and 1)
  (define (read-choices form)
    (with-syntax ([choices (datum->syntax #'here (read-choice-list form form '()))])
      #'(make-choice-converter 'choices)))

  ;; the datums of the literals in `rest`, checked; `texts` are the texts of those before
  (define (read-choice-list rest whole texts)
    (syntax-case rest ()
      [() (if (null? texts)
              (violation ":choices needs at least one choice" whole)
              '())]
      [(choice . more)
       (let ([text (choice-text #'choice)])
         (when (member text texts)
           (violation "duplicate choice" #'choice))
         (cons (syntax->datum #'choice)
               (read-choice-list #'more whole (cons text texts))))]
      [_ (violation ":choices must be a list of strings or integers" whole)]))

  ;; the text an argument has to have to match the choice
  (define (choice-text form)
    (let ([datum (syntax->datum form)])
      (cond [(string? datum) datum]
            [(and (integer? datum) (exact? datum)) (number->string datum)]
            [else (violation "a choice must be a string or an integer" form)])))

  (define (read-description form)
    (if (string? (syntax->datum form))
        (syntax->datum form)
        (violation ":description must be a string" form)))

  (define (violation message form)
    (syntax-violation 'define-command-line-options message form)))
