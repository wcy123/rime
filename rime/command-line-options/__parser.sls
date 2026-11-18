#!r6rs
(library (rime command-line-options __parser)
  (export make-option-spec
          parse-command-line
          format-usage
          program-name
          convert-bool
          convert-int
          convert-float
          convert-string)
  (import (rnrs (6)))

  ;; short/long are strings ("-n", "--count"), long may be #f.
  ;; max is (greatest-fixnum) when unbounded. type-name is a symbol or #f (used by usage only).
  (define-record-type option-spec
    (fields short long min max type-name converter description))

  (define unbounded (greatest-fixnum))

  (define help-spec
    (make-option-spec "-h" "--help" 0 0 #f #f "show this help message and exit"))

  (define (fail message . irritants)
    (apply error 'opt-parser message irritants))

  (define (program-name)
    (let ([command-line (command-line)])
      (if (and (pair? command-line) (string? (car command-line)))
          (car command-line)
          "program")))

  ;; ========================================
  ;; converters
  ;; ========================================

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

  (define (split-lines string)
    (let loop ([i 0] [start 0] [lines '()])
      (cond [(= i (string-length string))
             (reverse (cons (substring string start i) lines))]
            [(char=? (string-ref string i) #\newline)
             (loop (+ i 1) (+ i 1) (cons (substring string start i) lines))]
            [else (loop (+ i 1) start lines)])))

  ;; ========================================
  ;; parser
  ;; ========================================

  (define (find-spec specs name)
    (let loop ([specs specs])
      (cond [(null? specs) #f]
            [(or (string=? (option-spec-short (car specs)) name)
                 (equal? (option-spec-long (car specs)) name))
             (car specs)]
            [else (loop (cdr specs))])))

  (define (default-on-help text)
    (display text)
    (exit 0))

  (define parse-command-line
    (case-lambda
      [(specs args) (parse-command-line specs args default-on-help)]
      [(specs args on-help)
       (let ([table (make-hashtable string-hash string=?)])

         (define (convert-items spec name items)
           (map (lambda (item)
                  (let ([text (unescape item)])
                    (guard (e [else (fail "invalid argument value" name text)])
                      ((option-spec-converter spec) text))))
                items))

         (define (store! spec name items)
           (hashtable-set! table (option-spec-short spec) (convert-items spec name items)))

         (define (argument-token? token)
           (not (or (string=? token "--") (option-like? token))))

         ;; returns (values taken remaining), taking at most max tokens
         (define (take-arguments tokens max)
           (let loop ([tokens tokens] [count 0] [taken '()])
             (if (and (< count max) (pair? tokens) (argument-token? (car tokens)))
                 (loop (cdr tokens) (+ count 1) (cons (car tokens) taken))
                 (values (reverse taken) tokens))))

         ;; token is "-x", "--long" or "-x=a,b" / "--long=a,b"; returns the unconsumed tokens
         (define (parse-option token rest)
           (let* ([equals (index-of #\= token)]
                  [name (if equals (substring token 0 equals) token)]
                  [spec (or (find-spec specs name) (fail "unknown option" token))])
             (cond
              [equals
               (let ([items (split-commas (substring token (+ equals 1) (string-length token)))])
                 (cond [(= 0 (option-spec-max spec))
                        (fail "option does not take arguments" name)]
                       [(< (length items) (option-spec-min spec))
                        (fail "too few arguments for option" name)]
                       [(> (length items) (option-spec-max spec))
                        (fail "too many arguments for option" name)])
                 (store! spec name items)
                 rest)]
              [else
               (let-values ([(items remaining) (take-arguments rest (option-spec-max spec))])
                 (when (< (length items) (option-spec-min spec))
                   (fail "too few arguments for option" name))
                 (store! spec name items)
                 remaining)])))

         ;; returns the positional arguments
         (define (scan tokens)
           (cond
            [(null? tokens) '()]
            [(string=? (car tokens) "--") (cdr tokens)]
            [(member (car tokens) '("-h" "--help"))
             (on-help (format-usage specs (program-name)))
             '()]
            [(option-like? (car tokens))
             (scan (parse-option (car tokens) (cdr tokens)))]
            [else (map unescape tokens)]))

         (make-accessor specs table (list->vector (scan args))))]))

  (define (make-accessor specs table positionals)
    (lambda (key)
      (cond
       [(and (number? key) (exact? key) (integer? key))
        (if (and (>= key 0) (< key (vector-length positionals)))
            (vector-ref positionals key)
            (fail "positional argument index out of range" key))]
       [(eq? key 'number-of-positional-argument)
        (vector-length positionals)]
       [(or (string? key) (symbol? key))
        (let* ([name (if (symbol? key) (symbol->string key) key)]
               [spec (or (find-spec specs name) (fail "unknown option" key))]
               [items (hashtable-ref table (option-spec-short spec) #f)])
          (cond
           [(and (= 0 (option-spec-min spec)) (= 0 (option-spec-max spec)))
            (if items 'present 'absent)]
           [(and (= 1 (option-spec-min spec)) (= 1 (option-spec-max spec)))
            (and items (car items))]
           [else (or items '())]))]
       [else (fail "invalid option key" key)])))

  ;; ========================================
  ;; usage
  ;; ========================================

  (define (repeat n x)
    (if (= n 0) '() (cons x (repeat (- n 1) x))))

  (define (join strings separator)
    (if (null? strings)
        ""
        (let loop ([result (car strings)] [rest (cdr strings)])
          (if (null? rest)
              result
              (loop (string-append result separator (car rest)) (cdr rest))))))

  (define (placeholder spec)
    (let* ([min (option-spec-min spec)]
           [max (option-spec-max spec)]
           [label (if (option-spec-type-name spec)
                      (symbol->string (option-spec-type-name spec))
                      "value")]
           [arg (string-append "<" label ">")]
           [mandatory (repeat min arg)])
      (join
       (cond
        [(and (= max unbounded) (= min 0))
         (list (string-append "[" arg "...]"))]
        [(= max unbounded)
         (append (repeat (- min 1) arg) (list (string-append arg "...")))]
        [else
         (append mandatory (repeat (- max min) (string-append "[" arg "]")))])
       " ")))

  (define (flags spec)
    (let ([names (if (option-spec-long spec)
                     (string-append (option-spec-short spec) ", " (option-spec-long spec))
                     (option-spec-short spec))]
          [arguments (placeholder spec)])
      (if (string=? arguments "")
          names
          (string-append names " " arguments))))

  (define (format-usage specs program)
    (let* ([specs (append specs (list help-spec))]
           [width (apply max (map (lambda (spec) (string-length (flags spec))) specs))]
           [indent 2]
           [gap 2]
           [column (+ indent width gap)])
      (define (spaces n) (make-string n #\space))
      (define (row spec)
        (let ([flags (flags spec)]
              [lines (split-lines (option-spec-description spec))])
          (string-append
           (spaces indent)
           (if (string=? (car lines) "")
               flags
               (string-append flags
                              (spaces (+ (- width (string-length flags)) gap))
                              (car lines)))
           "\n"
           (apply string-append
                  (map (lambda (line) (string-append (spaces column) line "\n"))
                       (cdr lines))))))
      (string-append
       "Usage: " program " [options] [--] [arguments...]\n"
       "\n"
       "Options:\n"
       (apply string-append (map row specs))))))
