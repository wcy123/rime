#!r6rs
;; The converter record, shared by the runtime, which makes converters and runs them, and by the
;; usage, which shows their labels.
(library (rime command-line-options __converter)
  (export make-converter converter-label converter-convert)
  (import (rnrs records syntactic (6)))

  ;; A converter turns the text of an argument into a value, and it deals with everything about that:
  ;;   label    how an argument is shown in the usage: "<int>", "{json,text}"
  ;;   convert  (convert text option-name table) => the value; when the text does not suit, it raises
  ;;            the error the user sees with (fail table ...), so each kind of converter has its own
  ;;            failure
  ;; The runtime only uses these two, it does not know which kinds of converter there are.
  (define-record-type converter
    (fields label convert)))
