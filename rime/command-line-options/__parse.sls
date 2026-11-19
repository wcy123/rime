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
                builtin-converters builtin-converter make-choice-converter procedure->converter
                converter-convert))

  ;; (parse-options clauses) => (values options positionals)
  ;;   input   clauses: the syntax of `clause ...` in (define-command-line-options parser clause ...),
  ;;           exactly as the user wrote them
  ;;   output  options: one option-ast per option clause, in the same order, already checked
  ;;           (fields: see __ast.sls)
  ;;           positionals: one positional-ast per :positional clause, in the same order
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
    (let* ([asts (read-clauses clauses)]
           [options (filter option-ast? asts)]
           [positionals (filter positional-ast? asts)]
           [report (lambda (message source) (violation message source))])
      (check-options options report)
      (check-positionals positionals options report)
      (values options positionals)))

  ;; the clauses, one after the other -> list of option-ast and positional-ast in the same order,
  ;; not yet checked
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
    (if (positional-clause? clause)
        (read-positional-clause clause)
        (let ([option (read-fields clause (make-unbound-option-ast clause))])
          (option-ast-fill-defaults! option)
          (check-default-fits option)
          option)))

  ;; a clause is a :positional clause when the keyword is in it, in any place
  (define (positional-clause? clause)
    (syntax-case clause (:positional)
      [() #f]
      [(:positional . _) #t]
      [(_ . rest) (positional-clause? #'rest)]
      [_ #f]))

  ;; (read-positional-clause clause) => positional-ast
  ;;   clause = [:positional "file" :arity (1 +) :type int :description "input files"]
  ;;   => name "file", min 1, max unlimited, converter (builtin-converter 'int), description "input files"
  ;;   The fields are those of an option without the names: :arity :type :choices :description.
  ;;   :short, :long and :required are for options and are a violation here.
  (define (read-positional-clause clause)
    (let ([positional (read-positional-fields clause (make-unbound-positional-ast clause))])
      (positional-ast-fill-defaults! positional)
      positional))

  (define (read-positional-fields fields positional)
    (syntax-case fields (:positional :arity :type :choices :description :short :long :required :default)
      [() positional]
      [(:positional value . rest)
       (begin
         (positional-ast-name-set-if-not-given-yet!
          positional (name->string #'value ":positional name") (duplicate #'value))
         (read-positional-fields #'rest positional))]
      [(:arity value . rest)
       (let-values ([(min max) (read-arity #'value)])
         (positional-ast-min-set-if-not-given-yet! positional min (duplicate #'value))
         (positional-ast-max-set-if-not-given-yet! positional max (duplicate #'value))
         (read-positional-fields #'rest positional))]
      [(:type value . rest)
       (begin
         (positional-ast-converter-set-if-not-given-yet!
          positional (read-converter #'value) (converter-given-twice #'value))
         (read-positional-fields #'rest positional))]
      [(:choices value . rest)
       (begin
         (positional-ast-converter-set-if-not-given-yet!
          positional (read-choices #'value) (converter-given-twice #'value))
         (read-positional-fields #'rest positional))]
      [(:description value . rest)
       (begin
         (positional-ast-description-set-if-not-given-yet!
          positional (read-description #'value) (duplicate #'value))
         (read-positional-fields #'rest positional))]
      [(:short . _)
       (violation ":short is a field of an option, not of a :positional clause" fields)]
      [(:long . _)
       (violation ":long is a field of an option, not of a :positional clause" fields)]
      [(:required . _)
       (violation ":required is a field of an option, not of a :positional clause" fields)]
      [(:default . _)
       (violation ":default is a field of an option, not of a :positional clause" fields)]
      [(bad . _)
       (violation "unknown field, or field without a value (expected :positional :arity :type :choices :description)"
                  #'bad)]
      [_ (violation "a clause is a list of :key value pairs" fields)]))

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
    (syntax-case fields (:short :long :arity :type :choices :description :required :default)
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
      [(:default value . rest)
       (begin
         (option-ast-default-set-if-not-given-yet! option (read-default #'value) (duplicate #'value))
         (read-fields #'rest option))]
      [(:required . rest)
       (begin
         (option-ast-required-set-if-not-given-yet! option #t (duplicate fields))
         (read-fields #'rest option))]
      [(bad . _)
       (violation "unknown field, or field without a value (expected :short :long :arity :type :choices :description :required :default)"
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

  ;; the :default value -> the list of words, as the user would have typed them
  ;;   "3"  => ("3")     3  => ("3")     ("a" "b") => ("a" "b")     () => ()
  (define (read-default form)
    (let ([datum (syntax->datum form)])
      (cond [(default-word datum) => list]
            [(and (list? datum) (for-all default-word datum)) (map default-word datum)]
            [else (violation ":default must be a string, an integer, or a list of them" form)])))

  (define (default-word datum)
    (cond [(string? datum) datum]
          [(and (integer? datum) (exact? datum)) (number->string datum)]
          [else #f]))

  ;; A default is a syntax violation when the words cannot be converted by the type of the option,
  ;; or are not among its choices. The builtin types and the choices can be tried here, the same
  ;; converters the program uses; a procedure of the user can only be run by the program.
  (define (check-default-fits option)
    (let ([words (option-ast-default option)]
          [expression (option-ast-converter option)])
      (when (and words expression)
        (syntax-case expression (builtin-converter make-choice-converter quote)
          [(builtin-converter (quote name))
           (let ([convert (converter-convert (builtin-converter (syntax->datum #'name)))])
             (unless (for-all (lambda (word) (converts? convert word)) words)
               (violation ":default is not a valid value for :type" (option-ast-source option))))]
          [(make-choice-converter (quote choices))
           (let ([convert (converter-convert (make-choice-converter (syntax->datum #'choices)))])
             (unless (for-all (lambda (word) (converts? convert word)) words)
               (violation ":default must be one of the :choices" (option-ast-source option))))]
          [_ #f]))))

  (define (converts? convert word)
    (guard (e [else #f])
      (convert word "default")
      #t))

  (define (read-description form)
    (if (string? (syntax->datum form))
        (syntax->datum form)
        (violation ":description must be a string" form)))

  (define (violation message form)
    (syntax-violation 'define-command-line-options message form)))
