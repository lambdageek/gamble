;; Copyright (c) 2014 Ryan Culpepper
;; See the file COPYRIGHT for details.

#lang racket/base
(require racket/match
         data/order
         unstable/markparam
         "prob-hooks.rkt"
         "pairingheap.rkt"
         "util.rkt")
(provide (struct-out only)
         (struct-out split)
         (struct-out failed)
         reify-tree
         split->subtrees
         cond->subtrees)

;; == mem ==
;;
;; For mem, have an activation-specific store that gets rewound after
;; each ERP choice exploration. (cf logic continuations, or store
;; continuations?)
;;
;; Use mark-parameter to store the memotable. (See notes on parameters
;; below.)  Since prompts also delimit CCM, need a separate prompt tag
;; (sigh... it's complicated).
;;
;; What should it mean for a memoized function to escape the enumeration
;; in which it was created? Should probably be forbidden.

;; == Nesting enumerations ==
;;
;; How to make enumeration nest?
;;
;; (enum ;; outer
;;  ...
;;  (enum ;; inner
;;   ...))
;;
;; - Straightforward except for mem:
;;
;;   - An outer-created memoized function that is invoked in the inner
;;     enum should fork its possibilities to the *outer* prompt.
;;   - Except... what if the outer-mem-fun calls its argument, which is an
;;     inner-mem-fun? Then that "should" fork its possibilities to inner
;;     prompt.
;;   - Bleh, mem probably only makes sense on first-order functions.
;;   - Alternatively, in that case we say the inner-mem-fun has escaped
;;     its context, error. (In general, mem-fun that escapes its context
;;     is problematical, except for direct-style mem.)
;;   - What if outer-mem-fun is (lambda (n) (lambda () (flip (/ n))))?
;;     Then if applied, gets thunk, then applied in inner, inner explores
;;     branches. That seems reasonable.
;;
;;   - Anyway... when an outer-mem-fun is invoked, it needs to restore
;;     the outer ERP (and mem) impls.
;;     - That means nested enum can't use parameterize ... :/
;;       ??? Doesn't work without parameterize ... investigate?
;;     - A memoized function must close over the activation support (ctag,
;;       markparam) for the mem that created it.
;;   - Each enumeration activation needs a separate prompt tag and
;;     memo-table key.
;;   - explore must be rewritten in pure code: find functional priority
;;     queue (PFDS from planet?), use immutable hash, etc


;; == Notes on Parameters and Delimited Continuations ==

;; In the general case, Racket's parameters do not work interact
;; "correctly" with delimited continuations, in the sense that a
;; parameter P's value is not determined by the nearest (parameterize
;; ((P _)) []) in the context. (Parameters are grouped together into a
;; parameterization, and the nearest parameterization is fetched. This
;; is a known Racket WONTFIX.)
;;
;; However, the way 'enumerate' uses parameters is safe, since
;; captured continuations are invoked in dynamic contexts that are
;; mostly "compatible" with the ones they were captured in. But note:
;;
;;  - The invocation context needs a different memo-table, so the
;;    memo-table must be stored using a mark-parameter rather than an
;;    ordinary parameter.
;;  - The 'explore' function cannot use parameterize to affect the execution
;;    of the code that produces the lazy tree. The parameterization is
;;    essentially captured by the call to 'reify-tree'.

;; ============================================================

;; Each enumeration activation has a prompt-tag and memo-table key.
;; The current prompt-tag is stored by ctag-key.

;; An Activation is (activation PromptTag MarkParam)
;; where (memo-key) : (Boxof (Hashof ArgList => Result))
(struct activation (prompt memo-table-key))

