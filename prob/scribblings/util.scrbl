;; Copyright (c) 2014 Ryan Culpepper
;; Released under the terms of the 2-clause BSD license.
;; See the file COPYRIGHT for details.

#lang scribble/doc
@(require scribble/manual
          scribble/basic
          scribble/eval
          (for-label racket/contract
                     racket/class
                     math/distributions
                     prob
                     prob/viz))

@(define the-eval (make-base-eval))
@(the-eval '(require prob (only-in prob/viz [hist-pict hist])))

@title[#:tag "util"]{Probabilistic Utilities}

@defproc[(probability? [v any/c])
         boolean?]{

Returns @racket[#t] if @racket[v] is a real number between 0 and 1
(inclusive), @racket[#f] otherwise.
}

@defparam[verbose? v? boolean?]{

Parameter that controls whether informative messages are printed by
solvers and ERPs.
}


@section[#:tag "sample-utils"]{Sampler Utilities}

@defproc[(repeat [thunk (-> any/c)]
                 [n exact-nonnegative-integer?])
         list?]{

Calls @racket[thunk] @racket[n] times, accumulating the results in a
list.

@examples[#:eval the-eval
(repeat flip 10)
]
}

@defproc[(lag [thunk (-> any/c)]
              [n exact-positive-integer?])
         (-> any/c)]{

Lags a @tech{sampler}; when the resulting thunk is called, the given
@racket[thunk] is called @racket[n] times and only the last value is
returned.

@examples[#:eval the-eval
(repeat (lag (let ([n 0]) (lambda () (set! n (add1 n)) n)) 10) 10)
]
}

@defproc[(sampler->discrete-dist [sampler (-> _A)]
                                 [n exact-positive-integer?]
                                 [f (-> _A _B) (lambda (x) x)])
         (listof (list/c _B probability?))]{

Generates @racket[n] samples using @racket[(f (sampler))], and
produces a list of the results with probability weights.

@examples[#:eval the-eval
(sampler->discrete-dist (lambda () (flip 1/2)) 100)
]
}

@defproc[(sampler->mean+variance [sampler (-> _A)]
                                 [f (-> _A real?) (lambda (x) x)])
         (values real? real?)]{

Generates @racket[n] samples using @racket[(f (sampler))], and returns
the mean and variance. If @racket[sampler] does not return real-valued
samples, then @racket[f] must be given and must convert samples into
real values.

@examples[#:eval the-eval
(sampler->mean+variance (lambda () (flip 1/2))
                        100
                        (indicator/value #t))
]
}

@deftogether[[
@defproc[(weighted-sampler->discrete-dist
                [sampler (-> (list/c _A probability?))]
                [f (-> _A _B) (lambda (x) x)])
         (listof (list/c _B probability?))]
@defproc[(weighted-sampler->mean+variance
                [sampler (-> (list/c _A probability?))]
                [f (-> _A real?) (lambda (x) x)])
         (values real? real?)]
]]{

Like @racket[sampler->discrete-dist] and
@racket[sampler->mean+variance], respectively, but for weighted
samplers.
}

@deftogether[[
@defproc[(indicator/value [v any/c])
         (-> any/c (or/c 1 0))]
@defproc[(indicator/predicate [pred (-> any/c boolean?)])
         (-> any/c (or/c 1 0))]
]]{

Produces an indicator function for the value @racket[v] or the set of
values accepted by the predicate @racket[pred], respectively.

@examples[#:eval the-eval
(define z (indicator/value 0))
(z 0)
(z 2.74)
(z 'apple)
]
}


@section[#:tag "lazy"]{Laziness via Memoization}

@defform[(pdelay body ...+)]{

Delays the @racket[body] computation, producing a promise
(@racket[ppromise?]) that can be forced with @racket[pforce].
The @racket[pdelay] form uses @racket[mem] internally, the promises
cooperate with the enclosing solver/sampler context.

Use @racket[pdelay] to make a random choice lazy when it may not be
relevant to all execution paths.

@examples[#:eval the-eval
(time (code:comment "eager, explores 2^10 possibilities")
 (enumerate
  (define flips (for/list ([i 10]) (flip)))
  (andmap (lambda (x) x) flips)))
(time (code:comment "lazy, explores 11 possibilities")
 (enumerate
  (define flips (for/list ([i 10]) (pdelay (flip))))
  (andmap pforce flips)))
]
}

@defproc[(ppromise? [v any/c]) boolean?]{

Returns @racket[#t] if @racket[v] is a promise produced by
@racket[pdelay], @racket[#f] otherwise.
}


@defproc[(pforce [p ppromise?]) any]{

Evaluates @racket[p]'s body and caches the result, if @racket[p] has
not been previously forced, or returns the cached result otherwise.
}


@(close-eval the-eval)