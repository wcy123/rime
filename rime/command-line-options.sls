#!r6rs
(library (rime command-line-options)
  (export define-command-line-options
          :long :arity :type :description)
  (import (rnrs (6))
          (for (rnrs (6)) expand)
          (for (rime command-line-options __parse) expand)
          (for (rime command-line-options __codegen) expand)
          (rime syntax __define-auxiliary-syntax))

  ;; the field keywords of a clause, exported so that they are bound and match by binding
  (define-auxiliary-syntax :long :arity :type :description)

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

  ;; (collect-clauses parser (spec ...) clause ...)
  ;;   spec   = (name (key value) ...)  a clause that is already processed
  ;;   clause = [name field ...]        a clause as the user wrote it
  ;; Loops over the clauses. Takes the first unprocessed clause and hands it to collect-fields, which
  ;; calls back here with the finished spec added. With no clause left, expands to
  ;; (finish-definition parser spec ...).
  ;;
  ;;   (collect-clauses p () ["-v" :arity 0] ["-n" :type int])
  ;;   => (collect-fields p () (["-n" :type int]) "-v" () :arity 0)
  ;;   => (collect-clauses p (("-v" (:arity 0))) ["-n" :type int])
  ;;   => ...
  ;;   => (finish-definition p ("-v" (:arity 0)) ("-n" (:type int)))
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

  ;; (collect-fields parser (spec ...) (clause ...) name (pair ...) field ...)
  ;;   pair  = (key value)       a field that is already processed
  ;;   field = :key value        a field as the user wrote it
  ;;   (clause ...) are the clauses still waiting in collect-clauses.
  ;; Loops over the fields of one clause, moving each `:key value` into the pairs as `(:key value)`.
  ;; Anything but one of the four keys followed by a value is a syntax error. With no field left,
  ;; hands the finished spec (name pair ...) back to collect-clauses.
  ;;
  ;;   (collect-fields p () () "-n" () :long "--count" :type int)
  ;;   => (collect-fields p () () "-n" ((:long "--count")) :type int)
  ;;   => (collect-fields p () () "-n" ((:long "--count") (:type int)))
  ;;   => (collect-clauses p (("-n" (:long "--count") (:type int))))
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

  ;; (finish-definition parser spec ...)  spec = (name (key value) ...)
  ;; Phase 1 (__parse.sls) turns the specs into option-ast records, which are checked;
  ;; phase 2 (__codegen.sls) generates the definition of `parser` from the records.
  (define-syntax finish-definition
    (lambda (stx)
      (syntax-case stx ()
        [(_ parser spec ...)
         (generate-definition #'parser (parse-options (syntax-list #'(spec ...))))]))))
