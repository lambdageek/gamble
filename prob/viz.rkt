;; Copyright (c) 2014 Ryan Culpepper
;; See the file COPYRIGHT for details.

#lang racket/base
(require (rename-in plot)
         data/order)
(provide hist
         hist-pict
         bin)

(define (hist xs #:invert? [invert? #f])
  (hist* xs invert? plot))
(define (hist-pict xs #:invert? [invert? #f])
  (hist* xs invert? plot-pict))

(define (hist* xs invert? plot)
  (define table (make-hash))
  (for ([x xs])
    (hash-set! table x (add1 (hash-ref table x 0))))
  (define entries (hash-map table vector))
  (define sorted-entries (sort entries (order-<? datum-order)))
  (plot (discrete-histogram sorted-entries #:invert? invert?)))

;; Alternatively, use (plot (density ...))
(define (bin xs [nbins0 #f])
  (define n (length xs))
  (define nbins (max 2 (or nbins0 (inexact->exact (ceiling (log n))))))
  (define lo (apply min xs))
  (define hi (apply max xs))
  (define binlen (/ (- hi lo) (sub1 nbins)))
  (define lo* (- lo (/ binlen 2)))
  (define hi* (+ hi (/ binlen 2)))
  (define t (make-hash)) ;; bin# => count
  (for ([x (in-list xs)])
    (define index (inexact->exact (floor (/ (- x lo*) binlen))))
    (hash-set! t index (add1 (hash-ref t index 0))))
  (plot (discrete-histogram
         (for/list ([(index count) (in-hash t)])
           (list (+ lo (* index binlen)) count)))))
