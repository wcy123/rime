#!r6rs
(library (test rime loop count-fixed-test)
  (export main)
  (import (rnrs (6))
          (rime unit-test)
          (rime loop))

  (define (main)
    (run-all-tests))

  (define-test
    test-count-basic
    ;; Basic counting
    (CHECK equal? (loop :for i :from 1 :to 5 :count) 5)
    (CHECK equal? (loop :for i :from 0 :below 5 :count) 5))

  (define-test
    test-count-conditional
    ;; Conditional counting with :if/:when/:unless
    (CHECK equal? (loop :for ch :in-string "Hello World"
                        :count :if (char-upper-case? ch)) 2)
    (CHECK equal? (loop :for i :from 1 :to 10
                        :count :when (even? i)) 5)
    (CHECK equal? (loop :for i :from 1 :to 10
                        :count :unless (< i 5)) 6))

  (define-test
    test-count-step
    ;; Custom increment with :step
    (CHECK equal? (loop :for i :from 1 :to 5 :count :step 2) 10)
    (CHECK equal? (loop :for i :from 1 :to 5 :count :step i) 15)
    (CHECK equal? (loop :for i :from 1 :to 3 :count :step 10) 30))

  (define-test
    test-count-into
    ;; Count into variable
    (CHECK equal? (loop :for i :from 1 :to 5
                        :count :into total
                        :finally total) 5)
    (CHECK equal? (loop :for i :from 1 :to 5
                        :count :into sum :step 2
                        :finally sum) 10))

  (define-test
    test-count-combined
    ;; Combined :into :step :if
    (CHECK equal? (loop :for i :from 1 :to 10
                        :count :into sum :step (* 2 i) :if (odd? i)
                        :finally sum) 50)
    (CHECK equal? (loop :for i :from 1 :to 10
                        :count :into sum :step i :if (even? i)
                        :finally sum) 30))

  (define-test
    test-count-multiple-counters
    ;; Multiple counters in same loop
    (CHECK equal? (loop :for i :from 1 :to 10
                        :count :into evens :step i :if (even? i)
                        :count :into odds :step i :if (odd? i)
                        :finally (cons evens odds))
           '(30 . 25)))

  (define-test
    test-count-practical
    ;; Practical examples
    (CHECK equal? (loop :for ch :in-string "Hello World" :count) 11)
    (CHECK equal? (loop :for score :in '(80 90 100 70 60)
                        :for weight :in '(1 1 2 1 1)
                        :count :into total :step (* score weight)
                        :finally total) 500))

  (define-test
    test-count-original-request
    ;; Original requested example that was broken
    (CHECK equal? (loop :initially sum := 0
                        :for i :from 0 :below 10
                        :count :into sum :step (* 2 i) :if (odd? i)
                        :finally sum) 50)))
