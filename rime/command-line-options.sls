#!r6rs
(library (rime command-line-options)
  (export define-command-line-options
          :short :long :arity :type :choices :description :required)
  (import (rnrs (6))
          (for (rnrs (6)) expand)
          (for (rime command-line-options __parse) expand)
          (for (rime command-line-options __codegen) expand)
          (rime command-line-options __keywords))

  ;; (define-command-line-options parser clause ...)
  ;;   clause = [field ...]
  ;;   field  = :short name | :long name | :arity n | (min max) | (min +) | :type type
  ;;          | :choices (literal ...) | :description "text" | :required
  ;;   name   = "-x" or -x, "--long" or --long; a clause needs a :short or a :long
  ;; defines (parser arguments) => accessor procedure
  ;;
  ;; Reading and writing are separate steps: the clauses are first read into option-ast records
  ;; (__parse.sls), then the definition is written from the records (__codegen.sls).
  (define-syntax define-command-line-options
    (lambda (stx)
      (syntax-case stx ()
        [(_ parser clause ...)
         (identifier? #'parser)
         (let ([options (parse-options #'(clause ...))])
           (generate-definition #'parser options))]
        [_ (syntax-violation 'define-command-line-options
                             "expected (define-command-line-options name clause ...)"
                             stx)]))))
