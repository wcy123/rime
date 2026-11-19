#!r6rs
;; The runtime of define-command-line-options: what runs in the user's program. Parses the
;; command line against the options (option-ast records, see __ast.sls), builds the accessor,
;; and prints the usage.
(library (rime command-line-options __runtime)
  (export parse-command-line
          format-usage
          program-name
          default-on-help
          builtin-converters
          builtin-converter
          make-choice-converter
          procedure->converter
          make-converter
          converter-label
          converter-convert
          convert-bool
          convert-int
          convert-float
          convert-string)
  (import (rnrs (6))
          (rime command-line-options __ast))

  (define help-spec
    (make-option-ast "-h" "--help" 0 0 #f "show this help message and exit" #f #f))

  ;; ========================================
  ;; parsing the command line
  ;; ========================================

  ;; (parse-command-line specs args [on-help [positionals]]) => the accessor
  ;;   positionals: list of positional-ast, '() when the command line takes no positional words
  (define parse-command-line
    (case-lambda
      [(specs args) (parse-command-line specs args default-on-help '())]
      [(specs args on-help) (parse-command-line specs args on-help '())]
      [(specs args on-help positionals)
       (let ([table (make-eq-hashtable)])   ; option -> the converted arguments

         (define help-asked? #f)

         ;; returns the positional arguments; options and positional words may come in any order
         (define (scan tokens)
           (cond
            [(null? tokens) '()]
            [(string=? (car tokens) "--") (cdr tokens)]
            [(member (car tokens) '("-h" "--help"))
             (set! help-asked? #t)
             (on-help (format-usage specs (program-name) positionals))
             '()]
            [(option-like? (car tokens))
             (scan (parse-option (car tokens) (cdr tokens)))]
            [else (cons (unescape (car tokens)) (scan (cdr tokens)))]))

         ;; token is "-x", "--long" or "-x=a,b" / "--long=a,b"; returns the unconsumed tokens
         (define (parse-option token rest)
           (let* ([equals (index-of #\= token)]
                  [name (if equals (substring token 0 equals) token)]
                  [spec (or (find-spec-by-token specs name) (fail "unknown option" token))])
             (cond
              [equals
               (let ([items (split-commas (substring token (+ equals 1) (string-length token)))])
                 (cond [(= 0 (option-ast-max spec))
                        (fail "option does not take arguments" name)]
                       [(< (length items) (option-ast-min spec))
                        (fail "too few arguments for option" name)]
                       [(> (length items) (option-ast-max spec))
                        (fail "too many arguments for option" name)])
                 (store! spec name items)
                 rest)]
              [else
               (let-values ([(items remaining) (take-arguments rest (option-ast-max spec))])
                 (when (< (length items) (option-ast-min spec))
                   (fail "too few arguments for option" name))
                 (store! spec name items)
                 remaining)])))

         ;; returns (values taken remaining), taking at most max tokens
         (define (take-arguments tokens max)
           (let loop ([tokens tokens] [count 0] [taken '()])
             (if (and (< count max) (pair? tokens) (argument-token? (car tokens)))
                 (loop (cdr tokens) (+ count 1) (cons (car tokens) taken))
                 (values (reverse taken) tokens))))

         (define (argument-token? token)
           (not (or (string=? token "--") (option-like? token))))

         (define (store! spec name items)
           (hashtable-set! table spec (convert-items spec name items)))

         ;; the converter reports its own failure, it is given the name of the option for that
         (define (convert-items spec name items)
           (let ([convert (converter-convert (spec-converter spec))])
             (map (lambda (item) (convert (unescape item) name)) items)))

         ;; The words that are not options are shared out to the positionals, in order. Each gets as
         ;; many as its minimum, and the one that takes a variable number of words (there is at most
         ;; one) also gets the words that are left over. Without a positional they are an error.
         (define (take-positional-words! words)
           (if (null? positionals)
               (when (pair? words)
                 (apply fail "unexpected positional argument" words))
               (let* ([count (length words)]
                      [minimum (sum (map positional-ast-min positionals))]
                      [maximum (sum (map positional-ast-max positionals))])
                 (check-enough-words positionals count)
                 (when (> count maximum)
                   (apply fail "too many positional arguments" (list-tail words maximum)))
                 (let loop ([positionals positionals] [words words])
                   (unless (null? positionals)
                     (let* ([positional (car positionals)]
                            [own (if (= (positional-ast-min positional) (positional-ast-max positional))
                                     (positional-ast-min positional)
                                     (+ (positional-ast-min positional) (- count minimum)))]
                            [convert (converter-convert (spec-converter positional))])
                       (hashtable-set! table positional
                                       (map (lambda (word) (convert word (positional-ast-name positional)))
                                            (list-head words own)))
                       (loop (cdr positionals) (list-tail words own))))))))

         (let ([words (scan args)])
           (unless help-asked?
             (check-required specs table)
             (take-positional-words! words))
           (make-accessor specs positionals table)))]))

  ;; every positional needs its minimum, the first one that lacks words is the one to blame
  (define (check-enough-words positionals count)
    (let loop ([positionals positionals] [left count])
      (unless (null? positionals)
        (when (< left (positional-ast-min (car positionals)))
          (fail "too few positional arguments" (positional-ast-name (car positionals))))
        (loop (cdr positionals) (- left (positional-ast-min (car positionals)))))))

  (define (sum numbers) (apply + numbers))

  (define (list-head list count)
    (if (= count 0)
        '()
        (cons (car list) (list-head (cdr list) (- count 1)))))

  ;; the first required option that was not given is an error; the long name is the one to show
  (define (check-required specs table)
    (for-each
     (lambda (spec)
       (when (and (option-ast-required spec) (not (hashtable-contains? table spec)))
         (fail "missing required option" (or (option-ast-long spec) (option-ast-short spec)))))
     specs))

  (define (default-on-help text)
    (display text)
    (exit 0))

  ;; the procedure the user gets: (option "count"), (option "file"), (option "help"); the names are
  ;; those of the options without their dashes, the name of the positional, and "help" for the usage
  (define (make-accessor specs positionals table)
    (lambda (key)
      (if (or (string? key) (symbol? key))
          (let ([name (if (symbol? key) (symbol->string key) key)])
            (cond
             [(string=? name "help")
              (format-usage specs (program-name) positionals)]
             [(find-spec-by-name specs name)
              => (lambda (spec)
                   (value-of (option-ast-min spec) (option-ast-max spec) (hashtable-ref table spec #f)))]
             [(find-positional positionals name)
              => (lambda (positional)
                   (value-of (positional-ast-min positional) (positional-ast-max positional)
                             (hashtable-ref table positional #f)))]
             [else (fail "unknown option" key)]))
          (fail "invalid option key" key))))

  ;; what the program gets for the converted arguments `items` (#f when none were given):
  ;; present or absent for a flag, the value for exactly one argument, a list otherwise
  (define (value-of min max items)
    (cond
     [(and (= 0 min) (= 0 max)) (if items 'present 'absent)]
     [(and (= 1 min) (= 1 max)) (and items (car items))]
     [else (or items '())]))

  ;; "-n" or "--count", as written on the command line
  (define (find-spec-by-token specs token)
    (let loop ([specs specs])
      (cond [(null? specs) #f]
            [(or (equal? (option-ast-short (car specs)) token)
                 (equal? (option-ast-long (car specs)) token))
             (car specs)]
            [else (loop (cdr specs))])))

  (define (find-positional positionals name)
    (let loop ([positionals positionals])
      (cond [(null? positionals) #f]
            [(string=? (positional-ast-name (car positionals)) name) (car positionals)]
            [else (loop (cdr positionals))])))

  ;; "n" or "count", the name without the dashes
  (define (find-spec-by-name specs name)
    (let loop ([specs specs])
      (cond [(null? specs) #f]
            [(member name (option-lookup-names (car specs))) (car specs)]
            [else (loop (cdr specs))])))

  (define (program-name)
    (let ([command-line (command-line)])
      (if (and (pair? command-line) (string? (car command-line)))
          (car command-line)
          "program")))

  ;; ========================================
  ;; usage
  ;; ========================================

  ;; (format-usage specs program [positionals]) => the usage text
  (define format-usage
    (case-lambda
      [(specs program) (format-usage specs program '())]
      [(specs program positionals)
       (let ([specs (append specs (list help-spec))])
         (string-append
          "Usage: " program " [options]"
          (if (null? positionals)
              ""
              (string-append " [--] " (join (map positional-placeholder positionals) " ")))
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
                            specs))))]))

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

  (define (placeholder spec)
    (placeholder-of (option-ast-min spec) (option-ast-max spec)
                    (converter-label (spec-converter spec))))

  ;; "<file>...", "[<file>]": how many words, shown with the name of the positional
  (define (positional-placeholder positional)
    (placeholder-of (positional-ast-min positional) (positional-ast-max positional)
                    (string-append "<" (positional-ast-name positional) ">")))

  ;; the placeholder of `arg` for min to max arguments
  (define (placeholder-of min max arg)
    (let ([mandatory (repeat min arg)])
      (join
       (cond
        [(and (= max unlimited) (= min 0))
         (list (string-append "[" arg "...]"))]
        [(= max unlimited)
         (append (repeat (- min 1) arg) (list (string-append arg "...")))]
        [else
         (append mandatory (repeat (- max min) (string-append "[" arg "]")))])
       " ")))

  (define (repeat n x)
    (if (= n 0) '() (cons x (repeat (- n 1) x))))

  (define (join strings separator)
    (if (null? strings)
        ""
        (let loop ([result (car strings)] [rest (cdr strings)])
          (if (null? rest)
              result
              (loop (string-append result separator (car rest)) (cdr rest))))))

  (define (split-lines string)
    (let loop ([i 0] [start 0] [lines '()])
      (cond [(= i (string-length string))
             (reverse (cons (substring string start i) lines))]
            [(char=? (string-ref string i) #\newline)
             (loop (+ i 1) (+ i 1) (cons (substring string start i) lines))]
            [else (loop (+ i 1) start lines)])))

  ;; ========================================
  ;; tokens
  ;; ========================================

  (define (option-like? token)
    (and (> (string-length token) 1)
         (char=? (string-ref token 0) #\-)
         (not (string=? token "--"))))

  ;; "\-x" is the way to pass "-x" as a value
  (define (unescape token)
    (if (and (> (string-length token) 1)
             (char=? (string-ref token 0) #\\)
             (char=? (string-ref token 1) #\-))
        (substring token 1 (string-length token))
        token))

  (define (index-of char string)
    (let loop ([i 0])
      (cond [(= i (string-length string)) #f]
            [(char=? (string-ref string i) char) i]
            [else (loop (+ i 1))])))

  (define (split-commas string)
    (let loop ([i 0] [start 0] [parts '()])
      (cond [(= i (string-length string))
             (reverse (cons (substring string start i) parts))]
            [(char=? (string-ref string i) #\,)
             (loop (+ i 1) (+ i 1) (cons (substring string start i) parts))]
            [else (loop (+ i 1) start parts)])))

  ;; ========================================
  ;; converters, from the text of an argument to a value
  ;; ========================================

  ;; A converter turns the text of an argument into a value, and it deals with everything about that:
  ;;   label    how an argument is shown in the usage: "<int>", "{json,text}"
  ;;   convert  (convert text option-name) => the value; when the text does not suit, it raises the
  ;;            error the user sees, so each kind of converter has its own failure
  ;; The runtime only uses these two, it does not know which kinds of converter there are.
  (define-record-type converter
    (fields label convert))

  ;; the converter of an option; no converter means the text as it is
  (define (spec-converter spec)
    (or (if (positional-ast? spec) (positional-ast-converter spec) (option-ast-converter spec))
        (builtin-converter 'string)))

  ;; a converter made of a procedure from the text to a value, which may fail in any way:
  ;; whatever it raises is reported as an invalid argument value
  (define (make-procedure-converter label procedure)
    (make-converter label
                    (lambda (text name)
                      (guard (e [else (fail "invalid argument value" name text)])
                        (procedure text)))))

  ;; the converter of a :type written by the user, which is any procedure of one argument
  (define (procedure->converter procedure)
    (make-procedure-converter "<value>" procedure))

  ;; a converter for a list of choices, strings and exact integers; an integer is chosen by its
  ;; usual text and the value is the choice itself
  (define (make-choice-converter choices)
    (make-converter
     (string-append "{" (join (map choice->text choices) ",") "}")
     (lambda (text name)
       (let loop ([rest choices])
         (cond [(null? rest)
                (fail "argument must be one of the choices" name text choices)]
               [(string=? (choice->text (car rest)) text) (car rest)]
               [else (loop (cdr rest))])))))

  (define (choice->text choice)
    (if (string? choice) choice (number->string choice)))

  (define (convert-string s) s)

  (define (convert-int s)
    (let ([n (string->number s 10)])
      (if (and n (integer? n) (exact? n) (fixnum? n))
          n
          (fail "not an integer" s))))

  (define (convert-float s)
    (let ([n (string->number s 10)])
      (if (and n (real? n))
          (inexact n)
          (fail "not a number" s))))

  (define (convert-bool s)
    (let ([word (string-downcase s)])
      (cond [(member word '("true" "yes" "on" "1")) #t]
            [(member word '("false" "no" "off" "0")) #f]
            [else (fail "not a boolean" s)])))

  ;; the converters that :type knows by name: the name -> the converter
  (define builtin-converters
    (list (cons 'string (make-procedure-converter "<string>" convert-string))
          (cons 'int (make-procedure-converter "<int>" convert-int))
          (cons 'float (make-procedure-converter "<float>" convert-float))
          (cons 'bool (make-procedure-converter "<bool>" convert-bool))))

  (define (builtin-converter name)
    (cdr (assq name builtin-converters)))

  ;; ========================================
  ;; errors
  ;; ========================================

  (define (fail message . irritants)
    (apply error 'opt-parser message irritants)))
