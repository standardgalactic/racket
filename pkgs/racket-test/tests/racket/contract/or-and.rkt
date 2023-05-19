#lang racket/base
(require "test-util.rkt")
(parameterize ([current-contract-namespace
                (make-basic-contract-namespace
                 'racket/contract/private/prop)])
  
  (test/pos-blame
   'or/c1
   '(contract (or/c false/c) #t 'pos 'neg))
  
  (test/spec-passed
   'or/c2
   '(contract (or/c false/c) #f 'pos 'neg))
  
  (test/spec-passed
   'or/c3
   '((contract (or/c (-> integer? integer?)) (lambda (x) x) 'pos 'neg) 1))
  
  (test/neg-blame
   'or/c4
   '((contract (or/c (-> integer? integer?)) (lambda (x) x) 'pos 'neg) #f))
  
  (test/pos-blame
   'or/c5
   '((contract (or/c (-> integer? integer?)) (lambda (x) #f) 'pos 'neg) 1))
  
  (test/spec-passed
   'or/c6
   '(contract (or/c false/c (-> integer? integer?)) #f 'pos 'neg))
  
  (test/spec-passed
   'or/c7
   '((contract (or/c false/c (-> integer? integer?)) (lambda (x) x) 'pos 'neg) 1))
  
  (test/spec-passed/result
   'or/c8
   '((contract ((or/c false/c (-> string?))  . -> . any)
               (λ (y) y)
               'pos
               'neg)
     #f)
   #f)
  
  (test/spec-passed/result
   'or/c9
   '((contract (or/c (-> string?) (-> integer? integer?))
               (λ () "x")
               'pos
               'neg))
   "x")
  
  (test/spec-passed/result
   'or/c10
   '((contract (or/c (-> string?) (-> integer? integer?))
               (λ (x) x)
               'pos
               'neg)
     1)
   1)
  
  (test/pos-blame
   'or/c11
   '(contract (or/c (-> string?) (-> integer? integer?))
              1
              'pos
              'neg))
  
  (test/pos-blame
   'or/c12
   '((contract (or/c (-> string?) (-> integer? integer?))
               1
               'pos
               'neg)
     'x))
  
  (test/pos-blame
   'or/c13
   '(contract (or/c not) #t 'pos 'neg))
  
  (test/spec-passed
   'or/c14
   '(contract (or/c not) #f 'pos 'neg))

  (test/spec-passed
   'or/c15
   '(contract (or/c 'x 'y 1 2) 'x 'pos 'neg))

  (test/spec-passed
   'or/c16
   '(contract (or/c 'x 'y 1 2) 'y 'pos 'neg))

  (test/spec-passed
   'or/c17
   '(contract (or/c 'x 'y 1 2) 1 'pos 'neg))

  (test/spec-passed
   'or/c18
   '(contract (or/c 'x 'y 1 2) 1 'pos 'neg))

  (test/spec-passed
   'or/c19
   '(contract (or/c 'x 'y 1 2) 1.0 'pos 'neg))

  (test/spec-passed
   'or/c20
   '(contract (or/c 'x 'y 1 2) 2 'pos 'neg))

  (test/spec-passed
   'or/c21
   '(contract (or/c 'x 'y 1 2) 2.0 'pos 'neg))

  (test/pos-blame
   'or/c22
   '(contract (or/c 'x 'y 1 2) 'z 'pos 'neg))

  (test/pos-blame
   'or/c23
   '(contract (or/c 'x 'y 1 2) 3 'pos 'neg))

  (test/spec-passed
   'or/c24
   '(contract (or/c any/c #f) 3 'pos 'neg))

  (test/spec-passed/result
   'or/c25
   '(prop:any/c? (or/c any/c #f))
   #t)
  
  (test/spec-passed/result
   'or/c-not-error-early
   '(begin (or/c (-> integer? integer?) (-> boolean? boolean?))
           1)
   1)
  
  (contract-error-test
   'contract-error-test4
   #'(contract (or/c (-> integer? integer?) (-> boolean? boolean?))
               (λ (x) x)
               'pos
               'neg)
   exn:fail?)

  (test/spec-passed/result
   'or/c-ordering
   '(let ([x '()])
      (contract (or/c (lambda (y) (set! x (cons 2 x)) #f) (lambda (y) (set! x (cons 1 x)) #t))
                'anything
                'pos
                'neg)
      x)
   '(1 2)
   do-not-double-wrap)

  (test/spec-passed/result
   'or/c-ordering-double-wrap
   '(let ([x '()])
      (contract (or/c (lambda (y) (set! x (cons 2 x)) #f) (lambda (y) (set! x (cons 1 x)) #t))
                (contract
                 (or/c (lambda (y) (set! x (cons 2 x)) #f) (lambda (y) (set! x (cons 1 x)) #t))
                 'anything
                 'pos 'neg)
                'pos
                'neg)
      x)
   '(1 2 1 2)
   do-not-double-wrap)
  
  (test/spec-passed/result
   'or/c-ordering2
   '(let ([x '()])
      (contract (or/c (lambda (y) (set! x (cons 2 x)) #t) (lambda (y) (set! x (cons 1 x)) #t))
                'anything
                'pos
                'neg)
      x)
   '(2)
   do-not-double-wrap)

  (test/spec-passed/result
   'or/c-ordering2-double-wrap
   '(let ([x '()])
      (contract (or/c (lambda (y) (set! x (cons 2 x)) #t) (lambda (y) (set! x (cons 1 x)) #t))
                (contract
                 (or/c (lambda (y) (set! x (cons 2 x)) #t) (lambda (y) (set! x (cons 1 x)) #t))
                 'anything
                 'pos 'neg)
                'pos
                'neg)
      x)
   '(2 2)
   do-not-double-wrap)
  
  (test/spec-passed
   'or/c-hmm
   '(let ([funny/c (or/c (and/c procedure? (-> any)) (listof (-> number?)))])
      (contract (-> funny/c any) void 'pos 'neg)))
  
  
  (test/spec-passed
   'or/c-opt-unknown-flat
   '(let ()
      (define arr (-> number? number?))
      ((contract (opt/c (or/c not arr)) (λ (x) x) 'pos 'neg) 1)))
  
  
  
  
  
  
  ;
  ;
  ;
  ;                          ;;;;  ;;
  ;                          ;;;;  ;;
  ;  ;;;;;;;  ;;;; ;;;    ;;;;;;;  ;;  ;;;;;
  ;  ;;;;;;;; ;;;;;;;;;  ;;;;;;;;  ;; ;;;;;;
  ;      ;;;; ;;;; ;;;; ;;;;;;;;;  ;;;;;;;;;
  ;   ;;;;;;; ;;;; ;;;; ;;;; ;;;; ;; ;;;;
  ;  ;;  ;;;; ;;;; ;;;; ;;;;;;;;; ;; ;;;;;;;
  ;  ;;;;;;;; ;;;; ;;;;  ;;;;;;;; ;;  ;;;;;;
  ;   ;; ;;;; ;;;; ;;;;   ;;;;;;; ;;   ;;;;;
  ;                               ;;
  ;
  ;
  
  (test/spec-passed
   'and/c1
   '((contract (and/c (-> (<=/c 100) (<=/c 100))
                      (-> (>=/c -100) (>=/c -100)))
               (λ (x) x)
               'pos
               'neg)
     1))
  
  (test/neg-blame
   'and/c2
   '((contract (and/c (-> (<=/c 100) (<=/c 100))
                      (-> (>=/c -100) (>=/c -100)))
               (λ (x) x)
               'pos
               'neg)
     200))
  
  (test/pos-blame
   'and/c3
   '((contract (and/c (-> (<=/c 100) (<=/c 100))
                      (-> (>=/c -100) (>=/c -100)))
               (λ (x) 200)
               'pos
               'neg)
     1))
  
  
  
  
  (test/spec-passed/result
   'and/c-ordering
   '(let ([x '()])
      (contract (and/c (lambda (y) (set! x (cons 2 x)) #t) (lambda (y) (set! x (cons 1 x)) #t))
                'anything
                'pos
                'neg)
      x)
   '(1 2)
   do-not-double-wrap)

  (test/spec-passed/result
   'and/c-ordering-double-wrap
   '(let ([x '()])
      (contract (and/c (lambda (y) (set! x (cons 2 x)) #t) (lambda (y) (set! x (cons 1 x)) #t))
                (contract
                 (and/c (lambda (y) (set! x (cons 2 x)) #t) (lambda (y) (set! x (cons 1 x)) #t))
                 'anything
                 'pos 'neg)
                'pos
                'neg)
      x)
   '(1 2 1 2)
   do-not-double-wrap)
  
  (test/spec-passed/result
   'ho-and/c-ordering
   '(let ([x '()])
      ((contract (and/c (-> (lambda (y) (set! x (cons 1 x)) #t)
                            (lambda (y) (set! x (cons 2 x)) #t))
                        (-> (lambda (y) (set! x (cons 3 x)) #t)
                            (lambda (y) (set! x (cons 4 x)) #t)))
                 (λ (x) x)
                 'pos
                 'neg)
       1)
      (reverse x))
   '(3 1 2 4)
   do-not-double-wrap)

  (test/spec-passed/result
   'ho-and/c-ordering-double-wrap
   '(let ([x '()])
      ((contract (and/c (-> (lambda (y) (set! x (cons 1 x)) #t)
                            (lambda (y) (set! x (cons 2 x)) #t))
                        (-> (lambda (y) (set! x (cons 3 x)) #t)
                            (lambda (y) (set! x (cons 4 x)) #t)))
                 (contract
                  (and/c (-> (lambda (y) (set! x (cons 1 x)) #t)
                             (lambda (y) (set! x (cons 2 x)) #t))
                         (-> (lambda (y) (set! x (cons 3 x)) #t)
                             (lambda (y) (set! x (cons 4 x)) #t)))
                  (λ (x) x)
                  'pos 'neg)
                 'pos
                 'neg)
       1)
      (reverse x))
      '(3 1 3 1 2 4 2 4)
      do-not-double-wrap)
  
  (test/spec-passed/result
   'and/c-isnt
   '(and (regexp-match #rx"promised: even?"
                       (with-handlers ((exn:fail? exn-message))
                         (contract (and/c integer? even? positive?)
                                   -3
                                   'pos
                                   'neg)
                         "not the error!"))
         #t)
   #t)

  (test/spec-passed/result
   'and/c-real-chaperone.1
   '(let ()
      (define n "original")
      (contract (and/c (chaperone-procedure real? (λ (x) (set! n "updated") x))
                       negative?)
                -1 'pos 'neg)
      n)
   "updated")

  (test/spec-passed/result
   'and/c-real-chaperone.2
   '(let ()
      (define n "original")
      (contract (and/c (chaperone-procedure exact-nonnegative-integer? (λ (x) (set! n "updated") x))
                       (between/c 2 10))
                5 'pos 'neg)
      n)
   "updated")
  
  (test/spec-passed
   'contract-flat1
   '(contract not #f 'pos 'neg))
  
  (test/pos-blame
   'contract-flat2
   '(contract not #t 'pos 'neg))
  
  
  (test/neg-blame
   'ho-or/c-val-first1
   '((contract (-> (or/c (-> number?)
                         (-> number? number?))
                   number?)
               (λ (x) 1)
               'pos 'neg)
     (lambda (x y z) 1)))
  
  (test/neg-blame
   'ho-or/c-val-first2
   '((contract (-> (or/c (-> number? number?)
                         (-> number? number?))
                   number?)
               (λ (x) 1)
               'pos 'neg)
     (lambda (x) 1)))

  (test/pos-blame
   'first-or/c1
   '(contract (first-or/c false/c) #t 'pos 'neg))
  
  (test/spec-passed
   'first-or/c2
   '(contract (first-or/c false/c) #f 'pos 'neg))
  
  (test/spec-passed
   'first-or/c3
   '((contract (first-or/c (-> integer? integer?)) (lambda (x) x) 'pos 'neg) 1))
  
  (test/neg-blame
   'first-or/c4
   '((contract (first-or/c (-> integer? integer?)) (lambda (x) x) 'pos 'neg) #f))
  
  (test/pos-blame
   'first-or/c5
   '((contract (first-or/c (-> integer? integer?)) (lambda (x) #f) 'pos 'neg) 1))
  
  (test/spec-passed
   'first-or/c6
   '(contract (first-or/c false/c (-> integer? integer?)) #f 'pos 'neg))
  
  (test/spec-passed
   'first-or/c7
   '((contract (first-or/c false/c (-> integer? integer?)) (lambda (x) x) 'pos 'neg) 1))
  
  (test/spec-passed/result
   'first-or/c8
   '((contract ((first-or/c false/c (-> string?))  . -> . any)
               (λ (y) y)
               'pos
               'neg)
     #f)
   #f)
  
  (test/spec-passed/result
   'first-or/c9
   '((contract (first-or/c (-> string?) (-> integer? integer?))
               (λ () "x")
               'pos
               'neg))
   "x")
  
  (test/spec-passed/result
   'first-or/c10
   '((contract (first-or/c (-> string?) (-> integer? integer?))
               (λ (x) x)
               'pos
               'neg)
     1)
   1)
  
  (test/pos-blame
   'first-or/c11
   '(contract (first-or/c (-> string?) (-> integer? integer?))
              1
              'pos
              'neg))
  
  (test/pos-blame
   'first-or/c12
   '((contract (first-or/c (-> string?) (-> integer? integer?))
               1
               'pos
               'neg)
     'x))
  
  (test/pos-blame
   'first-or/c13
   '(contract (first-or/c not) #t 'pos 'neg))
  
  (test/spec-passed
   'first-or/c14
   '(contract (first-or/c not) #f 'pos 'neg))
  
  (test/spec-passed/result
   'first-or/c-not-error-early
   '(begin (first-or/c (-> integer? integer?) (-> boolean? boolean?))
           1)
   1)
  
  (test/spec-passed/result
   'contract-not-an-error-test4-ior
   '((contract (first-or/c (-> integer? integer?) (-> boolean? boolean?))
               (λ (x) x)
               'pos
               'neg) 1)
   1)
  
  (test/spec-passed/result
   'first-or/c-ordering
   '(let ([x '()])
      (contract (first-or/c (lambda (y) (set! x (cons 2 x)) #f) (lambda (y) (set! x (cons 1 x)) #t))
                'anything
                'pos
                'neg)
      x)
   '(1 2)
   do-not-double-wrap)

  (test/spec-passed/result
   'first-or/c-ordering-double-wrap
   '(let ([x '()])
      (contract (first-or/c (lambda (y) (set! x (cons 2 x)) #f) (lambda (y) (set! x (cons 1 x)) #t))
                (contract
                 (first-or/c (lambda (y) (set! x (cons 2 x)) #f) (lambda (y) (set! x (cons 1 x)) #t))
                 'anything
                 'pos
                 'neg)
                'pos
                'neg)
      x)
   '(1 2 1 2)
   do-not-double-wrap)
  
  (test/spec-passed/result
   'first-or/c-ordering2
   '(let ([x '()])
      (contract (first-or/c (lambda (y) (set! x (cons 2 x)) #t) (lambda (y) (set! x (cons 1 x)) #t))
                'anything
                'pos
                'neg)
      x)
   '(2)
   do-not-double-wrap)

  (test/spec-passed/result
   'first-or/c-ordering2-double-wrap
   '(let ([x '()])
      (contract (first-or/c (lambda (y) (set! x (cons 2 x)) #t) (lambda (y) (set! x (cons 1 x)) #t))
                (contract
                 (first-or/c (lambda (y) (set! x (cons 2 x)) #t) (lambda (y) (set! x (cons 1 x)) #t))
                 'anything
                 'pos 'neg)
                'pos
                'neg)
      x)
   '(2 2)
   do-not-double-wrap)
  
  (test/spec-passed
   'first-or/c-hmm
   '(let ([funny/c (first-or/c (and/c procedure? (-> any)) (listof (-> number?)))])
      (contract (-> funny/c any) void 'pos 'neg)))
  
  
  (test/spec-passed
   'first-or/c-opt-unknown-flat
   '(let ()
      (define arr (-> number? number?))
      ((contract (opt/c (first-or/c not arr)) (λ (x) x) 'pos 'neg) 1)))
  
 
  (test/neg-blame
   'ho-first-or/c-val-first1
   '((contract (-> (first-or/c (-> number?)
                         (-> number? number?))
                   number?)
               (λ (x) 1)
               'pos 'neg)
     (lambda (x y z) 1)))
  
  (test/spec-passed/result
   'ho-first-or/c-val-first2
   '((contract (-> (first-or/c (-> number? number?)
                          (-> number? number?))
                   number?)
               (λ (x) (x 1))
               'pos 'neg)
     (lambda (x) (+ x 1)))
   2))
