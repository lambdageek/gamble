;; Copyright (c) 2014 Ryan Culpepper
;; See the file COPYRIGHT for details.

#lang racket/base
(require racket/list
         racket/class
         racket/match
         data/order
         "context.rkt"
         "util.rkt"
         "sampler.rkt"
         "prob-hooks.rkt"
         "prob-util.rkt")
(provide mh-sampler*)

;; Unlike bher, use two databases---better for detecting collisions (debugging).

;; An Entry is (entry ERPTag Dist Any Boolean)
;; where the value is appropriate for the ERP denoted by the tag,
;; and pinned? indicates whether the value originated from a special condition
;; (and thus cannot be perturbed).
(struct entry (tag dist value pinned?) #:prefab)

(define (print-db db)
  (define entries (hash-map db list))
  (define sorted-entries
    (sort entries (order-<? datum-order) #:key car))
  (for ([entry (in-list sorted-entries)])
    (printf "~s => ~s\n" (car entry) (cadr entry))))

;; ----

#|
MH Acceptance

Let X, X' be full traces (dbs)

X  = Xsame  U Xdiff  U Xstale  U Xfresh
X' = Xsame' U Xdiff' U Xstale' U Xfresh'

  Xsame = Xsame' -- part of trace that stayed same
  Xdiff != Xdiff' -- part of trace w/ changed params, kept value
                  -- OR is the directly perturbed part
  Xstale -- part of old trace not reused
  Xfresh' -- new part of new trace

  Note: Xfresh = empty, Xstale' = empty

MH acceptance ratio (from Sean):

  P(X' | Obs)   Q(X | X')
  ----------- * ---------
  P(x  | Obs)   Q(X' | X)

  where Q is whole-trace proposal distribution

MH acceptance ratio from Bher paper:

  P(X')   Kt(x|x', theta)   P(Xstale)
  ----- * --------------- * ----------
  P(X)    Kt(x'|x, theta)   P(Xfresh')

  where x,x' are values of a single ERP

Many things cancel, resulting in

  P(Xdiff')   Kt(x|x', theta)
  --------- * ---------------
  P(Xdiff)    Kt(x'|x, theta)

So, need to accumulate

  lldiff = log Kt(x|x', theta) - log Kt(x'|x, theta)
           + log P(Xdiff') - log P(Xdiff')

depending on only choices reused w/ different params.
|#

;; default-reject-mode : one of the following
;; - 'retry-from-top : re-pick db key to change on rejection
;; - 'retry/same-choice : keep same db key to change on rejection
;; - 'last : replay last state (ie, produce same sample as prev)
(define default-reject-mode 'last)

;; default-threshold-mode : one of the following
;; - 'retain : R - F + ll_new - ll_old + ll_stale - ll_fresh
;; - 'purge : same, but purge unused entries from db
(define default-threshold-mode 'purge)

;; default-perturb-mode : list containing some subset of the following
;; - 'normal : use specialized proposal distribution for normal dist
;; (the default is to simply resample)
(define default-perturb-mode '(normal))

;; ----

(define (mh-sampler* thunk spconds)
  (new mh-sampler% (thunk thunk) (spconds spconds)))

(define mh-sampler%
  (class* object% (sampler<%>)
    (init-field thunk
                spconds)
    (field [last-db #f]
           [accepts 0]
           [cond-rejects 0]
           [mh-rejects 0]
           [perturb-mode default-perturb-mode]
           [reject-mode default-reject-mode]
           [threshold-mode default-threshold-mode]
           [last-sample #f])
    (super-new)

    (define/public (get-modes) (values reject-mode threshold-mode))
    (define/public (set-modes! reject-mode* threshold-mode*)
      (when reject-mode* (set! reject-mode reject-mode*))
      (when threshold-mode* (set! threshold-mode threshold-mode*)))

    (define/public (sample)
      (sample/picked-key (and last-db (pick-a-key last-db))))

    (define/private (sample/picked-key key-to-change)
      (define (reject)
        (case reject-mode
          [(retry-from-top) (sample)]
          [(retry/same-choice) (sample/picked-key key-to-change)]
          [(last) last-sample]))
      ;; FIXME: avoid so many hash-copies
      (when (verbose?)
        (eprintf "# perturb: changing ~s\n" key-to-change))
      (define perturbed-last-db (if last-db (hash-copy last-db) '#hash()))
      (define R-F (if key-to-change (perturb! perturbed-last-db key-to-change) 0))
      (define current-db (make-hash))
      ;; Run program
      (define result
        (let/ec escape
          (parameterize ((current-ERP (make-db-ERP perturbed-last-db current-db spconds))
                         (current-mem db-mem)
                         (current-fail (lambda (r) (escape (cons 'fail r)))))
            (cons 'okay (apply/delimit thunk)))))
      ;; Accept/reject
      ;; FIXME: check condition or MH step first?
      (match result
        [(cons 'okay sample-value)
         (define threshold (accept-threshold R-F current-db last-db key-to-change))
         (when (verbose?)
           (eprintf "# accept threshold = ~s\n" (exp threshold)))
         (define u (log (random)))
         (cond [(< u threshold)
                (when (verbose?)
                  (eprintf "# Accepted MH step with ~s\n" (exp u)))
                (set! last-db current-db)
                (set! accepts (add1 accepts))
                (set! last-sample sample-value)
                (when (verbose?)
                  (eprintf "# Accepted condition\n"))
                sample-value]
               [else
                (set! mh-rejects (add1 mh-rejects))
                (when (verbose?)
                  (eprintf "# Rejected MH step with ~s\n" (exp u)))
                (reject)])]
        [(cons 'fail fail-reason)
         (set! cond-rejects (add1 cond-rejects))
         (when (verbose?)
           (eprintf "# Rejected condition (~s)" fail-reason))
         (reject)]))

    ;; perturb! : DB Address -> Real
    ;; Updates db and returns (log) R-F.
    (define/private (perturb! db key-to-change)
      (match (hash-ref db key-to-change)
        [(entry tag dist value #f)
         (or (perturb!/proposal db key-to-change tag dist value)
             (perturb!/resample db key-to-change tag dist value))]))

    ;; perturb!/resample : DB Address Tag Dist Any -> Real
    (define/private (perturb!/resample db key-to-change tag dist value)
      ;; Fallback: Just resample from same dist.
      ;; Then Kt(x|x') = Kt(x) = (dist-pdf dist value)
      ;;  and Kt(x'|x) = Kt(x') = (dist-pdf dist value*)
      (define value* (dist-sample dist))
      (define R (dist-pdf dist value #t))
      (define F (dist-pdf dist value* #t))
      (when (verbose?)
        (eprintf "  RESAMPLED from ~e to ~e\n" value value*)
        (eprintf "  R = ~s, F = ~s\n" (exp R) (exp F)))
      (hash-set! db key-to-change (entry tag dist value* #f))
      (- R F))

    ;; perturb!/proposal : DB Address Tag Dist Any -> (U Real #f)
    ;; If applicable proposal dist avail, updates db and returns (log) R-F,
    ;; otherwise returns #f and perturb! should just resample.
    (define/private (perturb!/proposal db key-to-change tag dist value)
      ;; update! : ... -> Real
      (define (update! R F value*)
        (when (verbose?)
          (eprintf "  PROPOSED from ~e to ~e\n" value value*)
          (eprintf "  R = ~s, F = ~s\n" (exp R) (exp F)))
        (hash-set! db key-to-change (entry tag dist value* #f))
        (- R F))
      (match tag
        [`(normal ,mean ,stddev)
         (and (memq 'normal perturb-mode)
              (let ()
                (define forward-dist
                  (make-normal-dist value (/ stddev 4.0)))
                (define value* (dist-sample forward-dist))
                (define backward-dist
                  (make-normal-dist value* (/ stddev 4.0)))
                (define R (dist-pdf backward-dist value #t))
                (define F (dist-pdf forward-dist value* #t))
                (update! R F value*)))]
        [_ #f]))

    ;; accept-threshold : ... -> Real
    ;; Computes (log) accept threshold for current trace.
    (define/private (accept-threshold R-F current-db maybe-prev-db key-to-change)
      (if (and maybe-prev-db (positive? (hash-count current-db)))
          (accept-threshold* R-F current-db maybe-prev-db key-to-change)
          +inf.0))

    (define/private (accept-threshold* R-F current-db prev-db key-to-change)
      (define prev-ll (db-ll prev-db))
      (define current-ll (db-ll current-db))

      (define stale (db-ll/difference prev-db current-db key-to-change))
      (define fresh (db-ll/difference current-db prev-db key-to-change))

      (define R-F/pick
        ;; Account for backward and forward likelihood of picking
        ;; the random choice to perturb that we picked.
        ;; Note: assumes we pick uniformly from all choices.
        (case threshold-mode
          [(purge)
           (define R (/ 1.0 (hash-count current-db)))
           (define F (/ 1.0 (hash-count prev-db)))
           (- (log R) (log F))]
          [else 0]))

      (when (eq? threshold-mode 'retain)
        ;; If retaining, copy stale choices to current-db.
        (db-copy-stale (or prev-db '#hash()) current-db))

      (+ R-F R-F/pick (- current-ll prev-ll) (- stale fresh)))

    (define/public (info)
      (define total (+ accepts cond-rejects mh-rejects))
      (cond [(zero? total)
             (printf "No traces taken.\n")]
            [else
             (printf "Accepted traces: ~s, ~a%\n"
                     accepts (* 100.0 (/ accepts total)))
             (printf "Traces rejected by condition: ~s, ~a%\n"
                     cond-rejects (* 100.0 (/ cond-rejects total)))
             (printf "Traces rejected by MH threshold: ~s, ~a%\n"
                     mh-rejects (* 100.0 (/ mh-rejects total)))]))
    ))

;; pick-a-key : DB -> (U Address #f)
;; Returns a key s.t. the value is not pinned.
;; FIXME: bleh
(define (pick-a-key db)
  (define unpinned-entry-count
    (for/sum ([(k v) (in-hash db)]
              #:when (not (entry-pinned? v)))
      1))
  (and (positive? unpinned-entry-count)
       (let ([index (random unpinned-entry-count)])
         (let loop ([iter (hash-iterate-first db)] [i index])
           (cond [(entry-pinned? (hash-iterate-value db iter))
                  (loop (hash-iterate-next db iter) i)]
                 [(zero? i)
                  (hash-iterate-key db iter)]
                 [else
                  (loop (hash-iterate-next db iter) (sub1 i))])))))

(define (db-ll db)
  (for/sum ([(k v) (in-hash db)])
    (match v
      [(entry tag dist value _)
       (when #f
         (when (verbose?)
           (eprintf "  - ~s => ~e @ ~s\n" tag value (dist-pdf dist value))))
       (dist-pdf dist value #t)])))

(define (db-count/difference db exclude)
  (for/sum ([(k v) (in-hash db)])
    (if (hash-ref exclude k #f) 0 1)))

(define (db-ll/difference db exclude exclude-key)
  (for/sum ([(k v) (in-hash db)])
    (if (equal? k exclude-key)
        0
        (match v
          [(entry tag dist value _)
           (match (hash-ref exclude k #f)
             [(entry ex-tag ex-dist ex-value _)
              (cond [(and (tags-compatible? tag ex-tag)
                          (equal? value ex-value))
                     ;; kept value and rescored; don't count as fresh/stale
                     0]
                    [else (dist-pdf dist value #t)])]
             [#f (dist-pdf dist value #t)])]))))

(define (db-copy-stale old-db new-db)
  (for ([(k v) (in-hash old-db)])
    (unless (hash-has-key? new-db k)
      (hash-set! new-db k v))))

;; ----

;; FIXME: handle same w/ different params

(define ((make-db-ERP last-db current-db spconds) tag dist)
  (define context (get-context))
  (define (mem-context?)
    (and (pair? context)
         (let ([frame (last context)])
           (and (list? frame) (memq 'mem frame)))))
  (define (new! print?)
    (cond [(assoc (current-label) spconds)
           => (lambda (e)
                (match (cdr e)
                  [(spcond:equal value)
                   ;; FIXME: value might not match internal dist support (eg flip vs bernoulli)
                   (cond [(positive? (dist-pdf dist value))
                          (when (verbose?)
                            (when print?
                              (eprintf "- NEW ~s: ~s = ~e\n" tag context value))
                            (eprintf "  CONDITIONED ~s = ~e\n" (current-label) value))
                          (hash-set! current-db context (entry tag dist value #t))
                          value]
                         [else
                          (fail 'condition)])]
                  [(spcond:drawn alt-dist)
                   (error "unimplemented")]))]
          [else
           (define value (dist-sample dist))
           (when (and print? (verbose?))
             (eprintf "- NEW ~s: ~s = ~e\n" tag context value))
           (hash-set! current-db context (entry tag dist value #f))
           value]))
  (define (collision-error context)
    (error 'ERP
           (string-append "collision in random choice database"
                          ";\n check that the sampler module uses `#lang prob'"
                          "\n  address: ~e")
           context))
  (cond [(hash-ref current-db context #f)
         => (lambda (e)
              (cond [(not (equal? (entry-tag e) tag))
                     (when (or (verbose?) #t)
                       (eprintf "- MISMATCH ~a ~s / ~s: ~s\n"
                                (if (mem-context?) "MEMOIZED" "COLLISION")
                                (entry-tag e) tag context))
                     (unless (mem-context?) (collision-error context))
                     (new! #f)]
                    [(mem-context?)
                     (when (verbose?)
                       (eprintf "- MEMOIZED ~s: ~s = ~e\n" tag context (entry-value e)))
                     (entry-value e)]
                    [else
                     (when (verbose?)
                       (eprintf "- COLLISION ~s: ~s\n" tag context))
                     (collision-error context)
                     (entry-value e)]))]
        [(hash-ref last-db context #f)
         => (lambda (e)
              (cond [(equal? (entry-tag e) tag)
                     ;; Note: equal tags implies equal dists
                     (when (verbose?)
                       (eprintf "- REUSED ~s: ~s = ~e\n" tag context (entry-value e)))
                     (hash-set! current-db context e)
                     (entry-value e)]
                    [(and (tags-compatible? (entry-tag e) tag)
                          (positive? (dist-pdf dist (entry-value e))))
                     (define value (entry-value e))
                     (when (verbose?)
                       (eprintf "- RESCORE ~s: ~s = ~e\n" tag context value))
                     (hash-set! current-db context (entry tag dist value (entry-pinned? e)))
                     value]
                    [(not (equal? (entry-tag e) tag))
                     (when (verbose?)
                       (eprintf "- MISMATCH ~s / ~s: ~s\n" (entry-tag e) tag context))
                     (new! #f)]))]
        [else (new! #t)]))

(define (tags-compatible? old-tag new-tag)
  (and (eq? (car old-tag) (car new-tag))))

(define (db-mem f)
  (let ([context (get-context)])
    (lambda args
      (apply/delimit
       (lambda ()
         (parameterize ((the-context (list (list 'mem args context))))
           (apply f args)))))))
