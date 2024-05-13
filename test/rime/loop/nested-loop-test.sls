#!r6rs
(library (test rime loop nested-loop-test)
  (export main)
  (import (rnrs (6))
          (rime unit-test)
          (rime loop)
          )
  (define (main)
    (run-all-tests))
  (define-test
    test-nested-loop
    (let ()
      (CHECK equal? (loop :for i :in '(0 1 2)
                          :for j :in '(A B C)
                          (:loop :for x :in '("one" "two" "three")
                                 :for y :in '("Apple" "Boy" "Cat")
                                 :if (not (= i 0))
                                 :collect (list i j x y)))
             '((1 B "one" "Apple")
               (1 B "two" "Boy")
               (1 B "three" "Cat")
               (2 C "one" "Apple")
               (2 C "two" "Boy")
               (2 C "three" "Cat")
               ))
      )))
