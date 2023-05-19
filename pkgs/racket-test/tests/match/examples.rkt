#lang scheme/base

(require racket/match
         (prefix-in s: racket/set)
         scheme/mpair
         scheme/control scheme/foreign
         (only-in racket/list split-at)
         (for-syntax scheme/base)
         (prefix-in m: mzlib/match)
         (prefix-in r: racket/base)
         rackunit)

(define-syntax (comp stx)
  (syntax-case stx ()
    [(mytest tst exp)
     #`(test-case (format "test: ~a" (syntax->datum (quote-syntax tst)))
                       #,(syntax/loc stx (check-equal? tst exp)))]))

(define-struct X (a b c))
(define-match-expander X:
  (lambda (stx)
    (syntax-case stx ()
      [(_ . args) #'(struct X args)])))

(define (f x y)
  (match*
   (x y)
   [((box a) (box b)) (+ a b)]
   [((vector x y z) (vector _)) (* x y z)]
   [((list a b c) (list d)) (+ a b c d)]
   [((cons a b) (cons c _))  (+ a b c)]))


(define (g x)
  (match x
    [1 'one]
    [(and x (? number?)) (list x 'num)]
    [(? boolean?) 'bool]
    [_ 'neither]))


(define (split l)
  (match l
    [(list (list a b) ...) (list a b)]
    [_ 'wrong]))

(define (split2 l)
  (match l
    [(list (list a b) ..2 rest) (list a b rest)]
    [_ 'wrong]))


(define-struct empt ())


(provide new-tests)

(define new-tests
  (test-suite
   "new tests for match"

   (comp
    1
    (match (list 1 2 3)
      [(list x ...) (=> unmatch)
                    (if (= (car x) 1)
                        (begin (+ 100 (unmatch))
                               (error 'bad))
                        0)]
      [_ 1]))

   (comp
    '(1 2 3)
    (match (vector 1 2 3)
      [(vector (? number? x) ...) x]
      [_ 2]))

   (comp
    2
    (match (vector 'a 1 2 3)
      [(vector (? number? x) ...) x]
      [_ 2]))

   (comp
    3
    (match (list 'a 1 2 3)
      [(vector (? number? x) ...) x]
      [_ 3]))


   (comp -1
         (match (vector 1 2 3)
           [(or (list x) x) -1]
           [(list a b c) 0]
           [(vector a) 1]
           [(vector a b) 2]
           [(vector a b c) 3]
           [(box _) 4]))

   (comp 12
         (match (list 12 12)
           [(list x x) x]
           [_ 13]))
   (comp 13
         (match (list 1 0)
           [(list x x) x]
           [_ 13]))


   (comp
    6
    (let ()
      (match (make-X 1 2 3)
        [(struct X (a b c)) (+ a b c)]
        [(box a) a]
        [(cons x y) (+ x y)]
        [_ 0])))

   (comp
    6
    (let ()
      (match (make-X 1 2 3)
        [(X a b c) (+ a b c)]
        [(box a) a]
        [(cons x y) (+ x y)]
        [_ 0])))


   (comp
    6
    (match (make-X 1 2 3)
      [(X: a b c) (+ a b c)]))



   (comp
    '(6 3 100 6)
    (list
     (f (cons 1 2) (cons 3 4))
     (f (box 1) (box 2))
     (f (list 10 20 30) (list 40))
     (f (vector 1 2 3) (vector 4))))

   (comp '(one (2 num) bool neither)
         (list
          (g 1)
          (g 2)
          (g #f)
          (g "foo")))

   (comp
    (split (list (list 1 2) (list 'a 'b) (list 'x 'y)))
    '((1 a x) (2 b y)))
   (comp
    (split2 (list (list 1 2) (list 'a 'b) (list 'x 'y)))
    '((1 a) (2 b) (x y)))

   (comp
    'yes
    (match (list (box 2) 2)
      [(list (or (box x) (list x)) x) 'yes]
      [_ 'no]))

   (comp
    'no
    (parameterize ([match-equality-test eq?])
      (match (list (cons 1 1) (cons 1 1))
        [(list x x) 'yes]
        [_ 'no])))

   (comp
    'no
    (match (list (box 2) 3)
      [(list (or (box x) (list x)) x) 'yes]
      [_ 'no]))

   (comp
    2
    (match (list 'one 'three)
      [(list 'one 'two) 1]
      [(list 'one 'three) 2]
      [(list 'two 'three) 3]))
   (comp
    2
    (match (list 'one 'three)
      [(cons 'one (cons 'two '())) 1]
      [(cons 'one (cons 'three '())) 2]
      [(cons 'two (cons 'three '())) 3]))

   (comp 'yes
         (match '(1 x 2 y 3 z)
           [(list-no-order 1 2 3 'x 'y 'z) 'yes]
           [_ 'no]))

   ;; NOT WORKING YET
   (comp '(x y z)
         (match '(1 x 2 y 3 z)
           [(list-no-order 1 2 3 r1 r2 r3) (list r1 r2 r3)]
           [_ 'no]))

   (comp '(x y z)
         (match '(1 x 2 y 3 z)
           [(list-no-order 1 2 3 rest ...) rest]
           [_ 'no]))

   (comp '(x y z)
         (match '(1 x 2 y 3 z)
           [(list-no-order 1 2 3 rest ..1) rest]
           [_ 'no]))

   (comp '(x y z)
         (match '(1 x 2 y 3 z)
           [(list-no-order 1 2 3 rest ..2) rest]
           [_ 'no]))

   (comp '(x y z)
         (match '(1 x 2 y 3 z)
           [(list-no-order 1 2 3 rest ..3) rest]
           [_ 'no]))

   (comp 'no
         (match '(1 x 2 y 3 z)
           [(list-no-order 1 2 3 rest ..4) rest]
           [_ 'no]))

   (comp
    'yes
    (match '(a (c d))
      [(list-no-order 'a
                      (? pair?
                         (list-no-order 'c 'd)))
       'yes]
      [_ 'no]))


   (comp
    '((1 2) (a b 1 2))
    (let ()
      (define-syntax-rule (match-lambda . cl)
        (lambda (e) (match e . cl)))

      (define (make-nil)
        '())
      (define nil? null?)

      (define make-::
        (match-lambda
          ((list-no-order (list '|1| a) (list '|2| d))
           (cons a d))))
      (define ::? pair?)
      (define (::-content p)
        (list (list '|1| (car p))
              (list '|2| (cdr p))))

      (define my-append
        (match-lambda
          ((list-no-order (list '|1| (? nil?))
                          (list '|2| l))
           l)
          ((list-no-order (list '|1| (? ::?
                                        (app ::-content (list-no-order (list
                                                                        '|1| h) (list '|2| t)))))
                          (list '|2| l))
           (make-:: (list (list '|1| h)
                          (list '|2| (my-append (list (list '|1| t) (list '|2|
                                                                          l)))))))))
      (list
       (my-append (list (list '|1| '())
                        (list '|2| '(1 2))))

       (my-append (list (list '|1| '(a b))
                        (list '|2| '(1 2)))))))


   (comp
    'yes
    (match
        (make-immutable-hasheq '((|1| . (a b))))
      [(hash-table ('|1| (app (lambda (p)
                                (make-immutable-hasheq
                                 (list (cons '|1| (car p))
                                       (cons '|2| (cdr p)))))
                              (hash-table ('|1| _) ('|2| _))))) 'yes]
      [_ 'no]))

   ;; examples from docs

   (comp 'yes
         (match '(1 2 3)
           [(list (not 4) ...) 'yes]
           [_ 'no]))

   (comp 'no
         (match '(1 4 3)
           [(list (not 4) ...) 'yes]
           [_ 'no]))

   (comp 1
         (match '(1 2)
           [(or (list a 1) (list a 2)) a]
           [_ 'bad]))

   (comp 'yes
         (match '(1 2)
           [(app (lambda (v) (split-at v 1)) '(1) '(2)) 'yes]
           [_ 'bad]))

   (comp '(2 3)
         (match '(1 (2 3) 4)
           [(list _ (and a (list _ ...)) _) a]
           [_ 'bad]))



   (comp
    'yes
    (match "apple"
      [(regexp #rx"p+(.)" (list _ "l")) 'yes]
      [_ 'no]))
   (comp
    'no
    (match "append"
      [(regexp #rx"p+(.)" (list _ "l")) 'yes]
      [_ 'no]))


   (comp
    'yes
    (match "apple"
      [(regexp #rx"p+" ) 'yes]
      [_ 'no]))
   (comp
    'no
    (match "banana"
      [(regexp #rx"p+") 'yes]
      [_ 'no]))

   (comp
    '(0 1)
    (let ()
      (define-struct tree (val left right))

      (match (make-tree 0 (make-tree 1 #f #f) #f)
        [(struct tree (a (struct tree (b  _ _)) _)) (list a b)]
        [_ 'no])))

   (comp
    'ok
    (let ()
      (define impersonated? #f)
      (define-struct st ([x #:mutable])
        #:transparent)
      (define a (st 1))
      (define b (impersonate-struct a st-x (lambda (_self x)
                                             (set! impersonated? #t)
                                             x)))
      (match b
        [(st _) (if impersonated? 'fail 'ok)])))

   (comp
    'ok
    (let ()
      (define impersonated? #f)
      (define-struct st ([x #:mutable])
        #:transparent)
      (define a (st 1))
      (define b (impersonate-struct a st-x (lambda (_self x)
                                             (set! impersonated? #t)
                                             x)))
      (match b
        [(st x) (if impersonated? 'ok 'fail)])))

   (comp
    'ok
    (let ()
      (define impersonated? #f)
      (define v (vector 1 2 3))
      (define b (impersonate-vector v
                                    (lambda (self idx _)
                                      (set! impersonated? #t)
                                      (vector-ref self idx))
                                    vector-set!))
      (match b
        [(vector _ _ _) (if impersonated? 'fail 'ok)])))

   (comp
    'ok
    (let ()
      (define touched-indices (s:mutable-set))
      (define v (vector 1 2 3))
      (define b (impersonate-vector v
                                    (λ (_ idx v)
                                      (s:set-add! touched-indices idx)
                                      v)
                                    vector-set!))
      (match b
        [(vector a _ _) (if (equal? (s:mutable-set 0) touched-indices) 'ok 'fail)])))

   (comp
    'ok
    (let ()
      (define touched-indices (s:mutable-set))
      (define vec (impersonate-vector (vector 12 14 16 18 20 22 24 26)
                                      (λ (_ idx v)
                                        (s:set-add! touched-indices idx)
                                        v)
                                      vector-set!))
      (match vec
        [(vector _ ...) (if (equal? (s:mutable-set) touched-indices) 'ok 'fail)])))

   (comp
    'ok
    (let ()
      (define touched-indices (s:mutable-set))
      (define vec (impersonate-vector (vector 12 14 16 18 20 22 24 26)
                                      (λ (_ idx v)
                                        (s:set-add! touched-indices idx)
                                        v)
                                      vector-set!))
      (match vec
        [(vector xs ...)
         (if (equal? (s:mutable-set 0 1 2 3 4 5 6 7) touched-indices) 'ok 'fail)])))

   (comp
    'ok
    (let ()
      (define touched-indices (s:mutable-set))
      (define vec (impersonate-vector (vector 12 14 16 18 20 22 24 26)
                                      (λ (_ idx v)
                                        (s:set-add! touched-indices idx)
                                        v)
                                      vector-set!))
      ;; further optimization could potentionally elide the access of 1 and 6
      (match vec
        [(vector a _ b _ ... c _ e)
         (if (equal? (s:mutable-set 0 1 2 5 6 7) touched-indices) 'ok 'fail)])))

   (comp
    'ok
    (let ()
      (define touched-indices (s:mutable-set))
      (define vec (impersonate-vector (vector 12 14 16 18 20 22 24 26)
                                      (λ (_ idx v)
                                        (s:set-add! touched-indices idx)
                                        v)
                                      vector-set!))
      (match vec
        [(vector a _ ... b _ ... c)
         (if (equal? (s:mutable-set 0 1 2 3 4 5 6 7) touched-indices) 'ok 'fail)])))

   (comp
    'ok
    (let ()
      (define touched-indices (s:mutable-set))
      (define vec (impersonate-vector (vector 12 14 16 18 20 22 24 26)
                                      (λ (_ idx v)
                                        (s:set-add! touched-indices idx)
                                        v)
                                      vector-set!))
      (match vec
        [(vector a _ ..8) 'fail]
        [_ (if (equal? (s:mutable-set) touched-indices) 'ok 'fail)])))

   (comp
    'ok
    (let ()
      (define touched-indices (s:mutable-set))
      (define vec (impersonate-vector (vector 12 14 16 18 20 22 24 26)
                                      (λ (_ idx v)
                                        (s:set-add! touched-indices idx)
                                        v)
                                      vector-set!))
      (match vec
        [(vector a _ ..7) (if (equal? (s:mutable-set 0) touched-indices) 'ok 'fail)])))

   (comp
    '(12 14 24 26)
    (let ()
      (define vec (vector 12 14 16 18 20 22 24 26))
      (match vec
        [(vector a b _ ... c d) (list a b c d)])))

   (comp
    '(12 14)
    (let ()
      (define vec (vector 12 14 16 18 20 22 24 26))
      (match vec
        [(vector a b _ ...) (list a b)])))

   (comp
    '(24 26)
    (let ()
      (define vec (vector 12 14 16 18 20 22 24 26))
      (match vec
        [(vector _ ... c d) (list c d)])))

   (comp 1
         (match #&1
           [(box a) a]
           [_ 'no]))
   (comp '(2 1)
         (match #hasheq(("a" . 1) ("b" . 2))
           [(hash-table ("b" b) ("a" a)) (list b a)]
           [_ 'no]))

   (comp #t
         (andmap string?
                 (match #hasheq(("b" . 2) ("a" . 1))
                   [(hash-table (key val) ...) key]
                   [_ 'no])))

   (comp "non-empty"
         (match #hash((1 . 2))
           [(hash-table) "empty"]
           [_ "non-empty"]))
   (comp "empty"
         (match #hash()
           [(hash-table) "empty"]
           [_ "non-empty"]))

   (comp
    (match #(1 (2) (2) (2) 5)
      [(vector 1 (list a) ..3 5) a]
      [_ 'no])
    '(2 2 2))

   (comp '(1 3 4 5)
         (match '(1 2 3 4 5 6)
           [(list-no-order 6 2 y ...) y]
           [_ 'no]))

   (comp 1
         (match '(1 2 3)
           [(list-no-order 3 2 x) x]))
   (comp '((1 2 3) 4)
         (match '(1 2 3 . 4)
           [(list-rest a ... d) (list a d)]))

   (comp 4
         (match '(1 2 3 . 4)
           [(list-rest a b c d) d]))

   ;; different behavior from the way match used to be
   (comp '(2 3 4)
         (match '(1 2 3 4 5)
           [(list 1 a ..3 5) a]
           [_ 'else]))

   (comp '((1 2 3 4) ())
         (match (list 1 2 3 4 5)
           [(list x ... y ... 5) (list x y)]
           [_ 'no]))

   (comp '((1 3 2) (4))
         (match (list 1 3 2 3 4 5)
           [(list x ... 3 y ... 5) (list x y)]
           [_ 'no]))

   (comp '(3 2 1)
         (match '(1 2 3)
           [(list a b c) (list c b a)]))

   (comp '(2 3)
         (match '(1 2 3)
           [(list 1 a ...) a]))

   (comp 'else
         (match '(1 2 3)
           [(list 1 a ..3) a]
           [_ 'else]))

   (comp '(2 3 4)
         (match '(1 2 3 4)
           [(list 1 a ..3) a]
           [_ 'else]))

   (comp
    '(2 2 2)
    (match '(1 (2) (2) (2) 5)
      [(list 1 (list a) ..3 5) a]
      [_ 'else]))

   (comp
    #t
    (match "yes"
      ["yes" #t]
      ["no" #f]))

   (comp 3
         (match '(1 2 3)
           [(list _ _ a) a]))
   (comp '(3 2 1)
         (match '(1 2 3)
           [(list a b a) (list a b)]
           [(list a b c) (list c b a)]))

   (comp '(2 '(x y z) 1)
         (match '(1 '(x y z) 2)
           [(list a b a) (list a b)]
           [(list a b c) (list c b a)]))

   (comp '(1 '(x y z))
         (match '(1 '(x y z) 1)
           [(list a b a) (list a b)]
           [(list a b c) (list c b a)]))

   (comp '(2 3)
         (match '(1 2 3)
           [`(1 ,a ,(? odd? b)) (list a b)]))

   (comp '(2 1 (1 2 3 4))
         (match-let ([(list a b) '(1 2)]
                     [(vector x ...) #(1 2 3 4)])
           (list b a x)))



   (comp '(1 2 3 4)
         (match-let* ([(list a b) '(#(1 2 3 4) 2)]
                      [(vector x ...) a])
           x))

   (comp 2
         (let ()
           (match-define (list a b) '(1 2))
           b))

   (comp 'yes
         (match '(number_1 . number_2)
           [`(variable-except ,@(list vars ...))
            'no]
           [(? list?)
            'no]
           [_ 'yes]))

   (comp "yes"
         (match
             '((555))
           ((list-no-order (and (list 555)
                                (list-no-order 555)))
            "yes")
           (_ "no"))) ;; prints "no"

   (comp "yes"
         (match
             '((555))
           ((list-no-order (and (list-no-order 555)
                                (list 555)))
            "yes")
           (_ "no"))) ;; prints "yes"

   (comp "yes"
         (match
             '((555))
           ((list (and (list 555)
                       (list-no-order 555)))
            "yes")
           (_ "no"))) ;; prints "yes"

   (comp  '("a") (match "a"  ((regexp #rx"a" x) x)))
   (comp  '(#"a")
          (match #"a"
            ((regexp #rx"a" x) x)
            [_ 'no]))

   (comp 'yes (match #"a" (#"a" 'yes)))

   (comp 'yes (with-handlers ([exn:fail:syntax? (lambda _ 'yes)]) (expand #'(match-lambda ((a ?) #f))) 'no))
   (comp 'yes (with-handlers ([exn:fail:syntax? (lambda _ 'yes)]) (expand #'(match-lambda ((?) #f))) 'no))
   (comp 'yes (with-handlers ([exn:fail:syntax? (lambda _ 'yes)]
                              [exn:fail? (lambda _ 'no)])
                (expand #'(match 1 [1 (=> (fail)) 1]))
                'no))

   (comp
    'yes
    (let ()

      (m:define-match-expander exp1
                               #:plt-match
                               (lambda (stx)
                                 (syntax-case stx ()
                                   ((_match (x y))
                                    #'(list (list x y))))))

      (m:define-match-expander exp2
                               #:plt-match
                               (lambda (stx)
                                 (syntax-case stx ()
                                   ((_match x y)
                                    #'(exp1 (x y))))))

      (define (test tp)
        (match tp ((exp2 x y) x)))
      'yes))
   (comp '(a b c)
         (match '(a b c)
           [(list-rest foo) foo]))
   (comp 2
         (let ()
           (define (foo x) (match x [1 (+ x x)]))
           (foo 1)))


   (comp 'yes
         (match (make-empt)
           [(struct empt ()) 'yes]
           [_ 'no]))

   (comp 'yes
         (m:match (make-empt)
                  [($ empt) 'yes]
                  [_ 'no]))

   (comp 3
         (match (mcons 1 2)
           [(mcons a b) (+ a b)]
           [_ 'no]))

   (comp 3
         (match (mlist 1 2)
           [(mlist a b) (+ a b)]
           [_ 'no]))

   (comp 3
         (match (mlist 1 2)
           [(mlist a ...) (apply + a)]
           [_ 'no]))

   (comp 1
         (match (box 'x) ('#&x 1) (_ #f)))

   (comp 2
         (match (vector 1 2) ('#(1 2) 2) (_ #f)))

   (comp 'yes
         (with-handlers ([exn:fail? (lambda _ 'yes)]
                         [values (lambda _ 'no)])
                (match 1)
                'no))

   (comp 'yes
         (with-handlers ([exn:fail:syntax? (lambda _ 'yes)]
                         [values (lambda _ 'no)])
           (expand #'(let ()
                       (define-struct foo (bar))
                       (define the-bar (match (make-foo 42)
                                         [(struct foo bar) ;; note the bad syntax
                                          bar]))
                       0))))

   ;; raises error
   (comp 'yes (with-handlers ([exn:fail:syntax? (lambda _ 'yes)])
                (expand (quote-syntax (match '(1 x 2 y 3 z)
                                        [(list-no-order 1 2 3 rest ... e) rest]
                                        [_ 'no])))
                'no))
   (comp '((2 4) (2 1))
         (match '(3 2 4 3 2 1)
           [(list x y ... x z ...)
            (list y z)]))

   (comp '(1 2)
         (match-let ([(vector a b) (vector 1 2)])
                    (list a b)))

   (comp '(4 5)
         (let-values ([(x y)
                       (match 1
                         [(or (and x 2) (and x 3) (and x 4)) 3]
                         [_ (values 4 5)])])
           (list x y)))

   (comp 'bad
         (match #(1)
           [(vector a b) a]
           [_ 'bad]))

   (comp '(1 2)
         (call-with-values
          (lambda ()
            (match 'foo [_ (=> skip) (skip)] [_ (values 1 2)]))
          list))
   (comp 0
         (let ([z (make-parameter 0)])
           (match 1
             [(? number?) (=> f) (parameterize ([z 1]) (f))]
             [(? number?) (z)])))

   ;; make sure the prompts don't interfere
   (comp 12
         (%
          (let ([z (make-parameter 0)])
            (match 1
              [(? number?) (=> f) (parameterize ([z 1]) (fcontrol 5))]
              [(? number?) (z)]))
          (lambda _ 12)))


   (comp 4
	 (match 3
	  [(or) 1]
	  [_ 4]))

   (comp '((1 2) 3)
         (match `(begin 1 2 3)
           [`(begin ,es ... ,en)
            (list es en)]))

   (comp '((1 2 3 4) (6 7) (9))
         (match '(0 1 2 3 4 5 6 7 8 9)
           [`(0 ,@a 5 ,@b 8 ,@c)
            (list a b c)]))

   (comp '(a b c)
	 (let ()

	   (define-struct foo (a b c) #:prefab)
	   (match (make-foo 'a 'b 'c)
		  [`#s(foo ,x ,y ,z)
		   (list x y z)])))
   (comp '(a b c)
	 (let ()

	   (define-struct foo (a b c) #:prefab)
	   (define-struct (bar foo) (d) #:prefab)
	   (match (make-bar 'a 'b 'c 1)
		  [`#s((bar foo 3) ,x ,y ,z ,w)
		      (list x y z)])
	   ))
   (comp "Gotcha!"
         (let ()
           (define-cstruct _pose
             ([x _double*]
              [y _double*]
              [a _double*]))

           (match (make-pose 1 2 3)
             [(struct pose (x y a)) "Gotcha!"]
             [_ "Epic fail!"])))

   (comp #f
         (match (list 'a 'b 'c)
           [(or (list a b)
                (and (app (lambda _ #f) b)
                     (or (and (app (lambda _ #f) a)
                              (list))
                         (list a))))
            #t]
           [_ #f]))

   (comp '(2 7)
         (let ()
           (define-match-expander foo
             (syntax-rules () [(_) 1])
             (syntax-id-rules (set!)
               [(set! _ v) v]
               [(_) 2]))
           (list (foo)
                 (set! foo 7))))

   (comp 0
         (let ()
           (define-match-expander foo
             (syntax-id-rules () [_ 10]))
           (match 10
             [(foo) 0]
             [_ 1])))

   (comp '(1 2 4)
         (call-with-values
           (λ () (match-let-values ([(x y) (values 1 2)] [(3 w) (values 3 4)])
                   (values x y w)))
           list))

   (comp '(1 3 4)
         (call-with-values
           (λ () (match-let*-values ([(x y) (values 1 2)] [(y w) (values 3 4)])
                   (values x y w)))
           list))

   (comp '(1 2 3)
         (match/values (values 1 2 3)
           [(x y z) (list x y z)]))

   (comp '(1 2)
         (let () (match-define-values (x y 3) (values 1 2 3))
              (list x y)))

   (comp '(1 2 3)
         (match-let ([(list x y) (list 1 2)] [(list y z) '(2 3)])
            (list x y z)))

   (comp 'yes (match/values (values 1 2) [(x y) 0 'yes] [(_ _) 'no]))

   (comp 'yes
         (with-handlers ([exn:fail? (lambda _ 'yes)]
                         [values (lambda _ 'no)])
           (match-let ([(list x y) (list 1 22)] [(list y z) '(2 3)])
                      (list x y z))))

   (comp 1
         (match (cons 1 2)
           [(cons a b)
            (if (< a b)
                (failure-cont)
                0)]
           [_ 1]))

   (comp 0
         (match (cons 1 2)
           [(cons a b) #:when (= a b) 1]
           [_ 0]))

   (comp 1
         (match (cons 1 1)
           [(cons a b) #:when (= a b) 1]
           [_ 0]))

   (test-case "prefab structs and list-rest"
              (match #s(meow 1)
                [`#s(meow ,@(list-rest a))
                 a])
              (list 1))
   (test-case "mutated struct predicate"
     (let ()
       (r:struct point (x y))
       (set! point? pair?)
       (check-exn exn:fail:contract?
                  (lambda () (match (cons 1 2) [(point x y) (list x y)])))))
     

   (test-case
    "robby's slow example"
    (define v
      (let ()
        (define ht (make-hash))
        (define (L4e? e-exp)
          (hash-set! ht e-exp (+ (hash-ref ht e-exp 0) 1))
          (match e-exp
            [`(,(? is-biop?) ,(? L4e?) ,(? L4e?)) #t]
            [`(,_ ,(? L4e?)) #t]
            [`(new-array ,(? L4e?) ,(? L4e?)) #t]
            [`(new-tuple ,(? L4e?) ...) #t]
            [`(aref ,(? L4e?) ,(? L4e?)) #t]
            [`(aset ,(? L4e?) ,(? L4e?) ,(? L4e?)) #t]
            [`(alen ,(? L4e?)) #t]
            [`(print ,(? L4e?)) #t]
            [`(make-closure ,(? symbol?) ,(? L4e?)) #t]
            [`(closure-proc ,(? L4e?)) #t]
            [`(begin ,(? L4e?) ,(? L4e?)) #t]
            [`(closure-vars ,(? L4e?)) #t]
            [`(let ((,(? symbol?) ,(? L4e?))) ,(? L4e?)) #t]
            [`(if ,(? L4e?) ,(? L4e?) ,(? L4e?)) #t]
            [`(,(? L4e?) ...) #t]
            [(? L3v?) #t]
            [_ #f]))

        (define (is-biop? sym) (or (is-aop? sym) (is-cmp? sym)))
        (define (is-aop? sym) (memq sym '(+ - *)))
        (define (is-cmp? sym) (memq sym '(< <= =)))
        (define (L3v? v) (or (number? v) (symbol? v)))
        (list
         (L4e? '(let ((less_than (make-closure :lambda_0 (new-tuple))))
                  (let ((L5_swap (make-closure :lambda_1 (new-tuple))))
                    (let ((L5_sort_helper (new-tuple 0)))
                      (begin
                        (aset L5_sort_helper 0 (make-closure :lambda_2 (new-tuple L5_sort_helper L5_swap)))
                        (let ((L5_sort (new-tuple 0)))
                          (begin
                            (aset L5_sort 0 (make-closure :lambda_3 (new-tuple L5_sort_helper L5_sort)))
                            (print (let ((f (aref L5_sort 0)))
                                     ((closure-proc f)
                                      (closure-vars f)
                                      (new-tuple 3 1 9 4 5 6 2 8 7 10)
                                      less_than))))))))))
         (apply max (hash-values ht)))))
    (check-true (car v))
    (check < (cadr v) 50))

   (test-case "syntax-local-match-introduce"
     (define-match-expander foo
       (lambda (stx) (syntax-local-match-introduce #'x)))
     (check-equal? (match 42
                     [(foo) x])
                   42))

   (test-case "ordering"
     (define b (box #t))
     (check-equal?
      (match b
        [(and x (? (λ _ (set-box! b #f))) (app unbox #f)) 'yes]
        [_ 'no])
      'yes))

   (test-case "match-expander rename transformer"
           (define-match-expander foo
             (lambda (stx) (syntax-case stx () [(_ a) #'a]))
             (make-rename-transformer #'values))

           (check-equal? (foo 2) 2))

   (test-case "match-expander rename transformer set!"
              (define x 1)
              (define-match-expander foo
                (lambda (stx) (syntax-case stx () [(_ a) #'a]))
                (make-rename-transformer #'x))

              (set! foo 2)
              (check-equal? x 2))

   (test-case
    "match-expander with arity 2"
    (define-syntax forty-two-pat
      (let ()
        (define-struct datum-pat (datum)
          #:property prop:match-expander
          (lambda (pat stx)
            (datum->syntax #'here (datum-pat-datum pat) stx)))
        (make-datum-pat 42)))
    (check-equal? (match 42
                    [(forty-two-pat) #t])
                  #t))


))
