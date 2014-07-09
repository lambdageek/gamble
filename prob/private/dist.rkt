;; Copyright (c) 2014 Ryan Culpepper
;; Released under the terms of the 2-clause BSD license.
;; See the file COPYRIGHT for details.

#lang racket/base
(require racket/generic)
(provide (all-defined-out))

(define-generics dist
  (*pdf dist x log?)
  (*cdf dist x log? 1-p?)
  (*inv-cdf dist x log? 1-p?)
  (*sample dist)
  (*type dist)
  (*params dist)
  (*enum dist)
  (*support dist)
  (*mean dist)
  (*median dist)
  (*mode dist)
  (*variance dist)
  (*conj dist obs-dist data))

(define (dist-pdf d x [log? #f])
  (*pdf d x log?))
(define (dist-cdf d x [log? #f] [1-p? #f])
  (*cdf d x log? 1-p?))
(define (dist-inv-cdf d x [log? #f] [1-p? #f])
  (*inv-cdf d x log? 1-p?))
(define (dist-sample d)
  (*sample d))
(define (dist-enum d)
  (*enum d))

;; Support is one of
;; - #f        -- unknown/unrestricted
;; - 'finite   -- unknown but finite
;; - #s(integer-range Min Max)  -- inclusive
;; - #s(real-range Min Max)     -- inclusive (may overapprox)
;; - TODO: #s(product #(Support ...)), ...
(struct integer-range (min max) #:prefab)
(struct real-range (min max) #:prefab)

;; dist-support : Dist -> Support
(define (dist-support d)  (*support d))

;; Returns #t if dist is necessarily {integer,real}-valued.
;; Note: a discrete-dist that happens to have integer values is NOT integer-dist?.
(define (integer-dist? d)
  (and (dist? d) (integer-range? (dist-support d))))
(define (real-dist? d)
  (and (dist? d) (real-range? (dist-support d))))
(define (finite-dist? d)
  (define support (and (dist? d) (dist-support d)))
  (or (eq? support 'finite)
      (and (integer-range? support)
           (exact-integer? (integer-range-min support))
           (exact-integer? (integer-range-max support)))))

;; dist-<statistic> : Dist -> Real | #f | NaN
;; #f means unknown; NaN means known to be undefined
(define (dist-mean d)     (*mean d))
(define (dist-median d)   (*median d))
(define (dist-mode d)     (*mode d))
(define (dist-variance d) (*variance d))

(define (dist-update-prior d data-d data)
  (*conj d data-d data))