;; (current-activation) : Activation
(define current-activation (make-parameter #f))

;; A (EnumTree A) is one of
;; - (only A)
;; - (split Any Tag Dist (-> Value (EnumTree A)))
;; - (failed Any)
(struct only (answer))
(struct split (label tag dist k))
(struct failed (reason))

;; ----------------------------------------

;; reify-tree : (-> A) (Listof Condition) -> (EnumTree A)
(define (reify-tree thunk)
  (define memo-key (mark-parameter))
  (define memo-table (hash))
  (define ctag (make-continuation-prompt-tag))
  (define act (activation ctag memo-key))
  (call-with-enum-context act memo-table (lambda () (only (thunk)))))

;; calls thunk with memo-table in fresh box, parameters set up
(define (call-with-enum-context act memo-table thunk)
  (define ctag (activation-prompt act))
  (define memo-key (activation-memo-table-key act))
  (parameterize ((current-ERP enum-ERP)
                 (current-mem enum-mem)
                 (current-fail enum-fail)
                 (current-activation (activation ctag memo-key)))
    (mark-parameterize ((memo-key (box memo-table)))
      (call-with-continuation-prompt thunk (activation-prompt act)))))

;; ----

(define (enum-fail reason)
  (abort-current-continuation (activation-prompt (current-activation))
   (lambda () (failed reason))))

(define (enum-ERP tag dist)
  (define act (current-activation))
  (define ctag (activation-prompt act))
  (define memo-key (activation-memo-table-key act))
  (define memo-table (unbox (memo-key)))
  (define label (current-label))
  (call-with-composable-continuation
   (lambda (k)
     (abort-current-continuation
      ctag
      (lambda ()
        (split label tag dist
               (lambda (v)
                 (call-with-enum-context act memo-table
                   (lambda () (k v))))))))
   ctag))

(define (enum-mem f)
  (define act (current-activation))
  (define ctag (activation-prompt act))
  (define memo-key (activation-memo-table-key act))
  (define f-key (gensym))
  (define (memoized-function . args)
    (unless (continuation-prompt-available? ctag)
      (error 'mem
             "memoized function escaped its creating context\n  function: ~e\n  arguments: ~e\n"
             f args))
    (let ([b (memo-key)]
          [key (cons f-key args)])
      (cond [(hash-has-key? (unbox b) key)
             (hash-ref (unbox b) key)]
            [else
             ;; Call with saved activation; may be outer enumeration!
             (define v (mark-parameterize ((current-activation act)) (apply f args)))
             ;; NOTE: outer b might be stale, if f called ERP!
             (define b (memo-key))
             (set-box! b (hash-set (unbox b) key v))
             v])))
  memoized-function)

;; ----

;; split->subtrees : split Condition -> (Listof (List Prob (-> (EnumTree A))))
(define (split->subtrees s spconds)
  (match s
    [(split label tag dist k)
     (cond [(assoc label spconds)
            => (lambda (e) (cond->subtrees dist k (cdr e)))]
           [else
            (split->subtrees* tag dist k)])]))

(define (cond->subtrees dist k c)
  (match c
    [(spcond:equal value)
     (define l (dist-pdf dist value))
     (cond [(positive? l)
            ;; Note: create split w/ prob sum 1 so that explore gets prob-explored right.
            (list (cons l (lambda () (k value)))
                  (cons (- 1 l) (lambda () (failed #f))))]
           [else
            (list (cons 1 (lambda () (failed 'condition))))])]))

;; split->subtrees : Any Dist (-> Value (EnumTree A)) -> (Listof (Cons Prob (-> (EnumTree A))))
(define (split->subtrees* tag dist k)
  (define enum (dist-enum dist))
  (cond [(eq? enum 'lazy)
         (define-values (vals probs tail-prob tail-tag)
           (lazy-dist->vals+probs tag dist 0))
         (cons (cons tail-prob (lambda () (k (enum-ERP tail-tag dist))))
               (for/list ([val (in-list vals)]
                          [prob (in-list probs)])
                 (cons prob (lambda () (k val)))))]
        [(eq? enum #f)
         (error 'ERP "cannot enumerate non-integer distribution: ~s" tag)]
        [else ;; positive integer
         (for/list ([i (in-range enum)])
           (cons (dist-pdf dist i) (lambda () (k i))))]))

(define TAKE 10)

(define (lazy-dist->vals+probs tag dist start)
  (match tag
    [(list* 'continue-special _ (and base-tag (list* 'geometric _)))
     ;; Special case: for geometric, no need to resume
     (lazy-dist->vals+probs base-tag dist 0)]
    [(list* 'continue-special start base-tag)
     (lazy-dist->vals+probs base-tag dist start)]
    [_
     (define scale (- 1 (dist-cdf dist (sub1 start))))
     (define-values (vals probs)
       (for/lists (vals probs) ([i (in-range start (+ start TAKE))])
         (values i (/ (dist-pdf dist i) scale))))
     (values vals
             probs
             (/ (- 1 (dist-cdf dist (+ start TAKE -1))) scale)
             `(continue-special ,(+ start TAKE) . ,tag))]))
