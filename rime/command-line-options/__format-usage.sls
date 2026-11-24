#!r6rs
;; The usage text of a parser: "Usage: prog [options]", the arguments and the options, with the
;; descriptions lined up. It reads the option-ast and positional-ast records (see __ast.sls).
(library (rime command-line-options __format-usage)
  (export format-usage)
  (import (only (rnrs (6))
                + - = and append apply car cdr char=? cond cons define else if lambda let let* list
                make-string map max null? quote reverse string-append string-length string-ref
                string=? substring)
          (only (rime loop) :collect :repeat loop)
          (only (rime string __string-join) string-join)
          (only (rime command-line-options __converter) converter-label)
          (only (rime command-line-options __ast)
                option-ast-converter option-ast-description option-ast-long option-ast-max
                option-ast-metavar option-ast-min option-ast-short positional-ast-description
                positional-ast-max positional-ast-min positional-ast-name unlimited))

  ;; (format-usage specs program positionals) => the usage text
  ;;   specs: the options to show, in order; the caller adds the built-in -h and --help
  (define (format-usage specs program positionals)
    (string-append
     "Usage: " program " [options]"
     (if (null? positionals)
         ""
         (string-append " [--] " (string-join " " (map positional-placeholder positionals))))
     "\n"
     (if (null? positionals)
         ""
         (string-append
          "\n"
          "Arguments:\n"
          (format-rows (map (lambda (positional)
                              (cons (positional-placeholder positional)
                                    (positional-ast-description positional)))
                            positionals))))
     "\n"
     "Options:\n"
     (format-rows (map (lambda (spec) (cons (flags spec) (option-ast-description spec)))
                       specs))))

  ;; rows is a list of (label . description); the descriptions line up, a multi-line description is
  ;; indented under its first line
  (define (format-rows rows)
    (let* ([width (apply max (map (lambda (row) (string-length (car row))) rows))]
           [indent 2]
           [gap 2]
           [column (+ indent width gap)])
      (define (format-row row)
        (let ([label (car row)]
              [lines (split-lines (cdr row))])
          (string-append
           (spaces indent)
           (if (string=? (car lines) "")
               label
               (string-append label
                              (spaces (+ (- width (string-length label)) gap))
                              (car lines)))
           "\n"
           (apply string-append
                  (map (lambda (line) (string-append (spaces column) line "\n"))
                       (cdr lines))))))
      (define (spaces n) (make-string n #\space))
      (apply string-append (map format-row rows))))

  ;; "-n, --count <int>"; a long name alone is indented so that long names line up
  (define (flags spec)
    (let ([names (cond [(and (option-ast-short spec) (option-ast-long spec))
                        (string-append (option-ast-short spec) ", " (option-ast-long spec))]
                       [(option-ast-short spec) (option-ast-short spec)]
                       [else (string-append "    " (option-ast-long spec))])]
          [arguments (placeholder spec)])
      (if (string=? arguments "")
          names
          (string-append names " " arguments))))

  ;; "<int>", "{json,text}", or the <metavar> when the option has one
  (define (placeholder spec)
    (placeholder-of (option-ast-min spec) (option-ast-max spec)
                    (if (option-ast-metavar spec)
                        (string-append "<" (option-ast-metavar spec) ">")
                        (converter-label-or-string (option-ast-converter spec)))))

  ;; the label of a converter; no converter means the text as it is
  (define (converter-label-or-string converter)
    (if converter (converter-label converter) "<string>"))

  ;; "<file>...", "[<file>]": how many words, shown with the name of the positional
  (define (positional-placeholder positional)
    (placeholder-of (positional-ast-min positional) (positional-ast-max positional)
                    (string-append "<" (positional-ast-name positional) ">")))

  ;; the placeholder of `arg` for min to max arguments
  (define (placeholder-of min max arg)
    (let ([mandatory (repeat min arg)])
      (string-join
       " "
       (cond
        [(and (= max unlimited) (= min 0))
         (list (string-append "[" arg "...]"))]
        [(= max unlimited)
         (append (repeat (- min 1) arg) (list (string-append arg "...")))]
        [else
         (append mandatory (repeat (- max min) (string-append "[" arg "]")))]))))

  (define (repeat n x)
    (loop :repeat n :collect x))

  (define (split-lines string)
    (let loop ([i 0] [start 0] [lines '()])
      (cond [(= i (string-length string))
             (reverse (cons (substring string start i) lines))]
            [(char=? (string-ref string i) #\newline)
             (loop (+ i 1) (+ i 1) (cons (substring string start i) lines))]
            [else (loop (+ i 1) start lines)])))
)
