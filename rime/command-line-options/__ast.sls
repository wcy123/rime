#!r6rs
;; The semantic model of a command line option, and the rules that make a set of options valid.
;; It knows nothing about the surface syntax of define-command-line-options, and it does not
;; generate code: phase 1 (__parse.sls) builds these records from syntax, phase 2
;; (__codegen.sls) turns them into code.
(library (rime command-line-options __ast)
  (export make-option-ast
          option-ast-short
          option-ast-long
          option-ast-min
          option-ast-max
          option-ast-type
          option-ast-converter
          option-ast-description
          option-ast-source
          check-options)
  (import (rnrs (6)))

  ;; short       string, "-n"
  ;; long        string "--count", or #f
  ;; min         non-negative integer, the least number of arguments
  ;; max         non-negative integer, the most number of arguments, #f when unbounded
  ;; type        #f when none was given, 'string 'int 'float 'bool, or 'custom
  ;; converter   for type 'custom, the procedure expression; opaque here, never inspected; else #f
  ;; description string
  ;; source      opaque, where the option came from; only handed back to `report` below
  (define-record-type option-ast
    (fields short long min max type converter description source))

  (define reserved-names '("-h" "--help"))

  (define (well-formed? name)
    (for-all (lambda (c) (not (or (char=? c #\=) (char=? c #\,) (char-whitespace? c))))
             (string->list name)))

  (define (short-name? name)
    (and (> (string-length name) 1)
         (char=? (string-ref name 0) #\-)
         (not (char=? (string-ref name 1) #\-))
         (well-formed? name)))

  (define (long-name? name)
    (and (> (string-length name) 2)
         (string=? (substring name 0 2) "--")
         (not (char=? (string-ref name 2) #\-))
         (well-formed? name)))

  (define (flag? option)
    (and (eqv? 0 (option-ast-min option)) (eqv? 0 (option-ast-max option))))

  (define (check-option option report)
    (unless (short-name? (option-ast-short option))
      (report "option name must look like \"-x\"" option))
    (when (and (option-ast-long option) (not (long-name? (option-ast-long option))))
      (report ":long name must look like \"--name\"" option))
    (when (and (option-ast-max option) (> (option-ast-min option) (option-ast-max option)))
      (report "arity min must not exceed max" option))
    (when (and (flag? option) (option-ast-type option))
      (report ":type must not be given when arity is 0" option)))

  ;; names must be unique across all options and must not use the built-in help names
  (define (check-names options report)
    (let loop ([options options] [seen reserved-names])
      (unless (null? options)
        (let* ([option (car options)]
               [names (if (option-ast-long option)
                          (list (option-ast-short option) (option-ast-long option))
                          (list (option-ast-short option)))])
          (for-each
           (lambda (name)
             (when (member name seen)
               (report (if (member name reserved-names)
                           "-h and --help are reserved for the built-in help"
                           "option name is defined twice")
                       option)))
           names)
          (loop (cdr options) (append names seen))))))

  ;; (report message option) is called for each broken rule and is expected not to return
  (define (check-options options report)
    (for-each (lambda (option) (check-option option report)) options)
    (check-names options report)))
