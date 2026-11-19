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
          option-ast-required
          option-ast-short-set-if-not-given-yet!
          option-ast-long-set-if-not-given-yet!
          option-ast-min-set-if-not-given-yet!
          option-ast-max-set-if-not-given-yet!
          option-ast-converter-set-if-not-given-yet!
          option-ast-description-set-if-not-given-yet!
          option-ast-required-set-if-not-given-yet!
          option-ast?
          option-lookup-names
          make-positional-ast
          make-unbound-positional-ast
          positional-ast?
          positional-ast-name
          positional-ast-min
          positional-ast-max
          positional-ast-converter
          positional-ast-description
          positional-ast-source
          positional-ast-name-set-if-not-given-yet!
          positional-ast-min-set-if-not-given-yet!
          positional-ast-max-set-if-not-given-yet!
          positional-ast-converter-set-if-not-given-yet!
          positional-ast-description-set-if-not-given-yet!
          positional-ast-fill-defaults!
          unlimited
          unbound
          unbound?
          option-ast-fill-defaults!
          check-options
          check-positionals)
  (import (rnrs (6)))

  ;; short       string "-n", or #f
  ;; long        string "--count", or #f; an option has a short name, a long name, or both
  ;; min         non-negative integer, the least number of arguments
  ;; max         non-negative integer, the most number of arguments, `unlimited` when there is no limit
  ;; converter   how to turn the text of an argument into a value, #f when none was given:
  ;;               an expression whose value is a converter object (see __runtime.sls) at compile
  ;;               time, the converter object itself at runtime; opaque here, never inspected
  ;; description string
  ;; source      opaque, where the option came from; only handed back to `report` below, #f at runtime
  ;; required    boolean, #t when it is an error that the option is absent; never #t for a flag
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
            source
            (mutable required)))

  ;; the value of a field that has not been set yet; not #f, which is a value
  (define unbound (list 'unbound))

  (define (unbound? value)
    (eq? value unbound))

  ;; The :positional clause: the words of the command line that are not options.
  ;; name         string, what the program reads them by, and what the usage shows: <name>
  ;; min, max     how many words, as for an option; `unlimited` when there is no limit
  ;; converter    as for an option
  ;; description  string
  ;; source       as for an option
  ;; While the clause is being read the fields it has not given yet are `unbound`, as for an option.
  (define-record-type positional-ast
    (fields (mutable name)
            (mutable min)
            (mutable max)
            (mutable converter)
            (mutable description)
            source))

  (define (make-unbound-positional-ast source)
    (make-positional-ast unbound unbound unbound unbound unbound source))

  (define (positional-ast-name-set-if-not-given-yet! positional value on-duplicate)
    (if (unbound? (positional-ast-name positional))
        (positional-ast-name-set! positional value)
        (on-duplicate)))

  (define (positional-ast-min-set-if-not-given-yet! positional value on-duplicate)
    (if (unbound? (positional-ast-min positional))
        (positional-ast-min-set! positional value)
        (on-duplicate)))

  (define (positional-ast-max-set-if-not-given-yet! positional value on-duplicate)
    (if (unbound? (positional-ast-max positional))
        (positional-ast-max-set! positional value)
        (on-duplicate)))

  (define (positional-ast-converter-set-if-not-given-yet! positional value on-duplicate)
    (if (unbound? (positional-ast-converter positional))
        (positional-ast-converter-set! positional value)
        (on-duplicate)))

  (define (positional-ast-description-set-if-not-given-yet! positional value on-duplicate)
    (if (unbound? (positional-ast-description positional))
        (positional-ast-description-set! positional value)
        (on-duplicate)))

  ;; the defaults: exactly one word, no converter, no description; the name is always given
  (define (positional-ast-fill-defaults! positional)
    (positional-ast-min-set-if-not-given-yet! positional 1 ignore)
    (positional-ast-max-set-if-not-given-yet! positional 1 ignore)
    (positional-ast-converter-set-if-not-given-yet! positional #f ignore)
    (positional-ast-description-set-if-not-given-yet! positional "" ignore))

  ;; an option that only has its source, everything else is still to be read
  (define (make-unbound-option-ast source)
    (make-option-ast unbound unbound unbound unbound unbound unbound source unbound))

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

  (define (option-ast-required-set-if-not-given-yet! option value on-duplicate)
    (if (unbound? (option-ast-required option))
        (option-ast-required-set! option value)
        (on-duplicate)))

  ;; the defaults: no names, exactly one argument, no converter, no description, not required;
  ;; only the fields that are still unbound are set
  (define (option-ast-fill-defaults! option)
    (option-ast-short-set-if-not-given-yet! option #f ignore)
    (option-ast-long-set-if-not-given-yet! option #f ignore)
    (option-ast-min-set-if-not-given-yet! option 1 ignore)
    (option-ast-max-set-if-not-given-yet! option 1 ignore)
    (option-ast-converter-set-if-not-given-yet! option #f ignore)
    (option-ast-description-set-if-not-given-yet! option "" ignore)
    (option-ast-required-set-if-not-given-yet! option #f ignore))

  (define (ignore) #f)

  (define reserved-names '("h" "help"))

  ;; the max of an option that takes any number of arguments
  (define unlimited (greatest-fixnum))

  ;; (report message source) is called for each broken rule and is expected not to return
  (define (check-options options report)
    (for-each (lambda (option) (check-option option report)) options)
    (check-names options report))

  ;; the rules for one option on its own
  (define (check-option option report)
    (define (problem message) (report message (option-ast-source option)))
    (unless (or (option-ast-short option) (option-ast-long option))
      (problem "an option needs a :short or a :long name"))
    (when (and (option-ast-short option) (not (short-name? (option-ast-short option))))
      (problem ":short name must look like \"-x\""))
    (when (and (option-ast-long option) (not (long-name? (option-ast-long option))))
      (problem ":long name must look like \"--name\""))
    (when (> (option-ast-min option) (option-ast-max option))
      (problem "arity min must not exceed max"))
    (when (and (flag? option) (option-ast-converter option))
      (problem ":type and :choices must not be given when arity is 0"))
    (when (and (flag? option) (option-ast-required option))
      (problem "a flag (arity 0) cannot be :required")))

  ;; The names the program uses to read an option are the names without their dashes. They must be
  ;; unique across all options, and must not be the names of the built-in help.
  (define (check-names options report)
    (let loop ([options options] [seen reserved-names])
      (unless (null? options)
        (let* ([option (car options)]
               [names (option-lookup-names option)])
          (for-each
           (lambda (name)
             (when (member name seen)
               (report (if (member name reserved-names)
                           reserved-message
                           "option name is defined twice")
                       (option-ast-source option))))
           names)
          (loop (cdr options) (append names seen))))))

  (define reserved-message "-h and --help are reserved for the built-in help")

  ;; the names to read the option by: the short name without its dash, the long name without its
  ;; two dashes, each only once
  ;;   (option-lookup-names -n --count)    => ("n" "count")
  ;;   (option-lookup-names -emit --emit)  => ("emit")
  (define (option-lookup-names option)
    (let ([short (and (option-ast-short option) (drop-dashes (option-ast-short option) 1))]
          [long (and (option-ast-long option) (drop-dashes (option-ast-long option) 2))])
      (cond [(and short long) (if (string=? short long) (list short) (list short long))]
            [short (list short)]
            [long (list long)]
            [else '()])))

  (define (drop-dashes name count)
    (let loop ([i 0])
      (if (and (< i count) (< i (string-length name)) (char=? (string-ref name i) #\-))
          (loop (+ i 1))
          (substring name i (string-length name)))))

  ;; the rules for the :positional clauses, in the order they were written, and for how their names
  ;; relate to the options: the names are unique, and at most one positional takes a variable number
  ;; of words (min < max), so that the words can only be shared out in one way
  (define (check-positionals positionals options report)
    (for-each (lambda (positional) (check-positional positional options report)) positionals)
    (let loop ([rest positionals] [names '()] [variable-seen? #f])
      (unless (null? rest)
        (let* ([positional (car rest)]
               [variable? (not (eqv? (positional-ast-min positional) (positional-ast-max positional)))])
          (when (member (positional-ast-name positional) names)
            (report "positional name is defined twice" (positional-ast-source positional)))
          (when (and variable? variable-seen?)
            (report "only one positional argument can take a variable number of words, the others need an exact arity"
                    (positional-ast-source positional)))
          (loop (cdr rest)
                (cons (positional-ast-name positional) names)
                (or variable? variable-seen?))))))

  (define (check-positional positional options report)
    (define (problem message) (report message (positional-ast-source positional)))
    (let ([name (positional-ast-name positional)])
      (when (and (> (string-length name) 0) (char=? (string-ref name 0) #\-))
        (problem "a positional name must not start with -"))
      (when (or (string=? name "") (not (well-formed? name)))
        (problem "a positional name must not be empty or contain =, , or whitespace"))
      (cond [(member name reserved-names) (problem reserved-message)]
            [(exists (lambda (option) (member name (option-lookup-names option))) options)
             (problem "positional name clashes with an option name")]))
    (when (> (positional-ast-min positional) (positional-ast-max positional))
      (problem "arity min must not exceed max"))
    (when (eqv? 0 (positional-ast-max positional))
      (problem "a positional argument must take at least one word, arity 0 is not allowed")))

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
