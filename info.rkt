;; Copyright (c) 2014 Ryan Culpepper
;; See the file COPYRIGHT for details.

#lang setup/infotab

(define collection 'multi)

(define deps '("base"
               "data-lib"
               "math-lib"
               "gui-lib"
               "plot-lib"
               "plot-gui-lib"
               "pict-lib"
               "rackunit-lib"
               "typed-racket-lib"))
(define build-deps '("racket-doc"
                     "scribble-lib"
                     "pict-doc"
                     "plot-doc"
                     "math-doc"))
