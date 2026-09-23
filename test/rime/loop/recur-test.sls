#!r6rs
(library (test rime loop recur-test)
  (export main)
  (import (rnrs (6))
          (rime unit-test)
          (rime loop))

  (define (main)
    (run-all-tests))

  ;; ========================================
  ;; Example 1: Fibonacci Sequence
  ;; ========================================

  (define-test
    test-fibonacci
    ;; Classic Fibonacci using two recur variables
    (CHECK equal? (loop :repeat 10
                        :recur x0 := 0 :then x
                        :recur x := 1 :then (fx+ x0 x)
                        :collect x)
           '(1 1 2 3 5 8 13 21 34 55))

    ;; Fibonacci with :for iteration
    (CHECK equal? (loop :for i :upfrom 1 :to 10
                        :recur x0 := 0 :then x
                        :recur x := 1 :then (fx+ x0 x)
                        :collect x)
           '(1 1 2 3 5 8 13 21 34 55)))

  ;; ========================================
  ;; Example 2: Factorial
  ;; ========================================

  (define-test
    test-factorial
    ;; Factorial of 5
    (CHECK equal? (loop :for i :from 1 :to 5
                        :recur result := 1 :then (fx* result i)
                        :finally result)
           120)

    ;; Factorial of 0 (edge case)
    (CHECK equal? (loop :for i :from 1 :to 0
                        :recur result := 1 :then (fx* result i)
                        :finally result)
           1)

    ;; Factorial of 7
    (CHECK equal? (loop :for i :from 1 :to 7
                        :recur result := 1 :then (fx* result i)
                        :finally result)
           5040))

  ;; ========================================
  ;; Example 3: Running Sum
  ;; ========================================

  (define-test
    test-running-sum
    ;; Cumulative sum
    (CHECK equal? (loop :for i :from 1 :to 5
                        :recur sum := 0 :then (fx+ sum i)
                        :collect sum)
           '(0 1 3 6 10))

    ;; Running sum of a list
    (CHECK equal? (loop :for x :in '(10 20 30 40)
                        :recur total := 0 :then (fx+ total x)
                        :collect total)
           '(0 10 30 60)))

  ;; ========================================
  ;; Example 4: Powers of 2
  ;; ========================================

  (define-test
    test-powers-of-2
    ;; First 8 powers of 2
    (CHECK equal? (loop :repeat 8
                        :recur power := 1 :then (fx* power 2)
                        :collect power)
           '(1 2 4 8 16 32 64 128))

    ;; Powers of 3
    (CHECK equal? (loop :repeat 5
                        :recur power := 1 :then (fx* power 3)
                        :collect power)
           '(1 3 9 27 81)))

  ;; ========================================
  ;; Example 5: Sliding Window
  ;; ========================================

  (define-test
    test-sliding-window
    ;; Pair each element with its predecessor
    (CHECK equal? (loop :for i :in '(10 20 30 40 50)
                        :recur prev := #f :then i
                        :collect (cons prev i))
           '((#f . 10) (10 . 20) (20 . 30) (30 . 40) (40 . 50)))

    ;; Track previous character in string
    (CHECK equal? (loop :for ch :in-string "ABCD"
                        :recur prev := #\space :then ch
                        :collect (cons prev ch))
           '((#\space . #\A) (#\A . #\B) (#\B . #\C) (#\C . #\D))))

  ;; ========================================
  ;; Additional Tests
  ;; ========================================

  (define-test
    test-multiple-recur
    ;; Multiple recur variables working together
    (CHECK equal? (loop :for i :from 1 :to 5
                        :recur sum := 0 :then (fx+ sum i)
                        :recur product := 1 :then (fx* product i)
                        :collect (cons sum product))
           '((0 . 1) (1 . 1) (3 . 2) (6 . 6) (10 . 24))))

  (define-test
    test-recur-with-condition
    ;; Recur with conditional collection
    (CHECK equal? (loop :for i :from 1 :to 10
                        :recur sum := 0 :then (fx+ sum i)
                        :collect sum :if (even? i))
           '(1 6 15 28 45)))

  (define-test
    test-recur-edge-cases
    ;; Empty iteration - initial value should be used in :finally
    (CHECK equal? (loop :for i :from 1 :to 0
                        :recur x := 42 :then (fx+ x 1)
                        :finally x)
           42)

    ;; Single iteration
    (CHECK equal? (loop :repeat 1
                        :recur x := 10 :then (fx+ x 5)
                        :collect x)
           '(10))))
