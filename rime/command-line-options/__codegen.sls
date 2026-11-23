#!r6rs
;; Phase 2 of define-command-line-options: AST -> code.
;; It only reads option-ast records, it never looks at the syntax the user wrote.
;; This library is imported `for expand`.
(library (rime command-line-options __codegen)
  (export generate-definition)
  (import (only (rnrs (6)) ... datum->syntax define lambda let list map or syntax with-syntax)
          (only (rime command-line-options __ast)
                make-option-ast make-positional-ast option-ast-converter option-ast-description
                option-ast-long option-ast-max option-ast-metavar option-ast-min
                option-ast-required option-ast-short positional-ast-converter
                positional-ast-description positional-ast-max positional-ast-min
                positional-ast-name)
          (only (rime command-line-options __runtime) parse-command-line))

  ;; parser: the identifier to define; options: list of option-ast;
  ;; positionals: list of positional-ast, in the order of the clauses
  (define (generate-definition parser options positionals)
    (with-syntax ([parser parser]
                  [(spec ...) (map option->spec-expression options)]
                  [(positional ...) (map positional->expression positionals)])
      #'(define parser
          (let ([specs (list spec ...)]
                [positionals (list positional ...)])
            (lambda (arguments)
              (parse-command-line specs arguments positionals))))))

  ;; the same for the positional-ast
  (define (positional->expression positional)
    (with-syntax ([name (datum->syntax #'here (positional-ast-name positional))]
                  [min (datum->syntax #'here (positional-ast-min positional))]
                  [max (datum->syntax #'here (positional-ast-max positional))]
                  [converter (or (positional-ast-converter positional) #'#f)]
                  [description (datum->syntax #'here (positional-ast-description positional))])
      #'(make-positional-ast name min max converter description #f)))

  ;; an expression that builds the same option-ast again, at runtime, for the runtime (__runtime.sls)
  ;; to work with: the values are emitted as they are, and the source is not needed there.
  ;; The converter is emitted as the AST has it, #f (no converter) means the text as it is.
  (define (option->spec-expression option)
    (with-syntax ([short (datum->syntax #'here (option-ast-short option))]
                  [long (datum->syntax #'here (option-ast-long option))]
                  [min (datum->syntax #'here (option-ast-min option))]
                  [max (datum->syntax #'here (option-ast-max option))]
                  [converter (or (option-ast-converter option) #'#f)]
                  [description (datum->syntax #'here (option-ast-description option))]
                  [required (datum->syntax #'here (option-ast-required option))]
                  [metavar (datum->syntax #'here (option-ast-metavar option))])
      #'(make-option-ast short long min max converter description #f required metavar))))
