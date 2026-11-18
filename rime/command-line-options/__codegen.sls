#!r6rs
;; Phase 2 of define-command-line-options: AST -> code.
;; It only reads option-ast records, it never looks at the syntax the user wrote.
;; This library is imported `for expand`.
(library (rime command-line-options __codegen)
  (export generate-definition)
  (import (rnrs (6))
          (rime command-line-options __ast)
          (rime command-line-options __parser))

  (define (converter-for option)
    (case (or (option-ast-type option) 'string)
      [(string) #'convert-string]
      [(int) #'convert-int]
      [(float) #'convert-float]
      [(bool) #'convert-bool]
      [else (option-ast-converter option)]))

  ;; the type name is only shown in the usage text
  (define (type-name-for option)
    (let ([type (or (option-ast-type option) 'string)])
      (and (not (eq? type 'custom)) type)))

  ;; an expression that makes the option-spec the runtime (__parser.sls) works with
  (define (option->spec-expression option)
    (with-syntax ([short (datum->syntax #'here (option-ast-short option))]
                  [long (datum->syntax #'here (option-ast-long option))]
                  [min (datum->syntax #'here (option-ast-min option))]
                  [max (if (option-ast-max option)
                           (datum->syntax #'here (option-ast-max option))
                           #'(greatest-fixnum))]
                  [type-name (datum->syntax #'here (type-name-for option))]
                  [converter (converter-for option)]
                  [description (datum->syntax #'here (option-ast-description option))])
      #'(make-option-spec short long min max 'type-name converter description)))

  ;; parser: the identifier to define; options: list of option-ast
  (define (generate-definition parser options)
    (with-syntax ([parser parser]
                  [(spec ...) (map option->spec-expression options)])
      #'(define parser
          (let ([specs (list spec ...)])
            (lambda (arguments)
              (parse-command-line specs arguments)))))))
