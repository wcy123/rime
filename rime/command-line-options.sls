#!r6rs
(library (rime command-line-options)
  (export define-command-line-options)
  (import (rnrs (6))
          (for (rnrs (6)) expand)
          (for (rime command-line-options __ast) expand)
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

  ;; Phase 1: parse every clause into an option-ast record and check the options together.
  ;; Phase 2: generate the definition from the records.
  (define-syntax finish-definition
    (lambda (stx)
      (define (converter type)
        (case type
          [(string) #'convert-string]
          [(int) #'convert-int]
          [(float) #'convert-float]
          [(bool) #'convert-bool]
          [else type]))

      (define (option->spec-expression option)
        (let ([type (option-ast-type option)])
          (with-syntax ([short (datum->syntax #'here (option-ast-short option))]
                        [long (datum->syntax #'here (option-ast-long option))]
                        [min (datum->syntax #'here (option-ast-min option))]
                        [max (if (option-ast-max option)
                                 (datum->syntax #'here (option-ast-max option))
                                 #'(greatest-fixnum))]
                        [type-name (datum->syntax #'here (and (symbol? type) type))]
                        [converter (converter type)]
                        [description (datum->syntax #'here (option-ast-description option))])
            #'(make-option-spec short long min max 'type-name converter description))))

      (syntax-case stx ()
        [(_ parser clause ...)
         (let ([options (map parse-option (syntax-list #'(clause ...)))])
           (check-options options)
           (with-syntax ([(spec ...) (map option->spec-expression options)])
             #'(define parser
                 (let ([specs (list spec ...)])
                   (lambda (arguments)
                     (parse-command-line specs arguments))))))]))))
