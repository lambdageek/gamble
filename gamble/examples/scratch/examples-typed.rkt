;; Copyright (c) 2014 Ryan Culpepper
;; See the file COPYRIGHT for details.

#lang gamble/typed

;; Preliminary typed version of language.
;; Not all bindings are provided.

(enumerate
 (define A (flip))
 (define B (flip))
 A
 #:when (or A B))

(define s-mh
  (mh-sampler
   (define A (flip))
   (define B (flip))
   A
   #:when (or A B)))
(s-mh)

(: geom : -> Nonnegative-Integer)
(define (geom)
  (if (flip) 0 (add1 (geom))))
