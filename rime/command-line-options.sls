#!r6rs
(library (rime command-line-options)
  (export define-command-line-options
          parse-or-exit command-line-error? command-line-error-usage
          :short :long :arity :type :choices :description :required :positional :metavar)
  (import (only (rnrs (6)) define-syntax)
          (for (only (rnrs (6))
                     ... _ identifier? lambda let-values quote syntax syntax-case syntax-violation)
               expand)
          (for (only (rime command-line-options __parse) parse-options) expand)
          (for (only (rime command-line-options __codegen) generate-definition) expand)
          (only (rime command-line-options __keywords)
                :arity :choices :description :long :metavar :positional :required :short :type)
          (only (rime command-line-options __runtime)
                command-line-error-usage command-line-error? parse-or-exit))

  ;; (define-command-line-options parser clause ...)
  ;;   clause = [field ...]
  ;;   field  = :short name | :long name | :arity n | (min max) | (min +) | :type type
  ;;          | :choices (literal ...) | :description "text" | :required
  ;;   a clause with :positional name describes positional words: [:positional name field ...]
  ;;   name   = "-x" or -x, "--long" or --long; a clause needs a :short or a :long
  ;; defines (parser arguments) => accessor procedure; (option "help") is #t when -h was given and
  ;; (option "usage") is the usage text; (parse-or-exit parser arguments) prints the usage and exits
  ;; with 0 at -h, and exits with 2 on a wrong command line; a wrong command line is a
  ;; command-line-error? condition, which has the usage
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
