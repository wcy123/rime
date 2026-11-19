#!r6rs
;; Phase 2 of define-command-line-options: AST -> code.
;; It only reads option-ast records, it never looks at the syntax the user wrote.
;; This library is imported `for expand`.
(library (rime command-line-options __codegen)
  (export generate-definition)
  (import (rnrs (6))
          (rime command-line-options __ast)
          (rime command-line-options __runtime))

  ;; parser: the identifier to define; options: list of option-ast;
  ;; positionals: list of positional-ast, in the order of the clauses
  (define (generate-definition parser options positionals)
    (with-syntax ([parser parser]
                  [(spec ...) (map option->spec-expression options)]
                  [(positional ...) (map positional->expression positionals)])
      #'(define parser
          (let ([specs (list spec ...)])
            (lambda (arguments)
              (parse-command-line specs arguments default-on-help (list positional ...)))))))

  ;; the same for the positional-ast
  (define (positional->expression positional)
    (spec-expression
     #'positional-spec
     (list (spec-field 'name (positional-ast-name positional) never)
           (spec-field 'min (positional-ast-min positional) 1)
           (spec-field 'max (positional-ast-max positional) 1)
           (spec-field 'converter (positional-ast-converter positional) #f values)
           (spec-field 'description (positional-ast-description positional) ""))))

  ;; an expression that builds the same option-ast again, at runtime, for the runtime (__runtime.sls)
  ;; to work with: the values are emitted as they are, and the source is not needed there.
  ;; The converter is emitted as the AST has it, #f (no converter) means the text as it is.
  ;; Only the fields that are not the default are written, so the generated code does not change
  ;; when a field is added to the record:
  ;;
  ;;   (option-spec [short "-n"] [long "--count"] [converter (builtin-converter 'int)])
  (define (option->spec-expression option)
    (spec-expression
     #'option-spec
     (list (spec-field 'short (option-ast-short option) #f)
           (spec-field 'long (option-ast-long option) #f)
           (spec-field 'min (option-ast-min option) 1)
           (spec-field 'max (option-ast-max option) 1)
           (spec-field 'converter (option-ast-converter option) #f values)
           (spec-field 'description (option-ast-description option) "")
           (spec-field 'required (option-ast-required option) #f))))

  ;; (spec-field name value default [->syntax]) => (name . value-syntax), or #f when the value is the
  ;; default and need not be written. ->syntax turns the value into syntax, a datum by default.
  (define spec-field
    (case-lambda
      [(name value default)
       (spec-field name value default (lambda (datum) (datum->syntax #'here datum)))]
      [(name value default ->syntax)
       (and (not (equal? value default))
            (cons (datum->syntax #'here name) (->syntax value)))]))

  ;; a default that no value is equal to, for a field that is always written
  (define never (list 'never))

  ;; (spec-expression maker fields) => #'(maker [field value] ...), for the fields that are written
  (define (spec-expression maker fields)
    (with-syntax ([maker maker]
                  [([field value] ...)
                   (map (lambda (field) (list (car field) (cdr field))) (filter values fields))])
      #'(maker [field value] ...))))
