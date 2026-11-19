#!r6rs
;; The semantic model of a command line option, and the rules that make a set of options valid.
;; It knows nothing about the surface syntax of define-command-line-options, and it does not
;; generate code: phase 1 (__parse.sls) builds these records from syntax, phase 2
;; (__codegen.sls) turns them into code.
(library (rime command-line-options __ast)
  (export make-option-ast
          make-unbound-option-ast
          option-ast-short
          option-ast-long
          option-ast-min
          option-ast-max
          option-ast-converter
          option-ast-description
          option-ast-source
          option-ast-short-set-if-not-given-yet!
          option-ast-long-set-if-not-given-yet!
          option-ast-min-set-if-not-given-yet!
          option-ast-max-set-if-not-given-yet!
          option-ast-converter-set-if-not-given-yet!
          option-ast-description-set-if-not-given-yet!
          unlimited
          unbound
          unbound?
          option-ast-fill-defaults!
          check-options)
  (import (rnrs (6)))

  ;; short       string "-n", or #f
  ;; long        string "--count", or #f; an option has a short name, a long name, or both
  ;; min         non-negative integer, the least number of arguments
  ;; max         non-negative integer, the most number of arguments, `unlimited` when there is no limit
  ;; converter   how to turn the text of an argument into a value, #f when none was given:
  ;;               the expression of a converter procedure, builtin or custom; opaque here,
  ;;               never inspected
  ;; description string
  ;; source      opaque, where the option came from; only handed back to `report` below, #f at runtime
  ;;
  ;; The record is the same at compile time and at runtime: the generated code builds it again
  ;; (__codegen.sls) and the runtime works with it (__runtime.sls).
  ;;
  ;; While a clause is being read, the fields it has not given yet are `unbound`. The reader sets
  ;; them in place, only with the option-ast-<field>-set-if-not-given-yet! procedures below, and
  ;; option-ast-fill-defaults! gives the fields that are still unbound their defaults.
  (define-record-type option-ast
    (fields (mutable short)
            (mutable long)
            (mutable min)
            (mutable max)
            (mutable converter)
            (mutable description)
            source))

  ;; the value of a field that has not been set yet; not #f, which is a value
  (define unbound (list 'unbound))

  (define (unbound? value)
    (eq? value unbound))

  ;; an option that only has its source, everything else is still to be read
  (define (make-unbound-option-ast source)
    (make-option-ast unbound unbound unbound unbound unbound unbound source))

  ;; (option-ast-<field>-set-if-not-given-yet! option value on-duplicate)
  ;; Sets the field in place. If the field was already given, even as #f, it is left alone and
  ;; (on-duplicate) is called instead: the clause gave the same field twice.
  (define (option-ast-short-set-if-not-given-yet! option value on-duplicate)
    (if (unbound? (option-ast-short option))
        (option-ast-short-set! option value)
        (on-duplicate)))

  (define (option-ast-long-set-if-not-given-yet! option value on-duplicate)
    (if (unbound? (option-ast-long option))
        (option-ast-long-set! option value)
        (on-duplicate)))

  (define (option-ast-min-set-if-not-given-yet! option value on-duplicate)
    (if (unbound? (option-ast-min option))
        (option-ast-min-set! option value)
        (on-duplicate)))

  (define (option-ast-max-set-if-not-given-yet! option value on-duplicate)
    (if (unbound? (option-ast-max option))
        (option-ast-max-set! option value)
        (on-duplicate)))

  (define (option-ast-converter-set-if-not-given-yet! option value on-duplicate)
    (if (unbound? (option-ast-converter option))
        (option-ast-converter-set! option value)
        (on-duplicate)))

  (define (option-ast-description-set-if-not-given-yet! option value on-duplicate)
    (if (unbound? (option-ast-description option))
        (option-ast-description-set! option value)
        (on-duplicate)))

  ;; the defaults: no names, exactly one argument, no converter, no description;
  ;; only the fields that are still unbound are set
  (define (option-ast-fill-defaults! option)
    (option-ast-short-set-if-not-given-yet! option #f ignore)
    (option-ast-long-set-if-not-given-yet! option #f ignore)
    (option-ast-min-set-if-not-given-yet! option 1 ignore)
    (option-ast-max-set-if-not-given-yet! option 1 ignore)
    (option-ast-converter-set-if-not-given-yet! option #f ignore)
    (option-ast-description-set-if-not-given-yet! option "" ignore))

  (define (ignore) #f)

  (define reserved-names '("-h" "--help"))

  ;; the max of an option that takes any number of arguments
  (define unlimited (greatest-fixnum))

  ;; (report message option) is called for each broken rule and is expected not to return
  (define (check-options options report)
    (for-each (lambda (option) (check-option option report)) options)
    (check-names options report))

  ;; the rules for one option on its own
  (define (check-option option report)
    (unless (or (option-ast-short option) (option-ast-long option))
      (report "an option needs a :short or a :long name" option))
    (when (and (option-ast-short option) (not (short-name? (option-ast-short option))))
      (report ":short name must look like \"-x\"" option))
    (when (and (option-ast-long option) (not (long-name? (option-ast-long option))))
      (report ":long name must look like \"--name\"" option))
    (when (> (option-ast-min option) (option-ast-max option))
      (report "arity min must not exceed max" option))
    (when (and (flag? option) (option-ast-converter option))
      (report ":type and :choices must not be given when arity is 0" option)))

  ;; names must be unique across all options and must not use the built-in help names
  (define (check-names options report)
    (let loop ([options options] [seen reserved-names])
      (unless (null? options)
        (let* ([option (car options)]
               [names (filter values (list (option-ast-short option) (option-ast-long option)))])
          (for-each
           (lambda (name)
             (when (member name seen)
               (report (if (member name reserved-names)
                           "-h and --help are reserved for the built-in help"
                           "option name is defined twice")
                       option)))
           names)
          (loop (cdr options) (append names seen))))))

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

  (define (well-formed? name)
    (for-all (lambda (c) (not (or (char=? c #\=) (char=? c #\,) (char-whitespace? c))))
             (string->list name))))
