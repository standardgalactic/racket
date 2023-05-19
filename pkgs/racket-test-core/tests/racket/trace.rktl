(load-relative "loadtest.rktl")

(Section 'trace)

(require racket/trace)

(define-syntax-rule (trace-output expr ...)
  (let ([out '()])
    (parameterize ([current-trace-notify
                    (lambda (e) (set! out (cons e out)))])
      expr ...
      (reverse out))))

(let ([n1 (let ([out '()])
            (parameterize ([current-trace-notify
                            (lambda (e) (set! out (cons e out)))])
              (define (foo x) x)
              (trace foo)
              (foo 2)
              out))])
  (test (reverse n1) 'test-it (list ">(foo 2)" "<2")))

(test (trace-output
        (define (foo x) x)
        (trace foo)
        (foo 2))
      'simple-trace
      (list ">(foo 2)"
            "<2"))

(test (trace-output
        (define (foo x) (add1 x))
        (trace foo)
        (foo 2))
      'simple-trace
      (list ">(foo 2)"
            "<3"))

(test (trace-output
        (define (a x) x)
        (define (b x) (a x))
        (define (c x) (+ (b x) (b x)))
        (trace a b c)
        (c 1))
      'trace2
      (list ">(c 1)"
            "> (b 1)"
            "> (a 1)"
            "< 1"
            "> (b 1)"
            "> (a 1)"
            "< 1"
            "<2"))

(test (trace-output
       (define (f x #:q w) (list x 1))
       (trace f)
       (f #:q (box 18) '(1 2 3)))
      'trace-quotes
      (list ">(f '(1 2 3) #:q '#&18)"
            "<'((1 2 3) 1)"))

(parameterize ([print-as-expression #f])
  (test (trace-output
         (define (f x #:q w) (list x 1))
         (trace f)
         (f #:q (box 18) '(1 2 3)))
        'trace-quotes
        (list ">(f (1 2 3) #:q #&18)"
              "<((1 2 3) 1)")))

(test
  (list ">(verbose-fact 2)"
        "> (verbose-fact 1)"
        "> >(verbose-fact 0)"
        "< <1"
        "> >(verbose-fact 0)"
        "< <1"
        "< 1"
        "> (verbose-fact 1)"
        "> >(verbose-fact 0)"
        "< <1"
        "> >(verbose-fact 0)"
        "< <1"
        "< 1"
        "<2")
  'trace-define
  (trace-output
    (trace-define (verbose-fact x)
      (if (zero? x)
        (begin (displayln 1) 1)
        (begin (displayln (* x (verbose-fact (sub1 x))))
               (* x (verbose-fact (sub1 x))))))
    (parameterize ([current-output-port (open-output-nowhere)]) (verbose-fact 2))))

(test
  (list ">(plus1 2)"
        "<3")
  'trace-define-in-definition-only-context
   (trace-output
     (define (f x)
       (local-require racket/local)
       (local [(trace-define (plus1 x) (add1 x))]
         (plus1 x)))
         (parameterize ([current-output-port (open-output-nowhere)])
           (f 2))))

(test
  (list ">(fact 120)"
        "<120")
  'trace-lambda-named
  (trace-output
    ((trace-lambda #:name fact (x) x) 120)))

(let ([tout (trace-output ((trace-lambda (x) x) 120))])
  (local-require racket/match)
  (test #t
        'trace-lambda-anonymous
        (match tout
          [(list (pregexp #px">\\(.+\\.rktl?:\\d+:\\d+[|]? 120\\)") "<120") #t]
          [_ #f])))

(let* ([file-name (lambda (x)
                   (last (string-split
                         (car (string-split x ":"))
                         "/")))]
      [proc-file-name (compose file-name symbol->string object-name)])
  (local-require syntax/location)
  (let ([current-file-name (file-name (quote-source-file))]
         [f1 (trace-lambda (x) x)])
    (trace-define f2 (lambda (x) x))
    (test current-file-name
          'trace-lambda-source
          (proc-file-name f1))
    (test current-file-name
          'trace-lambda-source
          (proc-file-name f2))
    (trace-let f3 ([x 1])
      (test current-file-name
            'trace-lambda-source
            (proc-file-name f3)))))

(module sub racket/base
  (provide some-id)
  (define (some-id) 1))

(define (some-id*) 1)

(let ()
  (syntax-test #'(trace add1))
  (syntax-test #'(let ()
                   (local-require 'sub)
                   (trace some-id)))

  (trace some-id*)

  (define (some-id**) 1)
  (trace some-id**))

(report-errs)
