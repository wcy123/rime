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
  ;; intermixed?: whether options may come after positional words
  (define (generate-definition parser options intermixed?)
    (with-syntax ([parser parser]
                  [(spec ...) (map option->spec-expression options)]
                  [intermixed? (datum->syntax #'here intermixed?)])
      #'(define parser
          (let ([specs (list spec ...)])
            (lambda (arguments)
              (parse-command-line specs arguments default-on-help intermixed?))))))

  ;; an expression that builds the same option-ast again, at runtime, for the runtime (__runtime.sls)
  ;; to work with: the values are emitted as they are, and the source is not needed there.
  ;; The converter is emitted as the AST has it, #f (no converter) means the text as it is.
  (define (option->spec-expression option)
    (with-syntax ([short (datum->syntax #'here (option-ast-short option))]
                  [long (datum->syntax #'here (option-ast-long option))]
                  [min (datum->syntax #'here (option-ast-min option))]
                  [max (datum->syntax #'here (option-ast-max option))]
                  [converter (or (option-ast-converter option) #'#f)]
                  [description (datum->syntax #'here (option-ast-description option))])
      #'(make-option-ast short long min max converter description #f))))
