#!r6rs
(import (rnrs (6)) (rime loop))

;; Test :step keyword registration
;; This test catches missing keyword registration that unit tests miss
(display "Testing :step keyword: ")
(let ([result (loop :for i :from 1 :to 5 :count :step 2)])
  (if (equal? result 10)
      (begin
        (display "PASS\n")
        (exit 0))
      (begin
        (display "FAIL - expected 10, got ")
        (write result)
        (newline)
        (exit 1))))
