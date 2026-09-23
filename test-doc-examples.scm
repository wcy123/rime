#!r6rs
(import (rnrs (6)) (rime loop))

(define test-count 0)
(define pass-count 0)
(define fail-count 0)

(define (test-equal desc expected actual)
  (set! test-count (+ test-count 1))
  (if (equal? expected actual)
      (begin
        (set! pass-count (+ pass-count 1))
        (display (string-append "✓ Test " (number->string test-count) ": " desc "\n")))
      (begin
        (set! fail-count (+ fail-count 1))
        (display (string-append "✗ Test " (number->string test-count) " FAILED: " desc "\n"))
        (display "  Expected: ")
        (write expected)
        (newline)
        (display "  Got:      ")
        (write actual)
        (newline))))

(display "=== Testing doc/loop.md Examples ===\n\n")

;; Basic Iteration - Arithmetic
(test-equal "Arithmetic iteration"
  '(0 1 2)
  (loop :for i :from 0 :to 2 :collect i))

;; List Iteration
(test-equal "List iteration :in"
  '(1 2 3)
  (loop :for i :in '(1 2 3) :collect i))

(test-equal "List iteration :on"
  '((1 2 3) (2 3) (3))
  (loop :for i :on '(1 2 3) :collect i))

;; Vector Iteration
(test-equal "Vector iteration"
  '(1 2 3)
  (loop :for i :in-vector '#(1 2 3) :collect i))

;; String Iteration
(test-equal "String iteration"
  '(#\H #\E #\L #\L #\O)
  (loop :for i :in-string "HELLO" :collect i))

(test-equal "String iteration with offset"
  '(#\L #\L #\O)
  (loop :for i :in-string "HELLO" :offset 2 :collect i))

;; Filtering with :if
(test-equal "Filter odd numbers"
  '(1 3 5 7)
  (loop :for i :from 0 :to 8
        :if (odd? i)
        :collect i))

(test-equal "Filter with :unless"
  '(1 3 5 7)
  (loop :for i :from 0 :to 8
        :unless (even? i)
        :collect i))

;; Parallel Iteration
(test-equal "Parallel iteration"
  '((0 . a) (1 . b) (2 . c))
  (loop :for i :from 0 :to 8
        :for c :in '(a b c)
        :collect (cons i c)))

;; :append for flat-map
(test-equal "Append/flat-map"
  '(0 a 1 b 2 c)
  (loop :for index :from 0
        :for ch :in '(a b c)
        :append (list index ch)))

;; :count basic
(test-equal "Basic count"
  5
  (loop :for i :from 1 :to 5 :count))

;; :count with :if
(test-equal "Count with condition"
  2
  (loop :for ch :in-string "Hello World"
        :count :if (char-upper-case? ch)))

(test-equal "Count with :when"
  5
  (loop :for i :from 1 :to 10
        :count :when (even? i)))

(test-equal "Count with :unless"
  6
  (loop :for i :from 1 :to 10
        :count :unless (< i 5)))

;; :count with :step
(test-equal "Count with step 2"
  10
  (loop :for i :from 1 :to 5 :count :step 2))

(test-equal "Count with variable step"
  15
  (loop :for i :from 1 :to 5 :count :step i))

;; :count with :into and :step
(test-equal "Count into with step"
  '(30 . 25)
  (loop :for i :from 1 :to 10
        :count :into evens :step i :if (even? i)
        :count :into odds :step i :if (odd? i)
        :finally (cons evens odds)))

;; :count weighted scoring
(test-equal "Weighted scoring"
  500
  (loop :for score :in '(80 90 100 70 60)
        :for weight :in '(1 1 2 1 1)
        :count :into total :step (* score weight)
        :finally total))

;; :finally clause
(test-equal "Finally transformation"
  '(100 101 102)
  (loop :for i :from 0 :to 2
        :collect i
        :finally (map (lambda (x) (+ 100 x)) :return-value)))

;; :finally nested transformations
(test-equal "Finally nested transformations"
  '(1100 1101 1102)
  (loop :for i :from 0 :to 2
        :collect i
        :finally (map (lambda (y) (+ 1000 y))
                      (map (lambda (x) (+ 100 x)) :return-value))))

;; :break basic
(test-equal "Break with condition"
  '(0 1 2)
  (loop :for i :from 0 :to 200
        :break :if (> i 2)
        :collect i))

;; :break with return value
(test-equal "Break with value"
  100
  (loop :for i :from 0 :to 2
        :break 100
        :collect i))

;; :with clause
(test-equal "With clause for intermediate values"
  '(1008 1009 1010 1011 1012)
  (loop :for index :from 0
        :for ch :in-string "this is HELLO."
        :with is-uppercase := (char-upper-case? ch)
        :if is-uppercase
        :with plus-pos := (+ 500 index)
        :with plus-pos := (+ 500 plus-pos)
        :collect plus-pos))

;; Nested loop
(test-equal "Nested loop"
  '((0 . a) (0 . b) (0 . c)
    (1 . a) (1 . b) (1 . c)
    (2 . a) (2 . b) (2 . c))
  (loop :for i :in '(0 1 2)
        (:loop :for j :in '(a b c)
               :collect (cons i j))))

;; Fibonacci with :recur
(test-equal "Fibonacci with recur"
  '(1 1 2 3 5 8 13 21 34 55)
  (loop :repeat 10
        :recur x0 := 0 :then x
        :recur x := 1 :then (fx+ x0 x)
        :collect x))

;; Practical Examples
(test-equal "map implementation"
  '(#t #f #t)
  (loop :for i :in '(1 2 3) :collect (odd? i)))

(test-equal "filter implementation"
  '(1 3)
  (loop :for i :in '(1 2 3) :if (odd? i) :collect i))

;; string-start example
(define (string-start prefix from str)
  (loop :for c1 :in-string prefix
        :for c2 :in-string str :offset from
        :break :unless (char=? c1 c2)
        :count
        :finally (fx=? (string-length prefix) :return-value)))

(test-equal "string-start positive"
  #t
  (string-start "loop-" 5 "this-loop-parser"))

(test-equal "string-start negative"
  #f
  (string-start "loop-" 0 "this-loop-parser"))

;; intersection example
(define (intersection list-a list-b)
  (loop :for c1 :in list-a
        (:loop :for c2 :in list-b
               :if (eq? c1 c2)
               :collect c2)))

(test-equal "intersection"
  '(b c)
  (intersection '(a b c) '(b c d)))

;; member? example
(define (member? x lst)
  (loop :for item :in lst
        :if (equal? x item)
        :break #t))

(test-equal "member? found"
  #t
  (member? 'b '(a b c)))

;; list-index example
(define (list-index x lst)
  (loop :for item :in lst
        :for index :from 0
        :if (equal? x item)
        :break index))

(test-equal "list-index found"
  1
  (list-index 'b '(a b c)))

(test-equal "list-index first occurrence"
  0
  (list-index 'a '(a b a c)))

;; vector-index example
(define (vector-index x vec)
  (loop :for item :in-vector vec
        :for index :from 0
        :if (equal? x item)
        :break index))

(test-equal "vector-index found"
  1
  (vector-index 20 (vector 10 20 30)))

(test-equal "vector-index first"
  0
  (vector-index 10 (vector 10 20 10 30)))

;; list-indices example
(define (list-indices x lst)
  (loop :initially acc := '()
        :for item :in lst
        :for index :from 0
        :when (equal? x item)
        :do (set! acc (cons index acc))
        :finally (reverse acc)))

(test-equal "list-indices multiple"
  '(0 2 4)
  (list-indices 'a '(a b a c a)))

(test-equal "list-indices none"
  '()
  (list-indices 'd '(a b c)))

;; my-filter example
(define (my-filter pred lst)
  (loop :initially acc := '()
        :for item :in lst
        :when (pred item)
        :do (set! acc (cons item acc))
        :finally (reverse acc)))

(test-equal "my-filter"
  '(2 4 6)
  (my-filter even? '(1 2 3 4 5 6)))

;; my-map example
(define (my-map f lst)
  (loop :initially acc := '()
        :for item :in lst
        :do (set! acc (cons (f item) acc))
        :finally (reverse acc)))

(test-equal "my-map"
  '(2 4 6)
  (my-map (lambda (x) (* x 2)) '(1 2 3)))

;; remove-duplicates example
(define (remove-duplicates lst)
  (loop :initially seen := (make-eq-hashtable)
        :initially acc := '()
        :for item :in lst
        :unless (hashtable-contains? seen item)
        :do (hashtable-set! seen item #t)
        :do (set! acc (cons item acc))
        :finally (reverse acc)))

(test-equal "remove-duplicates"
  '(a b c d)
  (remove-duplicates '(a b a c b d)))

;; zip example
(define (zip lst1 lst2)
  (loop :initially acc := '()
        :for a :in lst1
        :for b :in lst2
        :do (set! acc (cons (cons a b) acc))
        :finally (reverse acc)))

(test-equal "zip"
  '((a . 1) (b . 2) (c . 3))
  (zip '(a b c) '(1 2 3)))

(test-equal "zip shorter"
  '((a . 1) (b . 2))
  (zip '(a b c d) '(1 2)))

;; range example
(define (range start end)
  (loop :initially acc := '()
        :for i :from start :to end
        :do (set! acc (cons i acc))
        :finally (reverse acc)))

(test-equal "range"
  '(0 1 2 3 4 5)
  (range 0 5))

(test-equal "range small"
  '(10 11 12)
  (range 10 12))

;; take example
(define (take n lst)
  (loop :initially acc := '()
        :for item :in lst
        :for count :from 1 :to n
        :do (set! acc (cons item acc))
        :finally (reverse acc)))

(test-equal "take"
  '(a b c)
  (take 3 '(a b c d e)))

;; Summary
(newline)
(display "=== Test Summary ===\n")
(display (string-append "Total:  " (number->string test-count) "\n"))
(display (string-append "Passed: " (number->string pass-count) "\n"))
(display (string-append "Failed: " (number->string fail-count) "\n"))

(if (= fail-count 0)
    (begin
      (display "\n✓ All documentation examples verified!\n")
      (exit 0))
    (begin
      (display "\n✗ Some tests failed!\n")
      (exit 1)))
