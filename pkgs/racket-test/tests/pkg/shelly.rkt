#lang racket/base
(require rackunit
         racket/port
         racket/system
         racket/match
         compiler/find-exe
         syntax/parse/define
         (for-syntax racket/base
                     syntax/parse))


;; {{ Shelly
;; This macro is intended to make Eli proud.

;; Do we print a lot of output?
(define verbose? (make-parameter #t))
(provide verbose?)

;; Wow, RackUnit really sucks that test-begin/case don't work inside
;; each other like this already. We Want's RackUnit's detailed printing
;; of test failure, but not it's throw-away-the-exception behavior:
(define-syntax-rule (exception-if-failed form sub ...)
  (let ([done? #f])
    (form sub ... (set! done? #t))
    (unless done? (really-abort))))
(define (really-abort)
  ;; Here's how we avoid RackUnit's exception capture:
  (abort-current-continuation (default-continuation-prompt-tag) void))
(define-syntax-rule (check-begin e ...)
  (exception-if-failed test-begin e ...))
(define-syntax-rule (check-case m e ...)
  (exception-if-failed test-case m e ...))

(define-syntax-parse-rule (check-similar? act exp name)
  #:with check-regexp-stx (syntax/loc (syntax exp) (check-regexp-match exp-v act-v name))
  #:with check-equal-stx  (syntax/loc (syntax exp) (check-equal? act-v exp-v name))
  (let ()
    (define exp-v exp)
    (define act-v act)
    (if (regexp? exp-v)
      check-regexp-stx
      check-equal-stx)))

(define (exn:input-port-closed? x)
  (and (exn:fail? x)
       (regexp-match #rx"input port is closed" (exn-message x))))

(begin-for-syntax
  (define-splicing-syntax-class shelly-case
    #:attributes (code)
    (pattern (~seq (~datum $) command-line:expr
                   (~optional (~seq (~datum =exit>) exit-cond:expr)
                              #:defaults ([exit-cond #'0]))
                   (~optional (~seq (~datum =stdout>) output-str:expr)
                              #:defaults ([output-str #'#f]))
                   (~optional (~seq (~datum =stderr>) error-str:expr)
                              #:defaults ([error-str #'#f]))
                   (~optional (~seq (~datum <input=) input-str:expr)
                              #:defaults ([input-str #'#f])))
             #:attr
             code
             (quasisyntax/loc
               #'command-line
               (let ([cmd (rename-racket command-line)])
                 (check-case
                  cmd
                  (define output-port (open-output-string))
                  (define error-port (open-output-string))
                  (when (verbose?)
                    (printf "$ ~a\n" cmd))
                  (match-define
                   (list stdout stdin pid stderr to-proc)
                   (process/ports #f
                                  (and input-str 
                                       (open-input-string input-str))
                                  #f
                                  cmd))
                  (define stdout-t
                    (thread 
                     (λ ()
                         (with-handlers ([exn:input-port-closed? void])
                           (if (verbose?)
                               (copy-port stdout output-port
                                          (current-output-port))
                               (copy-port stdout output-port))))))
                  (define stderr-t
                    (thread
                     (λ ()
                         (with-handlers ([exn:input-port-closed? void])
                           (define cop (current-output-port))
                           (let loop ()
                             (define l (read-bytes-line stderr))
                             (unless (eof-object? l)
                               (displayln l error-port)
                               (when (verbose?)
                                 (displayln (format "STDERR: ~a" l) cop)
                                 (flush-output cop))
                               (flush-output error-port)
                               (loop)))))))
                  (to-proc 'wait)
                  (define cmd-status (to-proc 'exit-code))
                  (when stdin (close-output-port stdin))
                  (thread-wait stdout-t)
                  (thread-wait stderr-t)
                  (when stdout (close-input-port stdout))
                  (when stderr (close-input-port stderr))
                  (define actual-output
                    (get-output-string output-port))
                  (define actual-error
                    (get-output-string error-port))
                  #,(syntax/loc #'command-line
                      (when output-str
                        (check-similar? actual-output output-str "stdout")))
                  #,(syntax/loc #'command-line
                      (when error-str
                        (check-similar? actual-error error-str "stderr")))
                  #,(syntax/loc #'command-line
                      (check-equal? cmd-status exit-cond "exit code"))))))
    (pattern (~and (~not (~datum $))
                   code:expr))))

(define-syntax (shelly-begin stx)
  (syntax-parse
      stx
    [(_ case:shelly-case ...)
     (syntax/loc stx (test-begin case.code ...))]))
(define-syntax (shelly-case stx)
  (syntax-parse
      stx
    [(_ m:expr case:shelly-case ...)
     (syntax/loc stx
       (let ()
         (define mv m)
         (check-case mv
                     (when (verbose?) (printf "# Starting... ~a\n" mv))
                     case.code ...
                     (when (verbose?) (printf "# Ending... ~a\n" mv)))))]))
(define-syntax (shelly-wind stx)
  (syntax-parse
      stx
    [(_ e:expr ... ((~datum finally) after:expr ...))
     (syntax/loc stx
       (dynamic-wind
           void
           (λ ()
             (shelly-begin e ...))
           (λ ()
             (shelly-begin after ...))))]))
;; }}

(define racket-run-suffix
  (let ()
    (define racket (find-exe))
    (cond
      [racket
       (define-values (base name dir?) (split-path racket))
       (define m (regexp-match #rx"^(?i:racket)(.*)$" (path-element->string name)))
       (define suffix (and m (cadr m)))
       (and (not (equal? suffix ""))
            suffix)]
      [else #f])))
      
;; Add a suffix ro "racket" or "raco", if there's one on the current executable
(define rename-racket
  (cond
    [racket-run-suffix
     ;; Adjust comands by adding a suffix:
     (lambda (cmd)
       (cond
         [(regexp-match-positions #rx"^(racket|raco) " cmd)
          => (lambda (m)
               (string-append (substring cmd 0 (cdadr m))
                              racket-run-suffix
                              (substring cmd (cdadr m))))]
         [else cmd]))]
    [else
     (lambda (cmd) cmd)]))

(provide (all-defined-out))
