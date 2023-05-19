#lang racket
(require racket/syntax
         syntax/stx
         rackunit)

;; Tests for most of racket/syntax
;; Missing tests for
;;  - generate-temporary
;;  - internal-definition-context-apply

(check free-identifier=?
       (format-id #'here "~a?" 'null)
       #'null?)

(check bound-identifier=?
       (format-id #'here "ab~a" #'c)
       #'abc)

(let ([abc 0])
  (check bound-identifier=?
         (format-id #'here "ab~a" #'c)
        #'abc))

(check free-identifier=?
       (format-id #'here "sub~a" 1)
       #'sub1)

(check free-identifier=?
       (format-id #'here "sub~a" #'1)
       #'sub1)

(check-equal? (format-symbol "~a?" 'null) 'null?)
(check-equal? (format-symbol "~a?" "null") 'null?)
(check-equal? (format-symbol "sub~a" 1) 'sub1)
(check-equal? (format-symbol "sub~a" #'1) 'sub1)

(check-exn
 exn:fail:contract?
 (lambda ()
   (format-id 'here "wrong--first-arg-is-not-syntax")))

(check free-identifier=?
       (format-id #f "cb~a" #'a)
       #'cba)

;; ----

(check-equal? (syntax->datum
               (let ()
                 (define/with-syntax p #'(1 2 3))
                 #'(0 p)))
              '(0 (1 2 3)))
(check-equal? (syntax->datum
               (let ()
                 (define/with-syntax (n ...) #'(1 2 3))
                 #'(0 n ...)))
              '(0 1 2 3))
(check-equal? (syntax->datum
               (let ()
                 (define/with-syntax (0 (m n ...) ...) #'(0 (1 2) (3 4 5) (6)))
                 #'(0 m ... (n ... $) ...)))
              '(0 1 3 6 (2 $) (4 5 $) ($)))

;; ----

(let* ([stx
        ;; would like to check that stx in exn is same as arg to wrong-syntax,
        ;; but raise-syntax-error arms stx args to protect macros...
        ;; so add recognizable properties and check those instead
        (with-syntax ([two (syntax-property #'2 'tag "two")]
                      [three (syntax-property #'3 'tag "three")])
          #'(foo 1 three two))]
       [stxlist (syntax->list stx)])
  (check-exn (lambda (e)
               (and (exn:fail:syntax? e)
                    (regexp-match? #rx"foo: should be" (exn-message e))
                    (let ([exprs (exn:fail:syntax-exprs e)])
                      (and (= (length exprs) 1)
                           (equal? (syntax-property (car exprs) 'tag) "two")))))
             (lambda ()
               (parameterize ((current-syntax-context stx))
                 (wrong-syntax (fourth stxlist) "should be bigger than ~s" (third stxlist))))))

;; ----

;; Test for recording disappeared uses
;; In particular, test that "originalness" is preserved, so that Check Syntax works.

(let ([ns (make-base-namespace)])
  (parameterize ((current-namespace ns))
    (eval '(require (for-syntax racket/base racket/syntax)))
    (eval '(define-syntax (m stx)
             (with-disappeared-uses
              (syntax-case stx (id)
                [(_ id1 id2 e)
                 (begin
                   (record-disappeared-uses (list #'id1))
                   (syntax-local-value/record #'id2 (lambda (x) #t))
                   #'(add1 e))]))))
    (let* ([stx
            ;; want syntax to have internal "original" property
            (namespace-syntax-introduce
             (read-syntax 'src (open-input-string "(m a define +)")))]
           [ee (expand stx)])
      (define (shallow-has-it? x sym)
        (let ([ds (if (syntax? x) (syntax-property x 'disappeared-use) null)])
          (let loop ([ds ds])
            (cond [(and (identifier? ds) (eq? (syntax-e ds) sym))
                   (syntax-original? ds)]
                  [(pair? ds)
                   (or (loop (car ds)) (loop (cdr ds)))]
                  [else #f]))))
      (define (has-it? x sym)
        (let loop ([ee ee])
          (or (shallow-has-it? ee sym)
              (and (stx-pair? ee)
                   (or (loop (stx-car ee))
                       (loop (stx-cdr ee)))))))
      (check-true (and (syntax-original? stx)
                       (andmap syntax-original? (syntax->list stx))))
      (check-true (has-it? ee 'a))
      (check-true (has-it? ee 'define)))))

;; ----

(check-equal? (with-syntax* ([x #'1] [x #'x]) (syntax->datum #'x))
              '1)

(check-equal? (with-syntax* ([x #'1] [y #'x]) (syntax->datum #'y))
              '1)

;; ----

(require (for-syntax racket/syntax))

; syntax-local-eval
(let ()
  (define-syntax x '5)
  (define-syntax (m stx)
    (define ctx1 (syntax-local-make-definition-context))
    (syntax-local-bind-syntaxes
      (list #'y)
      #''6
      ctx1)

    (define ctx2 (syntax-local-make-definition-context))
    (syntax-local-bind-syntaxes
      (list #'z)
      #''7
      ctx2)

    #`(list
       ; single intdef case
       '#,(syntax-local-eval #'(map syntax-local-value (list #'x #'y))
                             ctx1)
       ; #f case
       '#,(syntax-local-eval #'(list 1 2)
                             #f)
       ; #f case as default
       '#,(syntax-local-eval #'(list 1 2))
       ; list of intdefs case
       '#,(syntax-local-eval #'(map syntax-local-value (list #'y #'z))
                             (list ctx1 ctx2))))
  (check-equal?
    (m)
    '((5 6) (1 2) (1 2) (6 7))))

