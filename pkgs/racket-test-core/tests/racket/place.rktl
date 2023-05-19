(load-relative "loadtest.rktl")
(Section 'places)
(require tests/racket/place-utils)

(place-wait
 (place/splat (p1 ch) (printf "Hello from place\n")))

(let ()
  (define-values (in out) (place-channel))
  (struct ts (a))
  (err/rt-test (place-channel-put in (ts "k")))

  (define places-share-symbols?
    (or (not (place-enabled?))
        (eq? 'chez-scheme (system-type 'vm))))

  (let ()
    (define us (string->uninterned-symbol "foo"))
    (define us2 (string->uninterned-symbol "foo"))
    (place-channel-put in (cons us us))
    (define r (place-channel-get out))
    (test #t equal? (car r) (cdr r))
    (test places-share-symbols? equal? us (car r))
    (test places-share-symbols? equal? us (cdr r))
    (test #f symbol-interned? (car r))
    (test #f symbol-interned? (cdr r))

    (place-channel-put in (cons us us2))
    (define r2 (place-channel-get out))
    (test #f symbol-interned? (car r2))
    (test #f symbol-interned? (cdr r2))
    (test #f equal? (car r2) (cdr r2))
    (test places-share-symbols? equal? us (car r2))
    (test places-share-symbols? equal? us2 (cdr r2)))

  (let ()
    (define us (string->unreadable-symbol "foo2"))
    (define us2 (string->unreadable-symbol "foo3"))
    (place-channel-put in (cons us us))
    (define r (place-channel-get out))
    (test #t equal? (car r) (cdr r))
    (test #t equal? us (car r))
    (test #t equal? us (cdr r))
    (test #t symbol-unreadable? (car r))
    (test #t symbol-unreadable? (cdr r))
     
    (place-channel-put in (cons us us2))
    (define r2 (place-channel-get out))
    (test #t symbol-unreadable? (car r2))
    (test #t symbol-unreadable? (cdr r2))
    (test #f equal? (car r2) (cdr r2))
    ;interned into the same table as us and us2
    ;because the same place sends and receives
    (test #t equal? us (car r2))
    (test #t equal? us2 (cdr r2)))

  (place-channel-put out (make-prefab-struct 'bx (box 1) (box 2)))
  (test (make-prefab-struct 'bx (box 1) (box 2)) place-channel-get in)

  (place-channel-put out (make-prefab-struct 'vec (vector) (vector)))
  (test (make-prefab-struct 'vec (vector) (vector)) place-channel-get in))

(let ([p (place/splat (p1 ch)
          (printf "Hello form place 2\n")
          (exit 99))])
  (test #f place? 1)
  (test #f place? void)
  (test #t place? p)
  (test #t place-channel? p)

  (err/rt-test (place-wait 1))
  (err/rt-test (place-wait void))
  (test 99 place-wait p)
  (test 99 place-wait p))

(arity-test dynamic-place 2 2)
(arity-test place-wait 1 1)
(arity-test place-channel 0 0)
(arity-test place-channel-put 2 2)
(arity-test place-channel-get 1 1)
(arity-test place-channel? 1 1)
(arity-test place? 1 1)
(arity-test place-channel-put/get 2 2)
(arity-test processor-count 0 0)

(err/rt-test (dynamic-place "foo.rkt"))
(err/rt-test (dynamic-place null 10))
(err/rt-test (dynamic-place "foo.rkt" 10))
(err/rt-test (dynamic-place '(quote some-module) 'tfunc))

        
(let ([p (place/splat (p1 ch)
          (printf "Hello form place 2\n")
          (sync never-evt))])
  (place-kill p)
  (place-kill p)
  (place-kill p))

(for ([v (list #t #f null 'a #\a 1 1/2 1.0 (expt 2 100) 
               "apple" (make-string 10) #"apple" (make-bytes 10)
               (void) (gensym) (string->uninterned-symbol "apple")
               (string->unreadable-symbol "grape"))])
  (test #t place-message-allowed? v)
  (test #t place-message-allowed? (list v))
  (test #t place-message-allowed? (box v))
  (test #t place-message-allowed? (vector v)))
(test #t place-message-allowed? (box #f))
(test #t place-message-allowed? (vector))

(for ([v (list (lambda () 10)
               add1)])
  (test (not (place-enabled?)) place-message-allowed? v)
  (test (not (place-enabled?)) place-message-allowed? (list v))
  (test (not (place-enabled?)) place-message-allowed? (cons 1 v))
  (test (not (place-enabled?)) place-message-allowed? (cons v 1))
  (test (not (place-enabled?)) place-message-allowed? (box v))
  (test (not (place-enabled?)) place-message-allowed? (vector v)))

(let ()
  (struct s (a) #:prefab)
  (struct p (x))
  (define c (chaperone-struct (p 1)
                              p-x
                              (lambda (s v) v)))
  (test (not (place-enabled?)) place-message-allowed? (s (lambda () 1)))
  (test (not (place-enabled?)) place-message-allowed? (s c))
  (test (not (place-enabled?)) place-message-allowed? (hasheq c 5))
  (test (not (place-enabled?)) place-message-allowed? (hasheq 5 c))
  (test (not (place-enabled?)) place-message-allowed? (vector c))
  (test (not (place-enabled?)) place-message-allowed? (cons c 6))
  (test (not (place-enabled?)) place-message-allowed? (cons 6 c)))

;; ----------------------------------------
;; Place messages and chaperones

(test #t place-message-allowed? (chaperone-vector (vector 1 2) (lambda (v i e) e) (lambda (v i e) e)))
(test #t place-message-allowed? (chaperone-hash (hasheq 1 2 3 4)
                                                (lambda (ht k) (values k (lambda (ht k v) v)))
                                                (lambda (ht k v) (values k v))
                                                (lambda (ht k) k)
                                                (lambda (ht k) k)))
(test #t place-message-allowed? (chaperone-hash (make-hash)
                                                (lambda (ht k) (values k (lambda (ht k v) v)))
                                                (lambda (ht k v) (values k v))
                                                (lambda (ht k) k)
                                                (lambda (ht k) k)))
(let ()
  (struct posn (x y) #:prefab)
  (test #t place-message-allowed? (chaperone-struct '#s(posn 1 2)
                                                    posn-x (lambda (p x) x))))

(let ()
  (define-values (in out) (place-channel))

  (place-channel-put out (impersonate-vector (vector 1 2) (lambda (v i e) (add1 e)) (lambda (v i e) e)))
  (test '#(2 3) place-channel-get in)

  (let ([ht (make-hash)])
    (hash-set! ht 1 2)
    (hash-set! ht 3 4)
    (place-channel-put out (impersonate-hash ht
                                             (lambda (ht k) (values k (lambda (ht k v) (add1 v))))
                                             (lambda (ht k v) (values k v))
                                             (lambda (ht k) k)
                                             (lambda (ht k) k)))
    (test '#hash((1 . 3) (3 . 5))
          place-channel-get in))

  (let ()
    (struct posn (x y) #:prefab)
    (place-channel-put out (chaperone-struct (posn 1 2)
                                             posn-x (lambda (p x) x)))
    (test (posn 1 2) place-channel-get in))

  ;; MAke sure large values are handled correctly
  (let ([v (for/list ([i 10000])
             (impersonate-vector (vector i
                                         (impersonate-vector (vector (- i))
                                                             (lambda (v i e) (sub1 e))
                                                             (lambda (v i e) e)))
                                 (lambda (v i e) (list e))
                                 (lambda (v i e) e)))])
    (test #t 'allowed? (place-message-allowed? v))
    (place-channel-put out v)
    (test #t 'equal? (equal? v (place-channel-get in))))

  (void))

;; ----------------------------------------

(let ()
  (define-values (in out) (place-channel))

  (define (try v)
    (place-channel-put in v)
    (test #t eq? v (place-channel-get out)))

  (try (shared-bytes 0))
  (try (make-shared-bytes 10))
  (try (make-shared-bytes 10 3)))

;; ----------------------------------------

(require (submod "place-utils.rkt" place-test-submod))
(test 0 p 0)

;; ----------------------------------------

(let ()
  (define fn (make-temporary-file "place~a.rkt"))
  (call-with-output-file fn #:exists 'truncate
                         (lambda (out)
                           (displayln
                            (string-append "#lang racket/base\n"
                                           (format "~s"
                                                   '(begin
                                                      (require racket/place)
                                                      (provide main)
                                                      (define (main pch #:x [x #f])
                                                        (place-channel-put pch 'done)))))
                            out)))
  (test 'done place-channel-get (dynamic-place fn 'main))
  (delete-file fn))

;; ----------------------------------------

(report-errs)
