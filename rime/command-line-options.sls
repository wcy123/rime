#!r6rs
(library (rime command-line-options)
  (export define-command-line-options
          parse-or-exit command-line-error? command-line-error-usage
          :short :long :arity :type :choices :description :required :positional)
  (import (rnrs (6))
          (for (rnrs (6)) expand)
          (for (rime command-line-options __parse) expand)
          (for (rime command-line-options __codegen) expand)
          (rime command-line-options __keywords)
          (only (rime command-line-options __runtime)
                parse-or-exit command-line-error? command-line-error-usage))

  ;; (define-command-line-options parser clause ...)
  ;;   clause = [field ...]
  ;;   field  = :short name | :long name | :arity n | (min max) | (min +) | :type type
  ;;          | :choices (literal ...) | :description "text" | :required
  ;;   a clause with :positional name describes positional words: [:positional name field ...]
  ;;   name   = "-x" or -x, "--long" or --long; a clause needs a :short or a :long
  ;; defines (parser arguments [on-help]) => accessor procedure; on-help takes the usage text and
  ;; replaces the printing and the (exit 0) of -h; (parse-or-exit parser arguments) exits with 2 on a
  ;; wrong command line; a wrong command line is a command-line-error? condition, which has the usage
  ;;
  ;; Reading and writing are separate steps: the clauses are first read into option-ast records
  ;; (__parse.sls), then the definition is written from the records (__codegen.sls).
  (define-syntax define-command-line-options
    (lambda (stx)
      (syntax-case stx ()
        [(_ parser clause ...)
         (identifier? #'parser)
         (let-values ([(options positionals) (parse-options #'(clause ...))])
           (generate-definition #'parser options positionals))]
        [_ (syntax-violation 'define-command-line-options
                             "expected (define-command-line-options name clause ...)"
                             stx)]))))
