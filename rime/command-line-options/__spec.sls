#!r6rs
;; A constructor that takes the fields of a record by their names, in any order, with defaults:
;;
;;   (define-field-constructor option-spec make-option-ast (short #f) (min 1) (converter #f) ...)
;;
;;   (option-spec [converter 'int] [short "-n"])  =>  (make-option-ast "-n" <default> 1 <default> 'int ...)
;;
;; so that adding a field to a record means one more entry in the definition above, and no change to
;; the code that builds the record. A field without a default, `(name)`, has to be given.
;; The values are expressions, they are evaluated like the arguments of a procedure.
;; Mistakes are syntax violations at the use: an unknown field, a field given twice, a clause that
;; is not [field value], a missing field that has no default.
(library (rime command-line-options __spec)
  (export define-field-constructor
          assemble-spec)
  (import (rnrs (6))
          (for (rnrs (6)) expand))

  ;; (define-field-constructor name make (field default ...) ...)
  ;;   name      the macro to define
  ;;   make      the procedure that takes the values of all the fields, in the order of the fields below
  ;;   (field default)  a field with a default, (field) a field that has none
  (define-syntax define-field-constructor
    (lambda (stx)
      (syntax-case stx ()
        [(_ name make (field default ...) ...)
         #'(define-syntax name
             (lambda (use)
               (syntax-case use ()
                 [(_ . clauses)
                  (assemble-spec use #'make '(field ...) (list (list #'default ...) ...) #'clauses)])))])))

  ;; (assemble-spec use make names defaults clauses) => the syntax of (make value ...)
  ;; This runs when a use of the macro is expanded.
  ;;   use       the whole use, for the error messages
  ;;   names     the field names, as symbols, in the order of the arguments of `make`
  ;;   defaults  for each field, the list of its default as syntax, or () when it has none
  ;;   clauses   the syntax of the [field value] ... of the use
  (define (assemble-spec use make names defaults clauses)
    (let ([given (read-fields use clauses names)])
      (with-syntax ([make make]
                    [(value ...)
                     (map (lambda (name default)
                            (cond [(assq name given) => cdr]
                                  [(pair? default) (car default)]
                                  [else (syntax-violation
                                         #f (string-append "missing field " (symbol->string name)) use)]))
                          names defaults)])
        #'(make value ...))))

  ;; the clauses [field value] ... -> list of (name . value-syntax), checked
  (define (read-fields use clauses names)
    (syntax-case clauses ()
      [() '()]
      [([field value] . rest)
       (identifier? #'field)
       (let ([name (syntax->datum #'field)]
             [others (read-fields use #'rest names)])
         (unless (memq name names)
           (syntax-violation #f "unknown field" use #'field))
         (when (assq name others)
           (syntax-violation #f "field given twice" use #'field))
         (cons (cons name #'value) others))]
      [(bad . _)
       (syntax-violation #f "a field is written [name value]" use #'bad)]
      [_ (syntax-violation #f "a field is written [name value]" use)])))
