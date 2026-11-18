#!r6rs
(library (test rime syntax __syntax-location-test)
  (export main)
  (import (rnrs (6))
          (for (rnrs (6)) expand)
          (for (rime syntax __syntax-location) expand)
          (rime unit-test))

  (define (main)
    (run-all-tests))

  ;; expands to the location string of a syntax object that has no source information
  (define-syntax location-of-generated-syntax
    (lambda (e)
      (syntax-case e ()
        [(k)
         (datum->syntax
          #'k
          (syntax-location-as-string (datum->syntax #'k 'generated)))])))

  ;; expands to the location string of a syntax object read from this file
  (define-syntax location-of-source-syntax
    (lambda (e)
      (syntax-case e ()
        [(k)
         (datum->syntax #'k (syntax-location-as-string #'k))])))

  (define-test test-location-without-source-information
    ;; guile 3.0.1 returns #f from syntax-source here, which used to raise
    (CHECK eq? (string? (location-of-generated-syntax)) #t))

  (define-test test-location-with-source-information
    (CHECK eq? (string? (location-of-source-syntax)) #t)))
