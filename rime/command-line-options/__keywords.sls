#!r6rs
;; The field keywords of an option clause. Defined once here, so that the reader (__parse.sls)
;; matches them by binding, and re-exported by (rime command-line-options) for the users.
(library (rime command-line-options __keywords)
  (export :short :long :arity :type :choices :description :required :positional :default)
  (import (rnrs (6))
          (rime syntax __define-auxiliary-syntax))

  (define-auxiliary-syntax :short :long :arity :type :choices :description :required :positional :default))
