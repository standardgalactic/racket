#lang racket

(require racket/generic rackunit)

(define-namespace-anchor generic-env)

(define-syntax-rule (check-good-syntax exp ...)
  (begin
    (check-not-exn
     (lambda () (eval '(module foo racket/base
                         (require racket/generic)
                         exp)
                      (namespace-anchor->namespace generic-env))))
    ...))

(define-syntax-rule (check-bad-syntax exp ...)
  (begin
    (check-exn
     exn:fail:syntax?
     (lambda () (eval '(module foo racket/base
                         (require racket/generic)
                         exp)
                      (namespace-anchor->namespace generic-env))))
    ...))

(check-good-syntax

 (define-generics stream
   (stream-first stream)
   (stream-rest stream)
   (stream-empty? stream))

 (define-generics stream
   #:defined-table stream-table
   (stream-first stream)
   (stream-rest stream)
   (stream-empty? stream)
   #:defaults
   ([list?
     (define stream-first car)
     (define stream-rest cdr)
     (define stream-empty? null?)]))

 (define-generics stream
   #:defined-table stream-table
   #:defaults
   ([list?
     (define stream-first car)
     (define stream-rest cdr)
     (define stream-empty? null?)])
   (stream-first stream)
   (stream-rest stream)
   (stream-empty? stream))

 (define-generics stream
   (stream-first stream)
   (stream-rest stream)
   (stream-empty? stream)
   #:defined-table stream-table
   #:defaults
   ([list?
     (define stream-first car)
     (define stream-rest cdr)
     (define stream-empty? null?)]))

 (define-generics stream
   (stream-first stream)
   (stream-rest stream)
   (stream-empty? stream)
   #:defaults
   ([list?
     (define stream-first car)
     (define stream-rest cdr)
     (define stream-empty? null?)])
   #:defined-table stream-table)

 (define-generics stream
   (stream-first stream)
   (stream-rest stream)
   (stream-empty? stream)
   #:defaults
   ([box?
     (define/generic first stream-first)
     (define/generic rest stream-rest)
     (define/generic empty? stream-empty?)
     (define stream-first (compose first unbox))
     (define stream-rest (compose rest unbox))
     (define stream-empty? (compose empty? unbox))])))

(check-bad-syntax

 (define-generics stream
   (stream-first stream)
   (stream-rest stream)
   #:defaults
   ([list?
     (define stream-first car)
     (define stream-rest cdr)
     (define stream-empty? null?)])
   (stream-empty? stream))

 (define-generics stream
   (stream-first stream)
   (stream-rest stream)
   #:defined-table stream-table
   (stream-empty? stream))

 (define-generics stream
   (stream-first stream)
   (stream-rest stream)
   (stream-empty? stream)
   #:defaults
   foo)

 (define-generics stream
   (stream-first stream)
   (stream-rest stream)
   (stream-empty? stream)
   #:defaults
   ([list?
     (define stream-first car)
     (define stream-rest cdr)
     (define stream-rest 5)
     (define stream-empty? null?)]))

 (define-generics stream
   (stream-first stream)
   (stream-rest stream)
   (stream-empty? stream)
   #:defaults
   ([])))

(check-good-syntax
  (define-generics foo (bar foo))
  (define-generics foo (bar x foo))
  (define-generics foo (bar foo x))
  (define-generics foo (bar foo [x]))
  (define-generics foo (bar foo x y))
  (define-generics foo (bar foo x [y]))
  (define-generics foo (bar foo [x] [y]))
  (define-generics foo (bar foo x #:k z y))
  (define-generics foo (bar foo x #:k z [y]))
  (define-generics foo (bar foo [x] #:k z [y]))
  (define-generics foo (bar foo x #:k [z] y))
  (define-generics foo (bar foo x #:k [z] [y]))
  (define-generics foo (bar foo [x] #:k [z] [y]))
  (define-generics foo (bar foo [x] #:k z [y] #:j w))
  (define-generics foo (bar foo [x] #:k z [y] #:j [w]))
  (define-generics foo (bar foo [x] #:k [z] [y] #:j w))
  (define-generics foo (bar foo [x] #:k [z] [y] #:j [w])))

(check-bad-syntax
  (define-generics foo (bar))
  (define-generics foo (bar x))
  (define-generics foo (bar [foo]))
  (define-generics foo (bar [x] foo))
  (define-generics foo (bar foo [x] y))

  (define-generics stream
    (stream-first stream)
    (stream-rest stream)
    (stream-empty? stream)
    #:defaults
    ([list?
      (define/generic super not-a-stream-method)
      (define stream-first  first)
      (define stream-rest   rest)
      (define stream-empty? empty?)])))

(check-good-syntax
 (begin
  (module gen racket
    (require racket/generic)
    (provide gen:foo (rename-out [*bar bar]))
    (define-generics foo (bar foo))
    (define *bar bar))
  (module impl racket
    (require racket/generic (submod ".." gen))
    (struct thing []
      #:methods gen:foo
      [(define/generic gbar bar)]))))

(check-bad-syntax
 (begin
   (module gen racket
     (require racket/generic)
     (provide gen:foo (rename-out [*bar bar]))
     (define-generics foo (*bar foo))
     (define bar *bar))
   (module impl racket
     (require racket/generic (submod ".." gen))
     (struct thing []
       #:methods gen:foo
       [(define/generic gbar bar)]))))

(check-good-syntax
 (begin
   (define-generics foo
     #:requires (bar)
     (bar foo)
     (baz foo))

   (struct thing []
     #:methods gen:foo
     [(define (bar self) 1)])

   (struct thing2 []
     #:methods gen:foo
     [(define (bar self) 1)
      (define (baz self) 2)])

   (struct thing3 []
     #:methods gen:foo
     [(define (bar self) 1)
      (define (baz self) 2)
      (define (bam self) 3)])))


(check-bad-syntax
 (begin
   (define-generics foo
     #:requires (bar)
     (bar foo)
     (baz foo))

   (struct thing []
     #:methods gen:foo
     [(define (baz self) 1)])))

(check-good-syntax
 (begin
   (define-generics foo
     #:requires ()
     (bar foo)
     (baz foo))

   (struct thing []
     #:methods gen:foo
     [(define (baz self) 1)])))

;; tests from https://github.com/racket/racket/issues/1554

(check-bad-syntax
 (struct wuznub (x)
   #:transparent
   #:methods gen:equal+hash
   [(define (equal-proc a b _) (= (wuznub-x a) (wuznub-x b)))
    (define (hash-proc a _) (wuznub-x a))
    (define (hash-proc2 a _) (wuznub-x a))]))

(check-good-syntax
 (struct wuznub (x)
   #:transparent
   #:methods gen:equal+hash
   [(define (equal-proc a b _) (= (wuznub-x a) (wuznub-x b)))
    (define (hash-proc a _) (wuznub-x a))
    (define (hash2-proc a _) (wuznub-x a))]))
