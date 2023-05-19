
(load-relative "loadtest.rktl")

(Section 'unsafe)

(require racket/unsafe/ops
         racket/flonum
         racket/fixnum
         ffi/vector
         racket/extflonum)

(let* ([identity (lambda (x) x)]
       [compose (lambda (f g)
                  (if (eq? f identity)
                      g
                      (compose f g)))])
  (define ((add-star str) sym)
    (string->symbol (regexp-replace str (symbol->string sym) (string-append str "*"))))
  (define (test-tri result proc x y z
                    #:pre [pre void]
                    #:post [post identity]
                    #:literal-ok? [lit-ok? #t]
                    #:branch? [branch? #f])
    (pre)
    (test result (compose post (eval proc)) x y z)
    (pre)
    (test result (compose post (eval `(lambda (x y z) (,proc x y z)))) x y z)
    (when lit-ok?
      (pre)
      (test result (compose post (eval `(lambda (y z) (,proc ,x y z)))) y z))
    (pre)
    (test result (compose post (eval `(lambda (x z) (,proc x ,y z)))) x z)
    (pre)
    (test result (compose post (eval `(lambda (x y) (,proc x y ,z)))) x y)
    (pre)
    (test result (compose post (eval `(lambda (x) (,proc x ,y ,z)))) x)
    (pre)
    (when lit-ok?
      (pre)
      (test result (compose post (eval `(lambda (y) (,proc ,x y ,z)))) y)
      (pre)
      (test result (compose post (eval `(lambda (z) (,proc ,x ,y z)))) z)
      (pre)
      (test result (compose post (eval `(lambda () (,proc ,x ,y ,z))))))
    (when branch?
      (pre)
      (test (if result 'yes 'no) (compose post (eval `(lambda (x y z) (if (,proc x y z) 'yes 'no)))) x y z)
      (when lit-ok?
        (pre)
        (test (if result 'yes 'no) (compose post (eval `(lambda (y z) (if (,proc ,x y z) 'yes 'no)))) y z))
      (pre)
      (test (if result 'yes 'no) (compose post (eval `(lambda (x z) (if (,proc x ,y z) 'yes 'no)))) x z)
      (pre)
      (test (if result 'yes 'no) (compose post (eval `(lambda (x y) (if (,proc x y ,z) 'yes 'no)))) x y)
      (when lit-ok?
        (pre)
        (test (if result 'yes 'no) (compose post (eval `(lambda (z) (if (,proc ,x ,y z) 'yes 'no)))) z)
        (pre)
        (test (if result 'yes 'no) (compose post (eval `(lambda (y) (if (,proc ,x y ,z) 'yes 'no)))) y))
      (pre)
      (test (if result 'yes 'no) (compose post (eval `(lambda (x) (if (,proc x ,y ,z) 'yes 'no)))) x)))
  (define (test-bin result proc x y
                    #:pre [pre void]
                    #:post [post identity]
                    #:literal-ok? [lit-ok? #t]
                    #:branch? [branch? #f])
    (pre)
    (test result (compose post (eval proc)) x y)
    (pre)
    (test result (compose post (eval `(lambda (x y) (,proc x y)))) x y)
    (when lit-ok?
      (pre)
      (test result (compose post (eval `(lambda (y) (,proc ',x y)))) y)
      (pre)
      (test result (compose post (eval `(lambda () (,proc ',x ',y))))))
    (pre)
    (test result (compose post (eval `(lambda (x) (,proc x ',y)))) x)
    (when branch?
      (pre)
      (test (if result 'yep 'nope) (compose post (eval `(lambda (x y) (if (,proc x y) 'yep 'nope)))) x y)
      (when lit-ok?
        (pre)
        (test (if result 'yep 'nope) (compose post (eval `(lambda (y) (if (,proc ,x y) 'yep 'nope)))) y))
      (pre)
      (test (if result 'yep 'nope) (compose post (eval `(lambda (x) (if (,proc x ,y) 'yep 'nope)))) x)))
  (define (test-un result proc x
                   #:pre [pre void]
                   #:post [post identity]
                   #:branch? [branch? #f]
                   #:literal-ok? [lit-ok? #t])
    (pre)
    (test result (compose post (eval proc)) x)
    (pre)
    (test result (compose post (eval `(lambda (x) (,proc x)))) x)
    (when lit-ok?
      (pre)
      (test result (compose post (eval `(lambda () (,proc ',x))))))
    (when branch?
      (pre)
      (test (if result 'y 'n) (compose post (eval `(lambda (x) (if (,proc x) 'y 'n)))) x)
      (when lit-ok?
        (pre)
        (test (if result 'y 'n) (compose post (eval `(lambda () (if (,proc ',x) 'y 'n))))))))
  (define (test-zero result proc
                     #:pre [pre void]
                     #:post [post identity])
    (pre)
    (test result (compose post (eval proc)))
    (pre)
    (test result (compose post (eval `(lambda () (,proc))))))

  (test-zero 0 'unsafe-fx+)
  (test-un 7 'unsafe-fx+ 7)
  (test-bin 3 'unsafe-fx+ 1 2)
  (test-bin -1 'unsafe-fx+ 1 -2)
  (test-bin 12 'unsafe-fx+ 12 0)
  (test-bin -12 'unsafe-fx+ 0 -12)
  (test-tri 72 'unsafe-fx+ 12 23 37)

  (test-un -10 'unsafe-fx- 10)
  (test-bin 8 'unsafe-fx- 10 2)
  (test-bin 3 'unsafe-fx- 1 -2)
  (test-bin 13 'unsafe-fx- 13 0)
  (test-tri 2 'unsafe-fx- 37 12 23)

  (test-zero 1 'unsafe-fx*)
  (test-un 17 'unsafe-fx* 17)
  (test-bin 20 'unsafe-fx* 10 2)
  (test-bin -20 'unsafe-fx* 10 -2)
  (test-bin -2 'unsafe-fx* 1 -2)
  (test-bin -21 'unsafe-fx* -21 1)
  (test-bin 0 'unsafe-fx* 0 -2)
  (test-bin 0 'unsafe-fx* -21 0)
  (err/rt-test (unsafe-fx* 0 (error "bad")) exn:fail?) ; not 0
  (err/rt-test (unsafe-fx* (error "bad") 0) exn:fail?) ; not 0
  (test-tri 60 'unsafe-fx* 3 4 5)

  (test-bin 3 'unsafe-fxquotient 17 5)
  (test-bin -3 'unsafe-fxquotient 17 -5)
  (test-bin 0 'unsafe-fxquotient 0 -5)
  (test-bin 18 'unsafe-fxquotient 18 1)
  (err/rt-test (unsafe-fxquotient 0 (error "bad")) exn:fail?) ; not 0

  (test-bin 2 'unsafe-fxremainder 17 5)
  (test-bin 2 'unsafe-fxremainder 17 -5)
  (test-bin 0 'unsafe-fxremainder 0 -5)
  (test-bin 0 'unsafe-fxremainder 10 1)
  (err/rt-test (unsafe-fxremainder (error "bad") 1) exn:fail?) ; not 0

  (test-bin 2 'unsafe-fxmodulo 17 5)
  (test-bin -3 'unsafe-fxmodulo 17 -5)
  (test-bin 0 'unsafe-fxmodulo 0 -5)
  (test-bin 0 'unsafe-fxmodulo 10 1)
  (err/rt-test (unsafe-fxmodulo (error "bad") 1) exn:fail?) ; not 0
  (err/rt-test (unsafe-fxmodulo 0 (error "bad")) exn:fail?) ; not 0

  (test-bin 60 'unsafe-fxlshift 15 2)  
  (test-bin 3 'unsafe-fxrshift 15 2)

  (test-zero 0.0 'unsafe-fl+)
  (test-un 6.7 'unsafe-fl+ 6.7)
  (test-bin 3.4 'unsafe-fl+ 1.4 2.0)
  (test-bin -1.1 'unsafe-fl+ 1.0 -2.1)
  (test-bin +inf.0 'unsafe-fl+ 1.0 +inf.0)
  (test-bin -inf.0 'unsafe-fl+ 1.0 -inf.0)
  (test-bin +nan.0 'unsafe-fl+ +nan.0 -inf.0)
  (test-bin 1.5 'unsafe-fl+ 1.5 0.0)
  (test-bin 1.7 'unsafe-fl+ 0.0 1.7)
  (test-tri 1.25 'unsafe-fl* 1.0 2.5 0.5)

  (test-un #t unsafe-fx= 1 #:branch? #t)
  (test-bin #f unsafe-fx= 1 2 #:branch? #t)
  (test-bin #t unsafe-fx= 2 2 #:branch? #t)
  (test-bin #f unsafe-fx= 2 1 #:branch? #t)
  (test-tri #t unsafe-fx= 2 2 2 #:branch? #t)
  (test-tri #f unsafe-fx= 1 2 2 #:branch? #t)
  (test-tri #f unsafe-fx= 2 1 2 #:branch? #t)
  (test-tri #f unsafe-fx= 2 2 1 #:branch? #t)

  (test-un #t unsafe-fx< 1 #:branch? #t)
  (test-bin #t unsafe-fx< 1 2 #:branch? #t)
  (test-bin #f unsafe-fx< 2 2 #:branch? #t)
  (test-bin #f unsafe-fx< 2 1 #:branch? #t)
  (test-tri #t unsafe-fx< 1 2 3 #:branch? #t)
  (test-tri #f unsafe-fx< 2 2 3 #:branch? #t)
  (test-tri #f unsafe-fx< 1 2 2 #:branch? #t)

  (test-un #t unsafe-fx> 1 #:branch? #t)
  (test-bin #f unsafe-fx> 1 2 #:branch? #t)
  (test-bin #f unsafe-fx> 2 2 #:branch? #t)
  (test-bin #t unsafe-fx> 2 1 #:branch? #t)
  (test-tri #t unsafe-fx> 2 1 0 #:branch? #t)
  (test-tri #f unsafe-fx> 2 2 0 #:branch? #t)
  (test-tri #f unsafe-fx> 2 1 1 #:branch? #t)

  (test-un #t unsafe-fx<= 1 #:branch? #t)
  (test-bin #t unsafe-fx<= 1 2 #:branch? #t)
  (test-bin #t unsafe-fx<= 2 2 #:branch? #t)
  (test-bin #f unsafe-fx<= 2 1 #:branch? #t)
  (test-tri #t unsafe-fx<= 1 1 1 #:branch? #t)
  (test-tri #t unsafe-fx<= 1 2 3 #:branch? #t)
  (test-tri #f unsafe-fx<= 3 2 3 #:branch? #t)
  (test-tri #f unsafe-fx<= 1 2 1 #:branch? #t)

  (test-un #t unsafe-fx>= 1 #:branch? #t)
  (test-bin #f unsafe-fx>= 1 2 #:branch? #t)
  (test-bin #t unsafe-fx>= 2 2 #:branch? #t)
  (test-bin #t unsafe-fx>= 2 1 #:branch? #t)
  (test-tri #t unsafe-fx>= 3 2 1 #:branch? #t)
  (test-tri #t unsafe-fx>= 3 3 3 #:branch? #t)
  (test-tri #f unsafe-fx>= 3 4 1 #:branch? #t)
  (test-tri #f unsafe-fx>= 3 2 3 #:branch? #t)

  (test-un 3 unsafe-fxmin 3)
  (test-bin 3 unsafe-fxmin 3 30)
  (test-bin -30 unsafe-fxmin 3 -30)
  (test-tri 3 unsafe-fxmin 3 7 8)
  (test-tri -1 unsafe-fxmin 3 -1 8)
  (test-tri -8 unsafe-fxmin 3 7 -8)

  (test-un 30 unsafe-fxmax 30)
  (test-bin 30 unsafe-fxmax 3 30)
  (test-bin 3 unsafe-fxmax 3 -30)
  (test-tri 3 unsafe-fxmax 3 -30 -90)
  (test-tri 30 unsafe-fxmax 3 30 -90)
  (test-tri 90 unsafe-fxmax 3 30 90)

  (test-bin #f unsafe-char=? #\1 #\2 #:branch? #t)
  (test-bin #t unsafe-char=? #\2 #\2 #:branch? #t)
  (test-bin #f unsafe-char=? #\2 #\1 #:branch? #t)

  (test-bin #t unsafe-char<? #\1 #\2 #:branch? #t)
  (test-bin #f unsafe-char<? #\2 #\2 #:branch? #t)
  (test-bin #f unsafe-char<? #\2 #\1 #:branch? #t)

  (test-bin #f unsafe-char>? #\1 #\2 #:branch? #t)
  (test-bin #f unsafe-char>? #\2 #\2 #:branch? #t)
  (test-bin #t unsafe-char>? #\2 #\1 #:branch? #t)

  (test-bin #t unsafe-char<=? #\1 #\2 #:branch? #t)
  (test-bin #t unsafe-char<=? #\2 #\2 #:branch? #t)
  (test-bin #f unsafe-char<=? #\2 #\1 #:branch? #t)

  (test-bin #f unsafe-char>=? #\1 #\2 #:branch? #t)
  (test-bin #t unsafe-char>=? #\2 #\2 #:branch? #t)
  (test-bin #t unsafe-char>=? #\2 #\1 #:branch? #t)

  (test-un 49 unsafe-char->integer #\1)

  (test-un -7.8 'unsafe-fl- 7.8)
  (test-bin 7.9 'unsafe-fl- 10.0 2.1)
  (test-bin 3.7 'unsafe-fl- 1.0 -2.7)
  (test-bin 1.5 'unsafe-fl- 1.5 0.0)
  (test-tri 0.75 'unsafe-fl- 1.5 0.5 0.25)

  (test-zero 1.0 'unsafe-fl*)
  (test-un 4.5 'unsafe-fl* 4.5)
  (test-bin 20.02 'unsafe-fl* 10.01 2.0)
  (test-bin -20.02 'unsafe-fl* 10.01 -2.0)
  (test-bin +nan.0 'unsafe-fl* +inf.0 0.0)
  (test-bin 1.8 'unsafe-fl* 1.0 1.8)
  (test-bin 1.81 'unsafe-fl* 1.81 1.0)

  (test-un 0.125 'unsafe-fl/ 8.0)
  (test-bin (exact->inexact 17/5) 'unsafe-fl/ 17.0 5.0)
  (test-bin +inf.0 'unsafe-fl/ 17.0 0.0)
  (test-bin -inf.0 'unsafe-fl/ -17.0 0.0)
  (test-bin 1.5 'unsafe-fl/ 1.5 1.0)
  (test-tri 1.0 'unsafe-fl/ 8.0 2.0 4.0)

  (when (extflonum-available?)
    (test-bin 3.4t0 'unsafe-extfl+ 1.4t0 2.0t0)
    (test-bin -1.0999999999999999999t0 'unsafe-extfl+ 1.0t0 -2.1t0)
    (test-bin +inf.t 'unsafe-extfl+ 1.0t0 +inf.t)
    (test-bin -inf.t 'unsafe-extfl+ 1.0t0 -inf.t)
    (test-bin +nan.t 'unsafe-extfl+ +nan.t -inf.t)
    (test-bin 1.5t0 'unsafe-extfl+ 1.5t0 0.0t0)
    (test-bin 1.7t0 'unsafe-extfl+ 0.0t0 1.7t0)

    (test-bin 7.9t0 'unsafe-extfl- 10.0t0 2.1t0)
    (test-bin 3.7t0 'unsafe-extfl- 1.0t0 -2.7t0)
    (test-bin 1.5t0 'unsafe-extfl- 1.5t0 0.0t0)

    (test-bin 20.002t0 'unsafe-extfl* 10.001t0 2.0t0)
    (test-bin -20.002t0 'unsafe-extfl* 10.001t0 -2.0t0)
    (test-bin +nan.t 'unsafe-extfl* +inf.t 0.0t0)
    (test-bin 1.8t0 'unsafe-extfl* 1.0t0 1.8t0)
    (test-bin 1.81t0 'unsafe-extfl* 1.81t0 1.0t0)

    (test-bin (real->extfl 17/5) 'unsafe-extfl/ 17.0t0 5.0t0)
    (test-bin +inf.t 'unsafe-extfl/ 17.0t0 0.0t0)
    (test-bin -inf.t 'unsafe-extfl/ -17.0t0 0.0t0)
    (test-bin 1.5t0 'unsafe-extfl/ 1.5t0 1.0t0)

    (test-un 5.0t0 unsafe-extflabs 5.0t0)
    (test-un 5.0t0 unsafe-extflabs -5.0t0)
    (test-un 0.0t0 unsafe-extflabs -0.0t0)
    (test-un +inf.t unsafe-extflabs -inf.t)

    (test-un 5.0t0 unsafe-extflsqrt 25.0t0)
    (test-un 0.5t0 unsafe-extflsqrt 0.25t0)
    (test-un +nan.t unsafe-extflsqrt -1.0t0)

    (test-un 8.0t0 'unsafe-fx->extfl 8)
    (test-un -8.0t0 'unsafe-fx->extfl -8)

    (test-un 8 'unsafe-extfl->fx 8.0t0)
    (test-un -8 'unsafe-extfl->fx -8.0t0)

    (test-bin 3.7t0 'unsafe-extflmin 3.7t0 4.1t0)
    (test-bin 2.1t0 'unsafe-extflmin 3.7t0 2.1t0)
    (test-bin +nan.t 'unsafe-extflmin +nan.t 2.1t0)
    (test-bin +nan.t 'unsafe-extflmin 2.1t0 +nan.t)
    (test-bin 3.7t0 'unsafe-extflmax 3.7t0 2.1t0)
    (test-bin 4.1t0 'unsafe-extflmax 3.7t0 4.1t0)
    (test-bin +nan.t 'unsafe-extflmax +nan.t 2.1t0)
    (test-bin +nan.t 'unsafe-extflmax 2.1t0 +nan.t))

  (test-zero -1 'unsafe-fxand)
  (test-un 10 'unsafe-fxand 10)
  (test-bin 3 'unsafe-fxand 7 3)
  (test-bin 2 'unsafe-fxand 6 3)
  (test-bin 3 'unsafe-fxand -1 3)
  (test-tri 1 'unsafe-fxand -1 3 17)

  (test-zero 0 'unsafe-fxior)
  (test-un 10 'unsafe-fxior 10)
  (test-bin 7 'unsafe-fxior 7 3)
  (test-bin 7 'unsafe-fxior 6 3)
  (test-bin -1 'unsafe-fxior -1 3)
  (test-tri 19 'unsafe-fxior 2 3 17)

  (test-zero 0 'unsafe-fxxor)
  (test-un 10 'unsafe-fxxor 10)
  (test-bin 4 'unsafe-fxxor 7 3)
  (test-bin 5 'unsafe-fxxor 6 3)
  (test-bin -4 'unsafe-fxxor -1 3)
  (test-tri 16 'unsafe-fxxor 2 3 17)

  (test-un -1 'unsafe-fxnot 0)
  (test-un -4 'unsafe-fxnot 3)

  (test-bin 32 'unsafe-fxlshift 2 4)
  (test-bin 32 'unsafe-fxlshift 8 2)
  (test-bin 8 'unsafe-fxlshift 8 0)

  (test-bin 2 'unsafe-fxrshift 32 4)
  (test-bin -1 'unsafe-fxrshift -1 2)
  (test-bin 8 'unsafe-fxrshift 32 2)
  (test-bin 8 'unsafe-fxrshift 8 0)
  (test-bin 2 'unsafe-fxrshift/logical 32 4)
  (test-bin -1 'unsafe-fxrshift/logical -1 0)
  (test-bin (most-positive-fixnum) 'unsafe-fxrshift/logical -1 1)

  (test-un 5 unsafe-fxabs 5)
  (test-un 5 unsafe-fxabs -5)
  (test-un 5.0 unsafe-flabs 5.0)
  (test-un 5.0 unsafe-flabs -5.0)
  (test-un 0.0 unsafe-flabs -0.0)
  (test-un +inf.0 unsafe-flabs -inf.0)

  (test-un 5.0 unsafe-flsqrt 25.0)
  (test-un 0.5 unsafe-flsqrt 0.25)
  (test-un +nan.0 unsafe-flsqrt -1.0)

  (test-un 1.0 unsafe-flsingle 1.0)
  (test-un -1.0 unsafe-flsingle -1.0)
  (test-un +nan.0 unsafe-flsingle +nan.0)
  (test-un +inf.0 unsafe-flsingle +inf.0)
  (test-un -inf.0 unsafe-flsingle -inf.0)
  (test-un 1.2500000360947476e38 unsafe-flsingle 1.25e38)
  (test-un 1.2500000449239123e-37 unsafe-flsingle 1.25e-37)
  (test-un -1.2500000360947476e38 unsafe-flsingle -1.25e38)
  (test-un  -1.2500000449239123e-37 unsafe-flsingle -1.25e-37)
  (test-un +inf.0 unsafe-flsingle 1e100)
  (test-un -inf.0 unsafe-flsingle -1e100)
  (test-un 0.0 unsafe-flsingle 1e-100)
  (test-un -0.0 unsafe-flsingle -1e-100)

  (test-un 8.0 'unsafe-fx->fl 8)
  (test-un -8.0 'unsafe-fx->fl -8)

  (test-un 8 'unsafe-fl->fx 8.0)
  (test-un -8 'unsafe-fl->fx -8.0)

  (test-zero 0.0 'unsafe-fl+)
  (test-un 7.0 'unsafe-fl+ 7.0)
  (test-bin 3.0 'unsafe-fl+ 1.0 2.0)
  (test-bin -1.0 'unsafe-fl+ 1.0 -2.0)
  (test-bin 12.0 'unsafe-fl+ 12.0 0.0)
  (test-bin -12.0 'unsafe-fl+ 0.0 -12.0)
  (test-tri 72.0 'unsafe-fl+ 12.0 23.0 37.0)

  (test-un -10.0 'unsafe-fl- 10.0)
  (test-bin 8.0 'unsafe-fl- 10.0 2.0)
  (test-bin 3.0 'unsafe-fl- 1.0 -2.0)
  (test-bin 13.0 'unsafe-fl- 13.0 0.0)
  (test-tri 2.0 'unsafe-fl- 37.0 12.0 23.0)

  (test-zero 1.0 'unsafe-fl*)
  (test-un 17.0 'unsafe-fl* 17.0)
  (test-bin 20.0 'unsafe-fl* 10.0 2.0)
  (test-bin -20.0 'unsafe-fl* 10.0 -2.0)
  (test-bin -2.0 'unsafe-fl* 1.0 -2.0)
  (test-bin -21.0 'unsafe-fl* -21.0 1.0)
  (test-bin -0.0 'unsafe-fl* 0.0 -2.0)
  (test-bin -0.0 'unsafe-fl* -21.0 0.0)
  (test-tri 60.0 'unsafe-fl* 3.0 4.0 5.0)
  (test-tri +nan.0 'unsafe-fl* 3.0 +nan.0 5.0)

  (test-un 0.25 'unsafe-fl/ 4.0)
  (test-bin 5.0 'unsafe-fl/ 10.0 2.0)
  (test-bin -5.0 'unsafe-fl/ 10.0 -2.0)
  (test-bin -0.5 'unsafe-fl/ 1.0 -2.0)
  (test-bin -21.0 'unsafe-fl/ -21.0 1.0)
  (test-bin -0.0 'unsafe-fl/ 0.0 -2.0)
  (test-bin -inf.0 'unsafe-fl/ -21.0 0.0)
  (test-tri (/ 3.0 20.0) 'unsafe-fl/ 3.0 4.0 5.0)
  (test-tri +nan.0 'unsafe-fl/ 3.0 +nan.0 5.0)

  (test-un #t unsafe-fl= 1.0 #:branch? #t)
  (test-bin #f unsafe-fl= 1.0 2.0 #:branch? #t)
  (test-bin #t unsafe-fl= 2.0 2.0 #:branch? #t)
  (test-bin #f unsafe-fl= 2.0 1.0 #:branch? #t)
  (test-tri #t unsafe-fl= 2.0 2.0 2.0 #:branch? #t)
  (test-tri #f unsafe-fl= 1.0 2.0 2.0 #:branch? #t)
  (test-tri #f unsafe-fl= 2.0 1.0 2.0 #:branch? #t)
  (test-tri #f unsafe-fl= 2.0 2.0 1.0 #:branch? #t)

  (test-un #t unsafe-fl< 1.0 #:branch? #t)
  (test-bin #t unsafe-fl< 1.0 2.0 #:branch? #t)
  (test-bin #f unsafe-fl< 2.0 2.0 #:branch? #t)
  (test-bin #f unsafe-fl< 2.0 1.0 #:branch? #t)
  (test-tri #t unsafe-fl< 1.0 2.0 3.0 #:branch? #t)
  (test-tri #f unsafe-fl< 2.0 2.0 3.0 #:branch? #t)
  (test-tri #f unsafe-fl< 1.0 2.0 2.0 #:branch? #t)

  (test-un #t unsafe-fl> 1.0 #:branch? #t)
  (test-bin #f unsafe-fl> 1.0 2.0 #:branch? #t)
  (test-bin #f unsafe-fl> 2.0 2.0 #:branch? #t)
  (test-bin #t unsafe-fl> 2.0 1.0 #:branch? #t)
  (test-tri #t unsafe-fl> 2.0 1.0 0.0 #:branch? #t)
  (test-tri #f unsafe-fl> 2.0 2.0 0.0 #:branch? #t)
  (test-tri #f unsafe-fl> 2.0 1.0 1.0 #:branch? #t)

  (test-un #t unsafe-fl<= 1.0 #:branch? #t)
  (test-bin #t unsafe-fl<= 1.0 2.0 #:branch? #t)
  (test-bin #t unsafe-fl<= 2.0 2.0 #:branch? #t)
  (test-bin #f unsafe-fl<= 2.0 1.0 #:branch? #t)
  (test-tri #t unsafe-fl<= 1.0 1.0 1.0 #:branch? #t)
  (test-tri #t unsafe-fl<= 1.0 2.0 3.0 #:branch? #t)
  (test-tri #f unsafe-fl<= 3.0 2.0 3.0 #:branch? #t)
  (test-tri #f unsafe-fl<= 1.0 2.0 1.0 #:branch? #t)

  (test-un #t unsafe-fl>= 1.0 #:branch? #t)
  (test-bin #f unsafe-fl>= 1.0 2.0 #:branch? #t)
  (test-bin #t unsafe-fl>= 2.0 2.0 #:branch? #t)
  (test-bin #t unsafe-fl>= 2.0 1.0 #:branch? #t)
  (test-tri #t unsafe-fl>= 3.0 2.0 1.0 #:branch? #t)
  (test-tri #t unsafe-fl>= 3.0 3.0 3.0 #:branch? #t)
  (test-tri #f unsafe-fl>= 3.0 4.0 1.0 #:branch? #t)
  (test-tri #f unsafe-fl>= 3.0 2.0 3.0 #:branch? #t)

  (test-un 3.7 'unsafe-flmin 3.7)
  (test-bin 3.7 'unsafe-flmin 3.7 4.1)
  (test-bin 2.1 'unsafe-flmin 3.7 2.1)
  (test-bin +nan.0 'unsafe-flmin +nan.0 2.1)
  (test-bin +nan.0 'unsafe-flmin 2.1 +nan.0)
  (test-tri +nan.0 'unsafe-flmin +nan.0 2.1 3.4)
  (test-tri +nan.0 'unsafe-flmin 2.1 +nan.0 3.4)
  (test-tri +nan.0 'unsafe-flmin 2.1 3.4 +nan.0)
  (test-un 2.1 'unsafe-flmax 2.1)
  (test-bin 3.7 'unsafe-flmax 3.7 2.1)
  (test-bin 4.1 'unsafe-flmax 3.7 4.1)
  (test-bin +nan.0 'unsafe-flmax +nan.0 2.1)
  (test-bin +nan.0 'unsafe-flmax 2.1 +nan.0)
  (test-tri +nan.0 'unsafe-flmax +nan.0 2.1 3.4)
  (test-tri +nan.0 'unsafe-flmax 2.1 +nan.0 3.4)
  (test-tri +nan.0 'unsafe-flmax 2.1 3.4 +nan.0)

  (test-bin 1.7+45.0i 'unsafe-make-flrectangular 1.7 45.0)
  (test-un 3.5 'unsafe-flreal-part 3.5+4.6i)
  (test-un 4.6 'unsafe-flimag-part 3.5+4.6i)

  ;; test unboxing:
  (test-tri 9.0 '(lambda (x y z) (unsafe-fl+ (unsafe-fl- x z) y)) 4.5 7.0 2.5)
  (test-tri 9.0 '(lambda (x y z) (unsafe-fl+ y (unsafe-fl- x z))) 4.5 7.0 2.5)
  (test-bin 10.0 '(lambda (x y) (unsafe-fl+ (unsafe-fx->fl x) y)) 2 8.0)
  (test-bin 10.0 '(lambda (x y) (unsafe-fl+ (unsafe-fx->fl x) y)) 2 8.0)
  (test-bin 9.5 '(lambda (x y) (unsafe-fl+ (unsafe-flabs x) y)) -2.0 7.5)
  (test-tri (/ 20.0 0.8) '(lambda (x y z) (unsafe-fl/ (unsafe-fl* x z) y)) 4.0 0.8 5.0)
  (test-tri (/ 0.8 20.0) '(lambda (x y z) (unsafe-fl/ y (unsafe-fl* x z))) 4.0 0.8 5.0)
  (test-tri #t '(lambda (x y z) (unsafe-fl< (unsafe-fl+ x y) z)) 1.2 3.4 5.0)
  (test-tri 'yes '(lambda (x y z) (if (unsafe-fl< (unsafe-fl+ x y) z) 'yes 'no)) 1.2 3.4 5.0)
  (test-tri #f '(lambda (x y z) (unsafe-fl> (unsafe-fl+ x y) z)) 1.2 3.4 5.0)
  (test-tri 'no '(lambda (x y z) (if (unsafe-fl> (unsafe-fl+ x y) z) 'yes 'no)) 1.2 3.4 5.0)

  (when (extflonum-available?)
    (test-tri 9.0t0 '(lambda (x y z) (unsafe-extfl+ (unsafe-extfl- x z) y)) 4.5t0 7.0t0 2.5t0)
    (test-tri 9.0t0 '(lambda (x y z) (unsafe-extfl+ y (unsafe-extfl- x z))) 4.5t0 7.0t0 2.5t0)
    (test-bin 10.0t0 '(lambda (x y) (unsafe-extfl+ (unsafe-fx->extfl x) y)) 2 8.0t0)
    (test-bin 10.0t0 '(lambda (x y) (unsafe-extfl+ (unsafe-fx->extfl x) y)) 2 8.0t0)
    (test-bin 9.5t0 '(lambda (x y) (unsafe-extfl+ (unsafe-extflabs x) y)) -2.0t0 7.5t0)
    (test-tri (unsafe-extfl/ 20.0t0 0.8t0) '(lambda (x y z) (unsafe-extfl/ (unsafe-extfl* x z) y)) 4.0t0 0.8t0 5.0t0)
    (test-tri (unsafe-extfl/ 0.8t0 20.0t0) '(lambda (x y z) (unsafe-extfl/ y (unsafe-extfl* x z))) 4.0t0 0.8t0 5.0t0)

    (test-tri #t '(lambda (x y z) (unsafe-extfl< (unsafe-extfl+ x y) z)) 1.2t0 3.4t0 5.0t0)
    (test-tri 'yes '(lambda (x y z) (if (unsafe-extfl< (unsafe-extfl+ x y) z) 'yes 'no)) 1.2t0 3.4t0 5.0t0)
    (test-tri #f '(lambda (x y z) (unsafe-extfl> (unsafe-extfl+ x y) z)) 1.2t0 3.4t0 5.0t0)
    (test-tri 'no '(lambda (x y z) (if (unsafe-extfl> (unsafe-extfl+ x y) z) 'yes 'no)) 1.2t0 3.4t0 5.0t0))

  ;; test unboxing interaction with free variables:
  (test-tri 4.4 '(lambda (x y z) (with-handlers ([exn:fail:contract:variable?
                                                  (lambda (exn) (unsafe-fl+ x y))])
                                   (unsafe-fl- (unsafe-fl+ x y) NO-SUCH-VARIABLE)))
            1.1 3.3 5.2)

  (when (extflonum-available?)
    (test-tri 4.4t0 '(lambda (x y z) (with-handlers ([exn:fail:contract:variable?
                                                      (lambda (exn) (unsafe-extfl+ x y))])
                                       (unsafe-extfl- (unsafe-extfl+ x y) NO-SUCH-VARIABLE)))
              1.1t0 3.3t0 5.2t0))

  (let ([r (make-pseudo-random-generator)]
        [seed (random 100000)])
    (define (reset)
      (parameterize ([current-pseudo-random-generator r])
        (random-seed seed)))
    (reset)
    (define val (random r))
    (test-un val 'unsafe-flrandom r
             #:pre reset))

  (test-un 5 'unsafe-car (cons 5 9))
  (test-un 9 'unsafe-cdr (cons 5 9))
  (let ([v (cons 3 7)])
    (test-bin 8 'unsafe-set-immutable-car! v 8
              #:pre (lambda () (unsafe-set-immutable-car! v 0))
              #:post (lambda (x) (car v))
              #:literal-ok? #f)
    (test-bin 9 'unsafe-set-immutable-cdr! v 9
              #:pre (lambda () (unsafe-set-immutable-cdr! v 0))
              #:post (lambda (x) (cdr v))
              #:literal-ok? #f))
  (test-un 15 'unsafe-mcar (mcons 15 19))
  (test-un 19 'unsafe-mcdr (mcons 15 19))
  (let ([v (mcons 3 7)])
    (test-bin 8 'unsafe-set-mcar! v 8
              #:pre (lambda () (set-mcar! v 0))
              #:post (lambda (x) (mcar v))
              #:literal-ok? #f)
    (test-bin 9 'unsafe-set-mcdr! v 9
              #:pre (lambda () (set-mcdr! v 0))
              #:post (lambda (x) (mcdr v))
              #:literal-ok? #f))
  (test-bin 5 'unsafe-list-ref (cons 5 9) 0)
  (test-bin 8 'unsafe-list-ref (cons 5 (cons 8 9)) 1)
  (test-bin 9 'unsafe-list-ref (cons 5 (cons 8 (cons 9 10))) 2)
  (test-bin (cons 5 9) 'unsafe-list-tail (cons 5 9) 0)
  (test-bin 3 'unsafe-list-tail 3 0)
  (test-bin 9 'unsafe-list-tail (cons 5 9) 1)
  (test-bin 8 'unsafe-list-tail (cons 5 (cons 9 8)) 2)

  (for ([star (list values (add-star "box"))])
    (test-un 3 (star 'unsafe-unbox) #&3)
    (let ([b (box 12)])
      (test-tri (list (void) 8)
                `(lambda (b i val) (,(star 'unsafe-set-box!) b val))
                b 0 8
                #:pre (lambda () (set-box! b 12))
                #:post (lambda (x) (list x (unbox b)))
                #:literal-ok? #f)))
  (test-un 3 'unsafe-unbox (chaperone-box (box 3)
                                          (lambda (b v) v)
                                          (lambda (b v) v)))

  (let ([b (box 0)]
        [b2 (box 1)])
    ;; success
    (test-tri (list #true 1)
              'unsafe-box*-cas! b 0 1
              #:pre (lambda () (set-box! b 0))
              #:post (lambda (x) (list x (unbox b)))
              #:literal-ok? #f)
    ;; failure
    (test-tri (list #false 1)
              'unsafe-box*-cas! b2 0 7
              #:pre (lambda () (set-box! b2 1))
              #:post (lambda (x) (list x (unbox b2)))
              #:literal-ok? #f))

  (let ([v (vector 0 1)])
    ;; success
    (test-tri (list #true 1)
              '(lambda (v ov nv) (unsafe-vector*-cas! v 0 ov nv)) v 0 1
              #:pre (lambda () (vector-set! v 0 0))
              #:post (lambda (x) (list x (vector-ref v 0)))
              #:literal-ok? #f)
    ;; failure
    (test-tri (list #false 1)
              '(lambda (v ov nv) (unsafe-vector*-cas! v 1 ov nv)) v 0 7
              #:pre (lambda () (vector-set! v 1 1))
              #:post (lambda (x) (list x (vector-ref v 1)))
              #:literal-ok? #f))

  (for ([star (list values (add-star "vector"))])
    (test-bin 5 (star 'unsafe-vector-ref) #(1 5 7) 1)
    (test-un 3 (star 'unsafe-vector-length) #(1 5 7))
    (let ([v (vector 0 3 7)])
      (test-tri (list (void) 5) (star 'unsafe-vector-set!) v 2 5
                #:pre (lambda () (vector-set! v 2 0))
                #:post (lambda (x) (list x (vector-ref v 2)))
                #:literal-ok? #f)))
  (test-bin 5 'unsafe-vector-ref (chaperone-vector #(1 5 7)
                                                   (lambda (v i x) x)
                                                   (lambda (v i x) x))
            1)
  (test-un 3 'unsafe-vector-length (chaperone-vector #(1 5 7)
                                                     (lambda (v i x) x)
                                                     (lambda (v i x) x)))

  (test-bin 53 'unsafe-bytes-ref #"157" 1)
  (test-un 3 'unsafe-bytes-length #"157")
  (let ([v (bytes 0 3 7)])
    (test-tri (list (void) 135) 'unsafe-bytes-set! v 2 135
              #:pre (lambda () (bytes-set! v 2 0))
              #:post (lambda (x) (list x (bytes-ref v 2)))
              #:literal-ok? #f))

  (let ([bstr (make-bytes 10)])
    (test (void) unsafe-bytes-copy! bstr 1 #"testing" 2 6)
    (test #"\0stin\0\0\0\0\0" values bstr)
    (test (void) unsafe-bytes-copy! bstr 0 #"testing")
    (test #"testing\0\0\0" values bstr))

  (test-bin #\5 'unsafe-string-ref "157" 1)
  (test-un 3 'unsafe-string-length "157")
  (let ([v (string #\0 #\3 #\7)])
    (test-tri (list (void) #\5) 'unsafe-string-set! v 2 #\5
              #:pre (lambda () (string-set! v 2 #\0))
              #:post (lambda (x) (list x (string-ref v 2)))
              #:literal-ok? #f))

  (test-bin 9.5 'unsafe-flvector-ref (flvector 1.0 9.5 18.7) 1)
  (test-un 5 'unsafe-flvector-length (flvector 1.1 2.0 3.1 4.5 5.7))
  (let ([v (flvector 1.0 9.5 18.7)])
    (test-tri (list (void) 27.4) 'unsafe-flvector-set! v 2 27.4
              #:pre (lambda () (flvector-set! v 2 0.0))
              #:post (lambda (x) (list x (flvector-ref v 2)))
              #:literal-ok? #f))

  (test-bin 9.5 'unsafe-f64vector-ref (f64vector 1.0 9.5 18.7) 1)
  (let ([v (f64vector 1.0 9.5 18.7)])
    (test-tri (list (void) 27.4) 'unsafe-f64vector-set! v 2 27.4
              #:pre (lambda () (f64vector-set! v 2 0.0))
              #:post (lambda (x) (list x (f64vector-ref v 2)))
              #:literal-ok? #f))

  (when (extflonum-available?)
    (test-bin 9.5t0 'unsafe-extflvector-ref (extflvector 1.0t0 9.5t0 18.7t0) 1)
    (test-un 5 'unsafe-extflvector-length (extflvector 1.1t0 2.0t0 3.1t0 4.5t0 5.7t0))
    (let ([v (extflvector 1.0t0 9.5t0 18.7t0)])
      (test-tri (list (void) 27.4t0) 'unsafe-extflvector-set! v 2 27.4t0
                #:pre (lambda () (extflvector-set! v 2 0.0t0))
                #:post (lambda (x) (list x (extflvector-ref v 2)))
                #:literal-ok? #f))

    (test-bin 9.5t0 'unsafe-f80vector-ref (f80vector 1.0t0 9.5t0 18.7t0) 1)
    (let ([v (f80vector 1.0t0 9.5t0 18.7t0)])
      (test-tri (list (void) 27.4t0) 'unsafe-f80vector-set! v 2 27.4t0
                #:pre (lambda () (f80vector-set! v 2 0.0t0))
                #:post (lambda (x) (list x (f80vector-ref v 2)))
                #:literal-ok? #f))
    )

  (test-bin 95 'unsafe-fxvector-ref (fxvector 10 95 187) 1)
  (test-un 5 'unsafe-fxvector-length (fxvector 11 20 31 45 57))
  (let ([v (fxvector 10 95 187)])
    (test-tri (list (void) 274) 'unsafe-fxvector-set! v 2 274
              #:pre (lambda () (fxvector-set! v 2 0))
              #:post (lambda (x) (list x (fxvector-ref v 2)))
              #:literal-ok? #f))

  (test-bin 95 'unsafe-s16vector-ref (s16vector 10 95 187) 1)
  (let ([v (s16vector 10 95 187)])
    (test-tri (list (void) 274) 'unsafe-s16vector-set! v 2 274
              #:pre (lambda () (s16vector-set! v 2 0))
              #:post (lambda (x) (list x (s16vector-ref v 2)))
              #:literal-ok? #f))
  (test-bin -32768 'unsafe-s16vector-ref (s16vector 10 -32768 187) 1)
  (test-bin 32767 'unsafe-s16vector-ref (s16vector 10 32767 187) 1)

  (test-bin 95 'unsafe-u16vector-ref (u16vector 10 95 187) 1)
  (let ([v (u16vector 10 95 187)])
    (test-tri (list (void) 274) 'unsafe-u16vector-set! v 2 274
              #:pre (lambda () (u16vector-set! v 2 0))
              #:post (lambda (x) (list x (u16vector-ref v 2)))
              #:literal-ok? #f))
  (test-bin 65535 'unsafe-u16vector-ref (u16vector 10 65535 187) 1)

  (let ()
    (define (try-struct prop prop-val)
      (define-struct posn (x [y #:mutable] z)
        #:property prop prop-val)
      (for ([star (list values (add-star "star"))])
        (test-bin 'a unsafe-struct-ref (make-posn 'a 'b 'c) 0 #:literal-ok? #f)
        (test-bin 'b unsafe-struct-ref (make-posn 'a 'b 'c) 1 #:literal-ok? #f)
        (let ([p (make-posn 100 200 300)])
          (test-tri 500 (star 'unsafe-struct-set!) p 1 500
                    #:pre (lambda () (set-posn-y! p 0))
                    #:post (lambda (x) (posn-y p))
                    #:literal-ok? #f)))
      (let ([p (chaperone-struct (make-posn 100 200 300)
                                 posn-y (lambda (p v) v)
                                 set-posn-y! (lambda (p v) v))])
        (test-tri 500 'unsafe-struct-set! p 1 500
                  #:pre (lambda () (set-posn-y! p 0))
                  #:post (lambda (x) (posn-y p))
                  #:literal-ok? #f))
      (let ([p (make-posn 100 200 300)])
        ;; success
        (test-tri (list #true 201)
                  '(lambda (p ov nv) (unsafe-struct*-cas! p 1 ov nv)) p 200 201
                  #:pre (lambda () (unsafe-struct*-set! p 1 200))
                  #:post (lambda (x) (list x (unsafe-struct*-ref p 1)))
                  #:literal-ok? #f)
        ;; failure
        (test-tri (list #false 200)
                  '(lambda (p ov nv) (unsafe-struct*-cas! p 1 ov nv)) p 199 202
                  #:pre (lambda () (unsafe-struct*-set! p 1 200))
                  #:post (lambda (x) (list x (unsafe-struct*-ref p 1)))
                  #:literal-ok? #f))
      (let ([p (make-posn 100 200 300)])
        (test-un struct:posn 'unsafe-struct*-type p #:literal-ok? #f)))
    (define-values (prop:nothing nothing? nothing-ref) (make-struct-type-property 'nothing))
    (try-struct prop:nothing 5)
    (try-struct prop:procedure (lambda (s) 'hi!)))

  ;; test unboxing:
  (test-tri 5.4 '(lambda (x y z) (unsafe-fl+ x (unsafe-f64vector-ref y z))) 1.2 (f64vector 1.0 4.2 6.7) 1)
  (test-tri 3.2 '(lambda (x y z)
                   (unsafe-f64vector-set! y 1 (unsafe-fl+ x z))
                   (unsafe-f64vector-ref y 1))
            1.2 (f64vector 1.0 4.2 6.7) 2.0)

  (when (extflonum-available?)
    (test-tri 5.3999999999999999997t0 '(lambda (x y z) (unsafe-extfl+ x (unsafe-f80vector-ref y z))) 1.2t0 (f80vector 1.0t0 4.2t0 6.7t0) 1)
    (test-tri 3.2t0 '(lambda (x y z)
                       (unsafe-f80vector-set! y 1 (unsafe-extfl+ x z))
                       (unsafe-f80vector-ref y 1))
              1.2t0 (f80vector 1.0t0 4.2t0 6.7t0) 2.0t0))

  (void))

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Interaction of unboxing, closures, etc.
(let ([f (lambda (x)
           (let ([x (unsafe-fl+ x 1.0)])
             (let loop ([v 0.0][n 10000])
               (if (zero? n)
                   v
                   (loop (unsafe-fl+ v x)
                         (- n 1))))))])
  (test 20000.0 f 1.0))
(let ([f (lambda (x)
           (let ([x (unsafe-fl+ x 1.0)])
             (let loop ([v 0.0][n 10000][q 2.0])
               (if (zero? n)
                   (unsafe-fl+ v q)
                   (loop (unsafe-fl+ v x)
                         (- n 1)
                         (unsafe-fl- 0.0 q))))))])
  (test 20002.0 f 1.0))
(let ([f (lambda (x)
           (let loop ([a 0.0][v 0.0][n 1000000])
             (if (zero? n)
                 v
                 (if (odd? n)
                     (let ([b (unsafe-fl+ a a)])
                       (loop b v (sub1 n)))
                     ;; First arg is un place, but may need re-boxing
                     (loop a
                           (unsafe-fl+ v x)
                           (- n 1))))))])
  (test 500000.0 f 1.0))

(when (extflonum-available?)
  (let ([f (lambda (x)
             (let ([x (unsafe-extfl+ x 1.0t0)])
               (let loop ([v 0.0t0][n 10000])
                 (if (zero? n)
                     v
                     (loop (unsafe-extfl+ v x)
                           (- n 1))))))])
    (test 20000.0t0 f 1.0t0))
  (let ([f (lambda (x)
             (let ([x (unsafe-extfl+ x 1.0t0)])
               (let loop ([v 0.0t0][n 10000][q 2.0t0])
                 (if (zero? n)
                     (unsafe-extfl+ v q)
                     (loop (unsafe-extfl+ v x)
                           (- n 1)
                           (unsafe-extfl- 0.0t0 q))))))])
    (test 20002.0t0 f 1.0t0))
  (let ([f (lambda (x)
             (let loop ([a 0.0t0][v 0.0t0][n 1000000])
               (if (zero? n)
                   v
                   (if (odd? n)
                       (let ([b (unsafe-extfl+ a a)])
                         (loop b v (sub1 n)))
                       ;; First arg is un place, but may need re-boxing
                       (loop a
                             (unsafe-extfl+ v x)
                             (- n 1))))))])
    (test 500000.0t0 f 1.0t0)))

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Check that compiling a misapplication of `unsafe-car' and `unsafe-cdr'
;; (which are folding operations in the compiler ) doesn't crash:

(let ([f (lambda (x) (if x x (unsafe-car 3)))]
      [g (lambda (x) (if x x (unsafe-cdr 4)))])
  (test 5 f 5)
  (test 5 g 5))

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; A regression test to check that unsafe-fl/ doesn't
;; reorder its arguments when it isn't safe to do so, where the
;; unsafeness of the reordering has to do with safe-for-space
;; clearing of a variable that is used multiple times.

(let ()
  (define weird #f)
  (set! weird
        (lambda (get-M)
          (let* ([M  (get-M)]
                 [N1 (unsafe-fl/ M (unsafe-fllog M))])
            (get-M) ; triggers safe-for-space clearing of M
            N1)))

  (test 15388.0 floor (* 1000.0 (weird (lambda () 64.0)))))

(when (extflonum-available?)
  (define weird #f)
  (set! weird
        (lambda (get-M)
          (let* ([M  (get-M)]
                 [N1 (unsafe-extfl/ M (unsafe-extfllog M))])
            (get-M) ; triggers safe-for-space clearing of M
            N1)))
  (test 15388.0t0 unsafe-extflfloor (unsafe-extfl* 1000.0t0 (weird (lambda () 64.0t0)))))

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(let ()
  (define err-msg "no element at index")

;; Check that unsafe-weak-hash-iterate- ops do not segfault
;; when a key is collected before access; throw exception instead.
;; They are used for safe iteration in in-weak-hash- sequence forms
  (for ([make-weak-hash (list make-weak-hash make-ephemeron-hash)]
        [unsafe-weak-hash-iterate-first (list unsafe-weak-hash-iterate-first unsafe-ephemeron-hash-iterate-first)]
        [unsafe-weak-hash-iterate-key (list unsafe-weak-hash-iterate-key unsafe-ephemeron-hash-iterate-key)]
        [unsafe-weak-hash-iterate-pair (list unsafe-weak-hash-iterate-pair unsafe-ephemeron-hash-iterate-pair)]
        [unsafe-weak-hash-iterate-key+value (list unsafe-weak-hash-iterate-key+value unsafe-ephemeron-hash-iterate-key+value)])
    (define ht #f)

    ;; retain the list at first...
    (define lst (build-list 10 add1))

    (set! ht (make-weak-hash `((,lst . val))))

    (define i (unsafe-weak-hash-iterate-first ht))

    ;; everything ok
    (test #t number? i)
    (test #t list? (unsafe-weak-hash-iterate-key ht i))
    (test #t equal? (unsafe-weak-hash-iterate-value ht i) 'val)
    (test #t equal? (cdr (unsafe-weak-hash-iterate-pair ht i)) 'val)
    (test #t equal?
          (call-with-values
              (lambda () (unsafe-weak-hash-iterate-key+value ht i)) cons)
          '((1 2 3 4 5 6 7 8 9 10) . val))
    (test #t boolean? (unsafe-weak-hash-iterate-next ht i))

    ;; drop `lst` on next GC
    (test #t list? lst)
    (set! lst #f)

    (unless (eq? 'cgc (system-type 'gc))
      ;; collect key, everything should error (but not segfault)
      (collect-garbage)(collect-garbage)(collect-garbage)
      (test #t boolean? (unsafe-weak-hash-iterate-first ht))
      (err/rt-test (unsafe-weak-hash-iterate-key ht i) exn:fail:contract? err-msg)
      (test 'gone unsafe-weak-hash-iterate-key ht i 'gone)
      (err/rt-test (unsafe-weak-hash-iterate-value ht i) exn:fail:contract? err-msg)
      (test 'gone unsafe-weak-hash-iterate-value ht i 'gone)
      (err/rt-test (unsafe-weak-hash-iterate-pair ht i) exn:fail:contract? err-msg)
      (test '(gone . gone) unsafe-weak-hash-iterate-pair ht i 'gone)
      (err/rt-test (unsafe-weak-hash-iterate-key+value ht i) exn:fail:contract? err-msg)
      (test-values '(gone gone) (lambda () (unsafe-weak-hash-iterate-key+value ht i 'gone)))
      (test #f unsafe-weak-hash-iterate-next ht i)))

;; Check that unsafe mutable hash table operations do not segfault
;; after getting valid index from unsafe-mutable-hash-iterate-first and -next.
;; Throw exception instead since they're used for safe iteration
  (let ()
    (define ht (make-hash '((a . b))))
    (define i (unsafe-mutable-hash-iterate-first ht))

    ;; everything ok
    (test #t number? i)
    (test #t equal? (unsafe-mutable-hash-iterate-key ht i) 'a)
    (test #t equal? (unsafe-mutable-hash-iterate-value ht i) 'b)
    (test #t equal? (unsafe-mutable-hash-iterate-pair ht i) '(a . b))
    (test #t equal?
          (call-with-values
              (lambda () (unsafe-mutable-hash-iterate-key+value ht i)) cons)
          '(a . b))
    (test #f unsafe-mutable-hash-iterate-next ht i)

    ;; remove element, everything should error (but not segfault)
    (hash-remove! ht 'a)
    (test #t boolean? (unsafe-mutable-hash-iterate-first ht))
    (err/rt-test (unsafe-mutable-hash-iterate-key ht i) exn:fail:contract? err-msg)
    (test 'gone unsafe-mutable-hash-iterate-key ht i 'gone)
    (err/rt-test (unsafe-mutable-hash-iterate-value ht i) exn:fail:contract? err-msg)
    (test 'gone unsafe-mutable-hash-iterate-value ht i 'gone)
    (err/rt-test (unsafe-mutable-hash-iterate-pair ht i) exn:fail:contract? err-msg)
    (test '(gone . gone) unsafe-mutable-hash-iterate-pair ht i 'gone)
    (err/rt-test (unsafe-mutable-hash-iterate-key+value ht i) exn:fail:contract? err-msg)
    (test-values '(gone gone) (lambda () (unsafe-mutable-hash-iterate-key+value ht i 'gone)))
    (test #f unsafe-mutable-hash-iterate-next ht i))

  (for ([make-weak-hash (list make-weak-hash make-ephemeron-hash)]
        [unsafe-weak-hash-iterate-first (list unsafe-weak-hash-iterate-first unsafe-ephemeron-hash-iterate-first)]
        [unsafe-weak-hash-iterate-key (list unsafe-weak-hash-iterate-key unsafe-ephemeron-hash-iterate-key)]
        [unsafe-weak-hash-iterate-pair (list unsafe-weak-hash-iterate-pair unsafe-ephemeron-hash-iterate-pair)]
        [unsafe-weak-hash-iterate-key+value (list unsafe-weak-hash-iterate-key+value unsafe-ephemeron-hash-iterate-key+value)])
    (define ht (make-weak-hash '((a . b))))
    (define i (unsafe-weak-hash-iterate-first ht))

    ;; everything ok
    (test #t number? i)
    (test #t equal? (unsafe-weak-hash-iterate-key ht i) 'a)
    (test #t equal? (unsafe-weak-hash-iterate-value ht i) 'b)
    (test #t equal? (unsafe-weak-hash-iterate-pair ht i) '(a . b))
    (test #t equal?
          (call-with-values
              (lambda () (unsafe-weak-hash-iterate-key+value ht i)) cons)
          '(a . b))
    (test #t boolean? (unsafe-weak-hash-iterate-next ht i))

    ;; remove element, everything should error (but not segfault)
    (hash-remove! ht 'a)
    (test #t boolean? (unsafe-weak-hash-iterate-first ht))
    (err/rt-test (unsafe-weak-hash-iterate-key ht i) exn:fail:contract? err-msg)
    (test 'gone unsafe-weak-hash-iterate-key ht i 'gone)
    (err/rt-test (unsafe-weak-hash-iterate-value ht i) exn:fail:contract? err-msg)
    (test 'gone unsafe-weak-hash-iterate-value ht i 'gone)
    (err/rt-test (unsafe-weak-hash-iterate-pair ht i) exn:fail:contract? err-msg)
    (test '(gone . gone) unsafe-weak-hash-iterate-pair ht i 'gone)
    (err/rt-test (unsafe-weak-hash-iterate-key+value ht i) exn:fail:contract? err-msg)
    (test-values '(gone gone) (lambda () (unsafe-weak-hash-iterate-key+value ht i 'gone)))
    (test #f unsafe-weak-hash-iterate-next ht i)))

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Check that `unsafe-immutable-hash-...` proplerly handles an
;; indirection created by `read`:

(test '((a . 1) (b . 2))
      sort
      (for/list (((k v) (in-immutable-hash (read (open-input-string "#hash((a . 1) (b . 2))")))))
        (cons k v))
      <
      #:key cdr)

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Check that constant folding doesn't go wrong for `unsafe-fxlshift`:

(test #t procedure? (lambda ()
                      (if (eqv? 64 (system-type 'word))
                          (unsafe-fxlshift 1 60)
                          (unsafe-fxlshift 1 28))))
(test #t procedure? (lambda ()
                      (if (eqv? 64 (system-type 'word))
                          (unsafe-fxlshift 1 61)
                          (unsafe-fxlshift 1 29))))
(test #t procedure? (lambda ()
                      (if (eqv? 64 (system-type 'word))
                          (unsafe-fxlshift 1 62)
                          (unsafe-fxlshift 1 30))))
(test #t procedure? (lambda ()
                      (if (eqv? 64 (system-type 'word))
                          (unsafe-fxlshift 1 63)
                          (unsafe-fxlshift 1 31))))

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Check that allocation by inlined `unsafe-flrandom` is ok

(test #t
      symbol?
      (let ([r (current-pseudo-random-generator)])
        (for/fold ([v #f]) ([i (in-range 1000000)])
          ;; The pattern of `if`s here is intended to check the JIT's
          ;; runstack pointer is syned for allocation
          (let* ([a (let ([v (unsafe-flrandom r)])
                      (if (negative? v)
                          (error "oops")
                          v))]
                 [b (let ([v (unsafe-flrandom r)])
                      (if (negative? v)
                          (error "oops")
                          v))]
                 [c (let ([v (unsafe-flrandom r)])
                      (if (negative? v)
                          (error "oops")
                          v))])
            (if (and (eqv? a b) (eqv? b c))
                'same
                'diff)))))

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(let ([bstr (make-bytes 5 65)]
      [str (make-string 5 #\x)]
      [vec (make-vector 5 'x)])
  (let ([bstr (unsafe-bytes->immutable-bytes! bstr)]
        [str (unsafe-string->immutable-string! str)]
        [vec (unsafe-vector*->immutable-vector! vec)])
    (test #t immutable? bstr)
    (test #t immutable? str)
    (test #t immutable? vec)
    (test #t equal? #"AAAAA" bstr)
    (test #t equal? "xxxxx" str)
    (test #t equal? '#(x x x x x) vec)
    (test #t immutable? (unsafe-bytes->immutable-bytes! (make-bytes 0)))
    (test #f immutable? (make-bytes 0))
    (test #t immutable? (unsafe-string->immutable-string! (make-string 0)))
    (test #f immutable? (make-string 0))
    (test #t immutable? (unsafe-string->immutable-string! (string-append)))
    (test #f immutable? (string-append))
    (test #t immutable? (unsafe-vector*->immutable-vector! (make-vector 0)))
    (test #f immutable? (make-vector 0))))

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Make sure `bitwise-{and,ior,xor}` are not converted to
;; unsafe fixnum operations in `#:unsafe` mode

(module unsafe-but-not-restricted-to-fixnum racket/base
  (#%declare #:unsafe)
  (provide band bior bxor)
  (define (band x)
    (bitwise-and #xFF x))
  (define (bior x)
    (bitwise-ior #xFF x))
  (define (bxor x)
    (bitwise-xor #xFF x)))

(require 'unsafe-but-not-restricted-to-fixnum)
(test #x55 band (+ #x5555 (expt 2 100)))
(test (+ (expt 2 100) #x55FF) bior (+ #x5555 (expt 2 100)))
(test (+ (expt 2 100) #x55AA) bxor (+ #x5555 (expt 2 100)))

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-syntax-rule (module-claiming-unreachable-part name flag ...)
  (module name racket/base
    (require racket/unreachable)
    (provide f1 f2)
    (#%declare flag ...)
    (struct s (a) #:authentic)
    (define (f1 x)
      (if (s? x)
          (s-a x)
          (assert-unreachable)))
    (define (f2 x)
      (if (s? x)
          (s-a x)
          (with-assert-unreachable
            (raise-argument-error 'f2 "oops" x))))))

(module-claiming-unreachable-part claims-unreachable-parts/safe)
(module-claiming-unreachable-part claims-unreachable-parts/unsafe #:unsafe)

(err/rt-test ((dynamic-require ''claims-unreachable-parts/safe 'f1) (arity-at-least 7)))
(err/rt-test ((dynamic-require ''claims-unreachable-parts/safe 'f2) (arity-at-least 7)))

(when (eq? 'chez-scheme (system-type 'vm))
  (test 7 (dynamic-require ''claims-unreachable-parts/unsafe 'f1) (arity-at-least 7))
  (test 7 (dynamic-require ''claims-unreachable-parts/unsafe 'f2) (arity-at-least 7)))
  
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(report-errs)
