#!r6rs
;; The runtime of define-command-line-options: what runs in the user's program. Parses the
;; command line against the options (option-ast records, see __ast.sls), builds the accessor,
;; and prints the usage.
(library (rime command-line-options __runtime)
  (export parse-command-line
          parse-or-exit
          command-line-error?
          command-line-error-usage
          builtin-converters
          builtin-converter
          make-choice-converter
          procedure->converter)
  (import (only (rnrs (6))
                &error + - < = => > and append apply assq caddr cadr call-with-string-output-port
                car case-lambda cdr char-whitespace? char=? command-line cond condition
                condition-irritants condition-message cons current-error-port define
                define-condition-type display else equal? error exact? exists exit fixnum? for-all
                for-each guard hashtable-contains? hashtable-ref hashtable-set! if inexact integer?
                lambda length let let* let-values list list-tail list? make-eq-hashtable make-error
                make-irritants-condition make-message-condition make-string make-who-condition map
                max member not null? number->string or pair? quote raise real? reverse string->list
                string->number string-append string-downcase string-length string-ref string=?
                string? substring symbol->string symbol? unless values when write)
          ;; whole library: Guile's (rnrs (6)) has no `fields` or `mutable`, so no `only` list
          (rnrs records syntactic (6))
          (only (rime command-line-options __ast)
                make-option-ast option-ast-converter option-ast-description option-ast-long
                option-ast-max option-ast-metavar option-ast-min option-ast-required
                option-ast-short option-lookup-names positional-ast-converter
                positional-ast-description positional-ast-max positional-ast-min
                positional-ast-name positional-ast? unbound unbound? unlimited))

  (define help-spec
    (make-option-ast "-h" "--help" 0 0 #f "show this help message and exit" #f #f #f))

  ;; ========================================
  ;; parsing the command line
  ;; ========================================

  ;;; @brief The parser: the command line goes in, the accessor of the program comes out.
  ;;;
  ;;; `parse-command-line` runs a few steps in this order. Each step is a function with its own
  ;;; input and output. A step that finds a mistake of the command line raises it with `fail`, and
  ;;; the steps after it do not run.
  ;;;
  ;;; @li `scan-tokens`: the command line -> the options, in a table, and the positional words.
  ;;;     At -h or --help it calls the help hook, and then the steps below, up to
  ;;;     `store-positional-words!`, are skipped.
  ;;; @li `check-required`: every `:required` option is in the table.
  ;;; @li `check-collected`: the arity of an option that collects its arguments, on the total.
  ;;; @li `distribute-words`: the positional words -> the words of each positional.
  ;;; @li `store-positional-words!`: converts the words of each positional, puts them in the table.
  ;;; @li `make-accessor`: the table -> the procedure `(option "name")` that the program gets.
  ;;;
  ;;; @par Example
  ;;; The options are `[:short "-v" :arity 0]` and `[:short "-n" :long "--count" :type int]`.
  ;;; The positionals are `source` (one or more words) and `dest` (exactly one). The command line
  ;;; `a -v -n 3 b c` goes through the steps like this:
  ;;; @code
  ;;; scan-tokens              words ("a" "b" "c"); table: -v => (), -n => (3)
  ;;; check-required           no error, no option is required
  ;;; check-collected          no error, no option takes more than one argument
  ;;; distribute-words         (("source" "a" "b") ("dest" "c"))
  ;;; store-positional-words!  table: source => ("a" "b"), dest => ("c")
  ;;; make-accessor            (option "v") => #t          (option "n") => 3
  ;;;                          (option "source") => ("a" "b")   (option "dest") => "c"
  ;;; @endcode
  ;;;
  ;;; @par Errors
  ;;; With `[:long "--input" :required]` added to the options above, the first step that finds a
  ;;; mistake raises it:
  ;;; @code
  ;;; a -n                the step: scan-tokens        too few arguments for option ("-n")
  ;;; -n x a b --input x  the step: scan-tokens        invalid argument value ("-n" "x")
  ;;; a b                 the step: check-required     missing required option ("--input")
  ;;; a --input x         the step: distribute-words   too few positional arguments ("dest")
  ;;; @endcode

  ;; (parse-command-line specs args positionals) => the accessor
  ;;   positionals: list of positional-ast, '() when the command line takes no positional words
  ;; -h and --help are a flag like the others: the accessor tells (option "help") whether it was
  ;; given. The words after it are not read, and the checks that need them are skipped.
  (define (parse-command-line specs args positionals)
    ;; the library's own failures leave here with the usage of this parser attached
    (with-usage
     (lambda () (format-usage specs (program-name) positionals))
     (lambda ()
       (let* ([result (scan-tokens specs args)]
              [table (parse-result-table result)])
         (unless (hashtable-contains? table help-spec)
           (check-required specs table)
           (check-collected specs table)
           (store-positional-words! table (distribute-words positionals (parse-result-words result))))
         (make-accessor specs positionals table)))))

  ;; table          option-ast or positional-ast -> the converted arguments, of what was given;
  ;;                help-spec is in it when -h or --help was met
  ;; words          the positional words, in order, the ones before -- unescaped
  (define-record-type parse-result
    (fields table words))

  ;; (scan-tokens specs tokens) => parse-result
  ;; Options and positional words may come in any order. At -h and --help the scan stops: the table
  ;; has help-spec in it, and the words after it are not read.
  (define (scan-tokens specs tokens)
    (let ([table (make-eq-hashtable)])
      (let loop ([tokens tokens] [words '()])
        (cond
         [(null? tokens)
          (make-parse-result table (reverse words))]
         [(string=? (car tokens) "--")
          (make-parse-result table (append (reverse words) (cdr tokens)))]
         [(member (car tokens) '("-h" "--help"))
          (hashtable-set! table help-spec '())
          (make-parse-result table (reverse words))]
         [(option-like? (car tokens) specs)
          (loop (parse-option specs table (car tokens) (cdr tokens)) words)]
         [else
          (loop (cdr tokens) (cons (unescape (car tokens)) words))]))))

  ;; token is "-x", "--long" or "-x=text" / "--long=text"; stores the option in the table and returns
  ;; the tokens that it did not take.
  ;; After =, the text is exactly one argument, whatever it contains (getopt, argparse and click do the
  ;; same). Following words are not consumed, so an option that takes a variable number of arguments
  ;; can be stopped, and an option that needs two or more cannot use =.
  (define (parse-option specs table token rest)
    (let* ([equals (index-of #\= token)]
           [name (if equals (substring token 0 equals) token)]
           [spec (find-spec-by-token specs name)])
      (cond
       [equals
        (when (= 0 (option-ast-max spec))
          (fail "option does not take arguments" name))
        (store! table spec name (list (substring token (+ equals 1) (string-length token))))
        rest]
       [else
        (let-values ([(items remaining) (take-arguments specs rest (option-ast-max spec))])
          ;; an option that collects its arguments is checked on the total, see check-collected
          (when (and (not (collecting? spec)) (< (length items) (option-ast-min spec)))
            (fail "too few arguments for option" name))
          (store! table spec name items)
          remaining)])))

  ;; returns (values taken remaining), taking at most max tokens
  (define (take-arguments specs tokens max)
    (let loop ([tokens tokens] [count 0] [taken '()])
      (if (and (< count max) (pair? tokens) (argument-token? (car tokens) specs))
          (loop (cdr tokens) (+ count 1) (cons (car tokens) taken))
          (values (reverse taken) tokens))))

  (define (argument-token? token specs)
    (not (or (string=? token "--") (option-like? token specs))))

  ;; An option that takes several arguments, max above 1, collects the arguments of all its occurrences
  ;; in one flat list, and check-collected checks the total. Any other option, a flag or one with at
  ;; most one argument, keeps the last occurrence.
  (define (collecting? spec)
    (> (option-ast-max spec) 1))

  (define (store! table spec name items)
    (let ([values (convert-items spec name items)])
      (hashtable-set! table spec
                      (if (collecting? spec)
                          (append (hashtable-ref table spec '()) values)
                          values))))

  ;; the arity of an option that collects its arguments is checked on the total, after the scan
  (define (check-collected specs table)
    (for-each
     (lambda (spec)
       (when (and (collecting? spec) (hashtable-contains? table spec))
         (let ([count (length (hashtable-ref table spec '()))]
               [name (or (option-ast-long spec) (option-ast-short spec))])
           (when (< count (option-ast-min spec))
             (fail "too few arguments for option" name))
           (when (> count (option-ast-max spec))
             (fail "too many arguments for option" name)))))
     specs))

  ;; the converter reports its own failure, it is given the name of the option for that
  (define (convert-items spec name items)
    (let ([convert (converter-convert (spec-converter spec))])
      (map (lambda (item) (convert (unescape item) name)) items)))

  ;; (distribute-words positionals words) => list of (positional . words), one per positional
  ;; The words that are not options are shared out to the positionals, in order. Each gets as many
  ;; as its minimum, and the one that takes a variable number of words (there is at most one) also
  ;; gets the words that are left over. Without a positional they are an error.
  ;;   cp-like: source (1 +), dest 1; words a b c  =>  ((source a b) (dest c))
  (define (distribute-words positionals words)
    (cond
     [(null? positionals)
      (when (pair? words)
        (apply fail "unexpected positional argument" words))
      '()]
     [else
      (let* ([count (length words)]
             [minimum (sum (map positional-ast-min positionals))]
             [maximum (sum (map positional-ast-max positionals))])
        (check-enough-words positionals count)
        (when (> count maximum)
          (apply fail "too many positional arguments" (list-tail words maximum)))
        (let loop ([positionals positionals] [words words] [shared '()])
          (if (null? positionals)
              (reverse shared)
              (let* ([positional (car positionals)]
                     [own (if (= (positional-ast-min positional) (positional-ast-max positional))
                              (positional-ast-min positional)
                              (+ (positional-ast-min positional) (- count minimum)))])
                (loop (cdr positionals)
                      (list-tail words own)
                      (cons (cons positional (list-head words own)) shared))))))]))

  ;; converts the words of each positional and puts them in the table
  (define (store-positional-words! table shared)
    (for-each
     (lambda (pair)
       (let ([convert (converter-convert (spec-converter (car pair)))]
             [name (positional-ast-name (car pair))])
         (hashtable-set! table (car pair) (map (lambda (word) (convert word name)) (cdr pair)))))
     shared))

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

  ;; the procedure the user gets: (option "count"), (option "file"), (option "help"); the names are
  ;; those of the options without their dashes and the name of the positional. "help" is #t when -h
  ;; was given, and "usage" is the usage text.
  ;; (option "count" 3) is the same, but it gives 3 when the option was not given on the command line:
  ;; the value is the program's own, it is not converted or checked. An option that was given with
  ;; no arguments, -o alone, was given, and a positional that got no words was not.
  (define (make-accessor specs positionals table)
    ;; default is `unbound` when the program gave none; any other value is its default, even #f
    (define (lookup key default)
      (if (or (string? key) (symbol? key))
          (let ([name (if (symbol? key) (symbol->string key) key)])
            (cond
             [(string=? name "usage")
              (format-usage specs (program-name) positionals)]
             [(find-spec-by-name (append specs (list help-spec)) name)
              => (lambda (spec)
                   (if (and (not (unbound? default)) (not (hashtable-contains? table spec)))
                       default
                       (value-of (option-ast-min spec) (option-ast-max spec) (hashtable-ref table spec #f))))]
             [(find-positional positionals name)
              => (lambda (positional)
                   (if (and (not (unbound? default)) (null? (hashtable-ref table positional '())))
                       default
                       (value-of (positional-ast-min positional) (positional-ast-max positional)
                                 (hashtable-ref table positional #f))))]
             [else (accessor-fail "unknown option" key (unknown-name-hint specs positionals name))]))
          (accessor-fail "invalid option key" key)))
    (case-lambda
      [(key) (lookup key unbound)]
      [(key default) (lookup key default)]))

  ;; (unknown-name-hint specs positionals name) => the hint that the error carries after the name
  ;;   input   specs and positionals: what the parser defines; name: the name the program asked for
  ;;   output  the text "names are read without the dashes" when the name starts with a dash,
  ;;           otherwise the list of the names that do exist, the options in the order they were
  ;;           defined (short name first), then the positionals
  ;;
  ;; For [:short "-v" :long "--verbose"], [:short "-o" :long "--output"] and [:positional "file"]:
  ;;   (option "--verbose")  =>  error: unknown option "--verbose"
  ;;                             hint:  "names are read without the dashes"
  ;;   (option "verbos")     =>  error: unknown option "verbos"
  ;;                             hint:  ("v" "verbose" "o" "output" "file")
  (define (unknown-name-hint specs positionals name)
    (if (and (> (string-length name) 0) (char=? (string-ref name 0) #\-))
        "names are read without the dashes"
        (append (apply append (map option-lookup-names specs))
                (map positional-ast-name positionals))))

  ;; what the program gets for the converted arguments `items` (#f when none were given):
  ;; #t or #f for a flag, the value for exactly one argument, a list otherwise
  (define (value-of min max items)
    (cond
     [(and (= 0 min) (= 0 max)) (and items #t)]
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

  ;; the first element of (command-line), or "program" when there is none: (command-line) is ("")
  ;; when there is no script, in a REPL or with --eval
  (define (program-name)
    (let ([line (command-line)])
      (if (and (pair? line) (string? (car line)) (not (string=? (car line) "")))
          (car line)
          "program")))

  ;; ========================================
  ;; usage
  ;; ========================================

  ;; (format-usage specs program positionals) => the usage text
  (define (format-usage specs program positionals)
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
                         specs)))))

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
                        (converter-label (spec-converter spec)))))

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

  ;; A word is an option only when it is the name of a defined option, alone or followed by =text
  ;; ("-n", "--count=3"), or -h and --help. Any other word is an ordinary word, whatever it starts
  ;; with: -5, -x and --typo are positional words, or the arguments of the option before them.
  ;; An option that is named like a value, say -5, cannot be given as that value; write it after --,
  ;; after =, or with the escape.
  (define (option-like? token specs)
    (let ([equals (index-of #\= token)])
      (or (and (member token '("-h" "--help")) #t)
          (and (find-spec-by-token specs (if equals (substring token 0 equals) token)) #t))))

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

  ;; A problem with the command line: the condition is an &error with the who, the message and the
  ;; details that an (error 'opt-parser ...) has, and it is also a &command-line-error, so that a
  ;; program can tell it from its own errors. The usage is added where the parser is known, see
  ;; with-usage; until then it is #f.
  (define-condition-type &command-line-error &error
    make-command-line-error command-line-error?
    (usage command-line-error-usage))

  ;; details are the values the message is about: the option name, the text that did not fit, ...
  (define (fail message . details)
    (raise (command-line-condition message details #f)))

  (define (command-line-condition message details usage)
    (condition (make-error)
               (make-who-condition 'opt-parser)
               (make-message-condition message)
               (make-irritants-condition details)
               (make-command-line-error usage)))

  ;; The mistakes of the program that reads the result, a name that does not exist, a key that is
  ;; not a name: an ordinary error, not a problem with the command line.
  (define (accessor-fail message . details)
    (apply error 'opt-parser message details))

  ;; (with-usage make-usage thunk): runs thunk; a command-line error raised in it is raised again
  ;; with the usage text (from the procedure make-usage) in it. Other exceptions pass untouched.
  (define (with-usage make-usage thunk)
    (guard (e [(and (command-line-error? e) (not (command-line-error-usage e)))
               (raise (command-line-condition (condition-message e) (condition-irritants e) (make-usage)))])
      (thunk)))

  ;; "prog: sentence", a blank line, and the usage; what parse-or-exit prints. The sentence is
  ;; (describe-problem message details); a message that is not known is "message: detail ...".
  (define (format-command-line-error e)
    (string-append
     (program-name) ": "
     (or (describe-problem (condition-message e) (condition-irritants e))
         (string-append
          (condition-message e)
          (if (null? (condition-irritants e))
              ""
              (string-append ": " (join (map write->string (condition-irritants e)) " ")))))
     "\n\n"
     (or (command-line-error-usage e) "")))

  ;; (describe-problem message details) => what a person reads, or #f when the message is not known or
  ;; its details are not the ones it has. The condition keeps its message and details, this is only text.
  ;;   (describe-problem "invalid argument value" '("-n" "abc"))  =>  invalid argument "abc" for -n
  ;;   (describe-problem "missing required option" '("--input"))  =>  missing required option --input
  (define (describe-problem message details)
    (define (is? text) (string=? message text))
    ;; a word as it was typed, quoted only when it is empty or has whitespace in it
    (define (word w)
      (if (and (string? w) (> (string-length w) 0) (not (exists char-whitespace? (string->list w))))
          w
          (write->string w)))
    (define (words ws) (join (map word ws) " "))
    (define (choice-text c) (if (string? c) c (number->string c)))
    (define (all-strings? ds) (for-all string? ds))
    (cond
     [(and (is? "invalid argument value") (= 2 (length details)) (all-strings? details))
      (string-append "invalid argument " (write->string (cadr details)) " for " (car details))]
     [(and (is? "argument must be one of the choices") (= 3 (length details))
           (string? (car details)) (string? (cadr details)) (list? (caddr details)))
      (string-append (write->string (cadr details)) " is not one of "
                     (join (map choice-text (caddr details)) ", ")
                     " (for " (car details) ")")]
     [(and (is? "too few arguments for option") (= 1 (length details)) (all-strings? details))
      (string-append "too few arguments for " (car details))]
     [(and (is? "too many arguments for option") (= 1 (length details)) (all-strings? details))
      (string-append "too many arguments for " (car details))]
     [(and (is? "option does not take arguments") (= 1 (length details)) (all-strings? details))
      (string-append (car details) " does not take arguments")]
     [(and (is? "missing required option") (= 1 (length details)) (all-strings? details))
      (string-append "missing required option " (car details))]
     [(and (is? "too few positional arguments") (= 1 (length details)) (all-strings? details))
      (string-append "missing positional argument <" (car details) ">")]
     [(and (is? "too many positional arguments") (pair? details) (all-strings? details))
      (string-append "too many positional arguments: " (words details))]
     [(and (is? "unexpected positional argument") (pair? details) (all-strings? details))
      (string-append "unexpected positional argument: " (words details))]
     [else #f]))

  (define (write->string datum)
    (call-with-string-output-port (lambda (port) (write datum port))))

  ;; (parse-or-exit parser arguments) => the accessor of (parser arguments); when -h or --help was
  ;; given, prints the usage and exits with 0; when the command line is wrong, prints the problem and
  ;; the usage to the error port and exits with 2. Errors that are not about the command line are not
  ;; caught.
  (define (parse-or-exit parser arguments)
    (let ([option (guard (e [(command-line-error? e)
                             (display (format-command-line-error e) (current-error-port))
                             (exit 2)])
                    (parser arguments))])
      (when (option "help")
        (display (option "usage"))
        (exit 0))
      option)))
