
(load-relative "loadtest.rktl")

(Section 'string)

(require racket/string
         (submod racket/string private))

;; ---------- real->decimal-string ----------
(test "0." real->decimal-string 0 0)
(test "0." real->decimal-string 0.0 0)
(test "1." real->decimal-string 0.6 0)
(test "1." real->decimal-string 3/4 0)
(test "1." real->decimal-string 1.2 0)
(test "-0." real->decimal-string -0.0 0) ; note this!
(test "-0.00" real->decimal-string -0.0) ; same here...
(test "-1." real->decimal-string -0.6 0)
(test "-1." real->decimal-string -3/4 0)
(test "-1." real->decimal-string -1.2 0)
(test "1.20" real->decimal-string 1.2)
(test "-1.20" real->decimal-string -1.2)
(test "1.00" real->decimal-string 0.99999999999)
(test "-1.00" real->decimal-string -0.99999999999)
(test "1999999999999999859514578049071102439861518336.00"
      real->decimal-string 2e45)

;; ---------- regexp-quote ----------
(let ([s (list->string
          (let loop ([i 0])
            (if (= i 256)
              null
              (cons (integer->char i) (loop (add1 i))))))])
  (test (list s) regexp-match (regexp-quote s) s)
  (test (string-append "!" s "!")
        regexp-replace
        (regexp-quote s) s (regexp-replace-quote (string-append "!" s "!"))))

;; ---------- regexp-<?>* functions ----------
(let ()
  (define (->b x)
    (cond [(list? x) (map ->b x)]
          [(string? x) (string->bytes/utf-8 x)]
          [(pregexp? x) (byte-pregexp (->b (object-name x)))]
          [else x]))
  (define funs '())
  (define (test-funs ks vs res left rx str . args)
    (unless (memq regexp-match-peek-positions* funs)
      (for ([fun (in-list funs)])
        ;; test with a string
        (keyword-apply test ks vs res fun rx str args)
        ;; test with a byte-regexp and/or a byte string
        (keyword-apply test ks vs (->b res) fun (->b rx) str args)
        (keyword-apply test ks vs (->b res) fun rx (->b str) args)
        (keyword-apply test ks vs (->b res) fun (->b rx) (->b str) args)))
    (for ([fun (in-list funs)])
      ;; test with a port, and test leftovers
      (when left
        (let ([p (open-input-string str)])
          (keyword-apply test ks vs (->b res) fun rx p args)
          (keyword-apply test '() '() left read-string 50 p '())))))
  (define t
    (make-keyword-procedure
     test-funs
     (case-lambda [(fun*) (set! funs (if (list? fun*) fun* (list fun*)))]
                  [(res left rx str . args)
                   (apply test-funs '() '() res left rx str args)])))
  ;; --------------------
  (t regexp-match*)
  (t '("a" "b" "c") eof "[abc]" " a b c ")
  (t '("b" "c") eof     "[abc]" " a b c " 2)
  (t '("b" "c") eof     "[abc]" " a b c " 3)
  (t '("a") " b c "     "[abc]" " a b c " 0 2)
  (t '("a") "b c "      "[abc]" " a b c " 0 3)
  (t '("a" "b" "c") eof "[abc]" " a b c " 0 #f)
  (t '("a" "b" "c") eof "[abc]" " a b c " 0 7)
  (t '("a" "b" "c") eof "[abc]" "a b c")
  (t '("b" "c") eof     "[abc]" "a b c" 1)
  (t '("b" "c") eof     "[abc]" "a b c" 2)
  (t '("a") " b c"      "[abc]" "a b c" 0 1)
  (t '("a") "b c"       "[abc]" "a b c" 0 2)
  (t '("a" "b" "c") eof "[abc]" "a b c" 0)
  (t '("a" "b" "c") eof "[abc]" "a b c" 0 #f)
  (t '("a" "b" "c") eof "[abc]" "a b c" 0 5)
  (t '("a") eof         "^."    "a b c" 0 5 #"")
  (t '() eof            "^."    "a b c" 0 5 #"x")
  (t '("a\n" "b\n" "c\n") eof   "(?m:^.\n)" "a\nb\nc\n" 0 6)
  (t '("b\n" "c\n") eof         "(?m:^.\n)" "a\nb\nc\n" 0 6 #"x")
  (for ([cvt (in-list (list values byte-regexp byte-pregexp))])
    (test '(#"\x80" #"\x80") regexp-match* (cvt #"\x80") #"a\x80z\x80q"))
  ;; --------------------
  (define (regexp-explode . xs) (apply regexp-match* #:gap-select? #t xs))
  (t regexp-explode)
  (t '(" " "a" " " "b" " " "c" " ")  eof  "[abc]" " a b c ")
  (t '("" "a" "+" "b" " = " "c" " ") eof  "[abc]" "a+b = c ")
  (t '(" " "b" " " "c" " ") eof           "[abc]" " a b c " 2)
  (t '("" "b" " " "c" " ") eof            "[abc]" " a b c " 3)
  (t '(" " "a" "") " b c "                "[abc]" " a b c " 0 2)
  (t '(" " "a" " ") "b c "                "[abc]" " a b c " 0 3)
  (t '(" " "a" " " "b" " " "c" " ") eof   "[abc]" " a b c " 0 #f)
  (t '(" " "a" " " "b" " " "c" " ") eof   "[abc]" " a b c " 0 7)
  (t '("" "a" " " "b" " " "c" "") eof     "[abc]" "a b c")
  (t '(" " "b" " " "c" "") eof            "[abc]" "a b c" 1)
  (t '("" "b" " " "c" "") eof             "[abc]" "a b c" 2)
  (t '("" "a" "") " b c"                  "[abc]" "a b c" 0 1)
  (t '("" "a" " ") "b c"                  "[abc]" "a b c" 0 2)
  (t '("" "a" " " "b" " " "c" "") eof     "[abc]" "a b c" 0)
  (t '("" "a" " " "b" " " "c" "") eof     "[abc]" "a b c" 0 #f)
  (t '("" "a" " " "b" " " "c" "") eof     "[abc]" "a b c" 0 5)
  (t '("" "a" " b c") eof                 "^."    "a b c" 0 5 #"")
  (t '("a b c") eof                       "^."    "a b c" 0 5 #"x")
  (t '("" "a\n" "" "b\n" "" "c\n" "") eof "(?m:^.\n)" "a\nb\nc\n" 0 6)
  (t '("a\n" "b\n" "" "c\n" "") eof       "(?m:^.\n)" "a\nb\nc\n" 0 6 #"x")
  (for ([cvt (in-list (list values byte-regexp byte-pregexp))])
    (test '(#"a" #"\x80" #"z" #"\x80" #"q")
          regexp-explode (cvt #"\x80") #"a\x80z\x80q"))
  ;; --------------------
  (t regexp-match*) ; some tests with a match-select etc
  ;; (tests with #f for #:match-select and #t for #:gap-select? done below with
  ;; `regexp-split')
  (err/rt-test (regexp-match* "[abc]" "a b c"
                              #:match-select #f #:gap-select? #f))
  (t '("a" "b" "c") eof
     "<([abc])>" "<a> <b> <c>" #:match-select cadr)
  (t '(("a") ("b") ("c")) eof
     "<([abc])>" "<a> <b> <c>" #:match-select cdr)
  (t '(("<a>" "a") ("<b>" "b") ("<c>" "c")) eof
     "<([abc])>" "<a> <b> <c>" #:match-select values)
  (t '("" "a" " + " "b" " = " "c" "") eof
     "<([abc])>" "<a> + <b> = <c>" #:match-select cadr #:gap-select? #t)
  (t '("" ("<a>" "a") " + " ("<b>" "b") " = " ("<c>" "c") "") eof
     "<([abc])>" "<a> + <b> = <c>" #:match-select values #:gap-select? #t)
  (t '("" ("<a" "a" #f) " + " ("<b" "b" #f) " = " ("<c" "c" #f) "") eof
     "<([abc])(>)?" "<a + <b = <c" #:match-select values #:gap-select? #t)
  ;; --------------------
  (t (list regexp-match-positions*
           ;; also try the generic path
           (lambda xs (apply regexp-match-positions* xs
                             #:match-select (lambda (x) (car x))))
           ;; and try it with a list result too
           (lambda xs
             (map car (apply regexp-match-positions* xs
                             #:match-select values)))))
  (t '((1 . 2) (3 . 4) (5 . 6)) eof "[abc]" " a b c ")
  (t '((3 . 4) (5 . 6)) eof         "[abc]" " a b c " 2)
  (t '((3 . 4) (5 . 6)) eof         "[abc]" " a b c " 3)
  (t '((1 . 2)) " b c "             "[abc]" " a b c " 0 2)
  (t '((1 . 2)) "b c "              "[abc]" " a b c " 0 3)
  (t '((1 . 2) (3 . 4) (5 . 6)) eof "[abc]" " a b c " 0 #f)
  (t '((1 . 2) (3 . 4) (5 . 6)) eof "[abc]" " a b c " 0 7)
  (t '((0 . 1) (2 . 3) (4 . 5)) eof "[abc]" "a b c")
  (t '((2 . 3) (4 . 5)) eof     "[abc]" "a b c" 1)
  (t '((2 . 3) (4 . 5)) eof     "[abc]" "a b c" 2)
  (t '((0 . 1)) " b c"      "[abc]" "a b c" 0 1)
  (t '((0 . 1)) "b c"       "[abc]" "a b c" 0 2)
  (t '((0 . 1) (2 . 3) (4 . 5)) eof "[abc]" "a b c" 0)
  (t '((0 . 1) (2 . 3) (4 . 5)) eof "[abc]" "a b c" 0 #f)
  (t '((0 . 1) (2 . 3) (4 . 5)) eof "[abc]" "a b c" 0 5)
  (t '((0 . 1))                 eof "^."    "a b c" 0 5 #"")
  (t '()                        eof "^."    "a b c" 0 5 #"x")
  (t '((0 . 2) (2 . 4) (4 . 6)) eof "(?m:^.\n)" "a\nb\nc\n" 0 6)
  (t '((2 . 4) (4 . 6))         eof "(?m:^.\n)" "a\nb\nc\n" 0 6 #"x")
  (t '((0 . 2) (5 . 7) (10 . 12)) eof "<([abc])(>)?" "<a + <b = <c")
  (for ([cvt (in-list (list values byte-regexp byte-pregexp))])
    (test '((1 . 2) (3 . 4))
          regexp-match-positions* (cvt #"\x80") #"a\x80z\x80q"))
  ;; --------------------
  (t (list regexp-match-peek-positions*
           ;; also try the generic path
           (lambda xs (apply regexp-match-peek-positions* xs
                             #:match-select (lambda (x) (car x))))
           ;; and try it with a list result too
           (lambda xs
             (map (lambda (x) (and (= 1 (length x)) (car x)))
                  (apply regexp-match-peek-positions* xs
                         #:match-select values)))))
  (err/rt-test (regexp-match-peek-positions* "[abc]" "a b c"))
  (t '((1 . 2) (3 . 4) (5 . 6)) " a b c " "[abc]" " a b c ")
  (t '((3 . 4) (5 . 6))         " a b c " "[abc]" " a b c " 2)
  (t '((3 . 4) (5 . 6))         " a b c " "[abc]" " a b c " 3)
  (t '((1 . 2))                 " a b c " "[abc]" " a b c " 0 2)
  (t '((1 . 2))                 " a b c " "[abc]" " a b c " 0 3)
  (t '((1 . 2) (3 . 4) (5 . 6)) " a b c " "[abc]" " a b c " 0 #f)
  (t '((1 . 2) (3 . 4) (5 . 6)) " a b c " "[abc]" " a b c " 0 7)
  (t '((0 . 1) (2 . 3) (4 . 5)) "a b c" "[abc]" "a b c")
  (t '((2 . 3) (4 . 5))         "a b c" "[abc]" "a b c" 1)
  (t '((2 . 3) (4 . 5))         "a b c" "[abc]" "a b c" 2)
  (t '((0 . 1))                 "a b c" "[abc]" "a b c" 0 1)
  (t '((0 . 1))                 "a b c" "[abc]" "a b c" 0 2)
  (t '((0 . 1) (2 . 3) (4 . 5)) "a b c" "[abc]" "a b c" 0 #f)
  (t '((0 . 1) (2 . 3) (4 . 5)) "a b c" "[abc]" "a b c" 0 5)
  (t '((0 . 1))                 "a b c" "^."    "a b c" 0 5 #"")
  (t '()                        "a b c" "^."    "a b c" 0 5 #"x")
  (t '((0 . 2) (2 . 4) (4 . 6)) "a\nb\nc\n" "(?m:^.\n)" "a\nb\nc\n" 0 6)
  (t '((2 . 4) (4 . 6))         "a\nb\nc\n" "(?m:^.\n)" "a\nb\nc\n" 0 6 #"x")
  ;; --------------------
  (t (list regexp-split
           ;; also via an equivalent `regexp-match*' configuration
           (lambda xs
             (apply regexp-match* xs #:match-select #f #:gap-select? #t))))
  (t '("1" "2" "3" "4") eof "[abc]" "1a2b3c4")
  (t '("2" "3" "4") eof     "[abc]" "1a2b3c4" 2)
  (t '("" "3" "4") eof      "[abc]" "1a2b3c4" 3)
  (t '("1" "") "2b3c4"      "[abc]" "1a2b3c4" 0 2)
  (t '("1" "2") "b3c4"      "[abc]" "1a2b3c4" 0 3)
  (t '("1" "2" "3" "4") eof "[abc]" "1a2b3c4" 0 #f)
  (t '("1" "2" "3" "4") eof "[abc]" "1a2b3c4" 0 7)
  (t '("" "1" "2" "") eof   "[abc]" "a1b2c")
  (t '("1" "2" "") eof      "[abc]" "a1b2c" 1)
  (t '("" "2" "") eof       "[abc]" "a1b2c" 2)
  (t '("" "") "1b2c"        "[abc]" "a1b2c" 0 1)
  (t '("" "1") "b2c"        "[abc]" "a1b2c" 0 2)
  (t '("" "1" "2" "") eof   "[abc]" "a1b2c" 0)
  (t '("" "1" "2" "") eof   "[abc]" "a1b2c" 0 #f)
  (t '("" "1" "2" "") eof   "[abc]" "a1b2c" 0 5)
  (t '("" " b c")     eof   "^."    "a b c" 0 5 #"")
  (t '("a b c")       eof   "^."    "a b c" 0 5 #"x")
  (t '("" "" "" "")   eof "(?m:^.\n)" "a\nb\nc\n" 0 6)
  (t '("a\n" "" "")   eof "(?m:^.\n)" "a\nb\nc\n" 0 6 #"x")
  (for ([cvt (in-list (list values byte-regexp byte-pregexp))])
    (test '(#"" #"a" #"z" #"q" #"")
          regexp-split (cvt #"\x80") #"\x80a\x80z\x80q\x80"))
  ;; ---------- tests with zero-length matches ----------
  ;; Many of these tests can be repeated with Perl.  To try something in Perl,
  ;; put this code in a file:
  ;;   #!/usr/bin/perl
  ;;   sub test {
  ;;     my ($rx,$str) = @_; @words = split /$rx/, $str;
  ;;     print "(t '(";
  ;;     while (@words) {print '"'.shift(@words).'"'.(@words?" ":"");}
  ;;     print ") eof \"$rx\" \"$str\")\n";
  ;;   };
  ;;   test("[abc]","1a2b3");
  ;; and it will print a test that does what perl is doing.  Tests that differ
  ;; from Perl have explanations.
  ;;
  (t regexp-split)
  ;; test("a","a");
  ;; (t '() eof "a" "a")
  ;;   perl returns an empty list, we return '("" ""), and this is a difference
  ;;   that is unrelated to dealing with empty matches, just the way that
  ;;   perl's split throws out some empty matches (it throws empty matches at
  ;;   the end (but not at the beginning for some reason...))
  (t '("" "") eof "a" "a")
  ;; test("3","123");
  ;; (t '("12") eof "3" "123")
  ;;   a more straightforward demonstration of this
  (t '("12" "") eof "3" "123")
  ;; test("a","1a2a3");
  (t '("1" "2" "3") eof "a" "1a2a3")
  ;; test("","123");
  (t '("" "1" "2" "3" "") eof "" "123")
  ;; test("","12 34");
  (t '("" "1" "2" " " "3" "4" "") eof "" "12 34")
  ;; test(" *","123");
  (t '("" "1" "2" "3" "") eof " *" "123")
  ;; test(" *","12 34");
  (t '("" "1" "2" "" "3" "4" "") eof " *" "12 34")
  ;; test(" *"," 12 34 ");
  (t '("" "" "1" "2" "" "3" "4" "" "") eof " *" " 12 34 ")
  ;; test("2|", "1234");
  (t '("" "1" "" "3" "4" "") eof "2|" "1234")
  ;; test("1|", "1234");
  (t '("" "" "2" "3" "4" "") eof "1|" "1234")
  ;; test("4|", "1234");
  ;; (t '("1" "2" "3") eof "4|" "1234")
  ;;   perl perl drops the last empty string again
  (t '("" "1" "2" "3" "" "") eof "4|" "1234")
  ;; test("|2", "1234");
  (t '("" "1" "" "" "3" "4" "") eof "|2" "1234")
  ;; test("2|3", "1234");
  (t '("1" "" "4") eof "2|3" "1234")
  ;; test("2|3|4", "12345");
  (t '("1" "" "" "5") eof "2|3|4" "12345")
  ;; test("1|2", "1234");
  (t '("" "" "34") eof "1|2" "1234")
  ;; test("3|4", "1234");
  ;; (t '("12") eof "3|4" "1234")
  ;;   perl perl drops the last empty string again -- even two here
  (t '("12" "" "") eof "3|4" "1234")
  ;; test("2|3|4", "1234");
  ;; (t '("1") eof "2|3|4" "1234")
  ;;   ...and even three in this example
  (t '("1" "" "" "") eof "2|3|4" "1234")
  ;; test('$',"123");
  (t '("123" "") eof "$" "123")
  ;; test('^',"123");
  (t '("" "123") eof "^" "123")
  ;; test('^',"123\n456");
  (t '("" "123\n" "456") eof "(?m:^)" "123\n456")
  ;; test("\\b", "123 456");
  (t '("" "123" " " "456" "") eof #px"\\b" "123 456")
  ;; test("^|a", "abc");
  (t '("" "" "bc") eof "^|a" "abc")
  ;; some tests with bounds (these have no perl equivalences)
  (t '("" "1" "2" " " "3" "4" "") eof "" "12 34" 0)
  (t '("" "1" "2" " " "3" "4" "") eof "" "12 34" 0 #f)
  (t '("" "1" "2" " " "3" "4" "") eof "" "12 34" 0 5)
  (t '("" "" "1" "2" "" "3" "4" "" "") eof " *" " 12 34 " 0)
  (t '("" "" "1" "2" "" "3" "4" "" "") eof " *" " 12 34 " 0 #f)
  (t '("" "" "1" "2" "" "3" "4" "" "") eof " *" " 12 34 " 0 7)
  (t '("" "2" "3" "") eof " *" "123" 1)
  (t '("" "2" "" "3" "4" "") eof " *" "12 34" 1)
  (t '("" "2" "" "3" "4" "" "") eof " *" " 12 34 " 2)
  (t '("" "1" "") "23" "" "123" 0 1)
  (t '("" "2" "") "3" "" "123" 1 2)
  (t '("" "3" "") eof "" "123" 2 3)
  (t '("" "1" "2" "") "3" " *" "123" 0 2)
  (t '("" "2" "3" "") eof " *" "123" 1 3)
  ;; more tests with match*
  (t regexp-match*)
  (t '("" "" "" "") eof "" "123")
  (t '("" "" " " "" "" "") eof " *" "12 34")
  (t '(" " "" "" " " "" "" " " "") eof " *" " 12 34 ")
  (t '("" "" " " "" "" "") " " " *" " 12 34 " 1 6)
  (t '("") eof " *" "")
  (t '("") eof " *" "1234" 4)
  (t '("") "34" " *" "1234" 2 2)
  (t regexp-match-positions*)
  (t '((0 . 0) (1 . 1) (2 . 2) (3 . 3)) eof "" "123")
  (t '((0 . 0) (1 . 1) (2 . 3) (3 . 3) (4 . 4) (5 . 5)) eof " *" "12 34")
  (t '((0 . 1) (1 . 1) (2 . 2) (3 . 4) (4 . 4) (5 . 5) (6 . 7) (7 . 7)) eof " *" " 12 34 ")
  (t '((1 . 1) (2 . 2) (3 . 4) (4 . 4) (5 . 5) (6 . 6)) " " " *" " 12 34 " 1 6)
  (t regexp-match-peek-positions*)
  (t '((0 . 0) (1 . 1) (2 . 2) (3 . 3)) "123" "" "123")
  (t '((0 . 0) (1 . 1) (2 . 3) (3 . 3) (4 . 4) (5 . 5)) "12 34" " *" "12 34")
  (t '((0 . 1) (1 . 1) (2 . 2) (3 . 4) (4 . 4) (5 . 5) (6 . 7) (7 . 7)) " 12 34 " " *" " 12 34 ")
  (t '((1 . 1) (2 . 2) (3 . 4) (4 . 4) (5 . 5) (6 . 6)) " 12 34 " " *" " 12 34 " 1 6)
  ;; finally, some tests for the match* + split property
  (t (lambda (rx str)
       (let ([s (regexp-split rx str)]
             [m (regexp-match* rx str)])
         (and (pair? s) (= (length s) (add1 (length m)))
              (apply (if (string? (car s)) string-append bytes-append)
                     (car s)
                     (append-map list m (cdr s)))))))
  (t "12 34"   #f " " "12 34")
  (t " 12 34 " #f " " " 12 34 ")
  (t "12 34"   #f " *" "12 34")
  (t " 12 34 " #f " *" " 12 34 ")
  (t "12 34"   #f "" "12 34")
  (t " 12 34 " #f "" " 12 34 ")
  )

;; String splitting can take longer than byte-string splitting,
;;  but it should have the same computational complexity.
;;
;; While the test is unreliable, it seems to fail mostly on
;; Windows CI.
(when (or (not (eq? (system-type 'os) 'windows))
          (run-unreliable-tests? 'timing))
  (define N 100000)
  (define-values (b bcpu breal bgc) 
    (time-apply
     (lambda () (regexp-split #rx#"." (make-bytes N)))
     null))
  (define-values (s scpu sreal sgc) 
    (time-apply
     (lambda () (regexp-split #rx"." (make-string N)))
     null))
  (test #f
        'split
        (and ((* 100 (- bcpu bgc)) . < . (- scpu sgc))
             "suspiciously long time for regexp string split")))

;; ---------- regexp-replaces ----------
(let ()
  (test "foo" regexp-replaces "foo" '())
  (test "is_zero_or_more"
        regexp-replaces "zero-or-more?"
        '([#rx"-" "_"] [#rx"(.*)\\?$" "is_\\1"]))
  (test "zooroo-oor-mooroo?"
        regexp-replaces "zero-or-more?" '(["e" "o"] ["o" "oo"])))

;; ---------- string-append* ----------
(let ()
  (test ""           string-append* '())
  (test ""           string-append* '(""))
  (test ""           string-append* '("" ""))
  (test "0123456789" string-append* '("0123456789"))
  (test "0123456789" string-append* "0123456789" '())
  (test "0123456789" string-append* "0123456789" '(""))
  (test "0123456789" string-append* "0123456789" '("" ""))
  (test "0123456789" string-append* "01234567" '("8" "9")))

;; ---------- string-join ----------
(let ()
  (test ""      string-join '())
  (test ""      string-join '(""))
  (test " "     string-join '("" ""))
  (test "x"     string-join '("x"))
  (test "x y"   string-join '("x" "y"))
  (test "x y z" string-join '("x" "y" "z") " ")
  (test "x,y,z" string-join '("x" "y" "z") ",")
  (test "x, y and z" string-join '("x" "y" "z") ", " #:before-last " and ")

  ;; test empty string optimization
  (test "xyz" string-join '("x" "y" "z") "")
  (test "xyz" string-join '("x" "y" "z") "" #:before-last "")
  (test "xy and z" string-join '("x" "y" "z") "" #:before-last " and ")
  (test "xy" string-join '("x" "y") "")
  (test "xy" string-join '("x" "y") "" #:before-last "")
  (test "x and y" string-join '("x" "y") "" #:before-last " and ")

  (for ([strs+res
         (in-list '((("x" "y" "z") "x, y and z")
                    (("x" "y")     "x and y")
                    (("x")         "x")
                    (("")          "")
                    (()            "")))])
    (test (cadr strs+res)
          string-join (car strs+res)
          ", " #:before-last " and ")
    (test (string-append "Todo: " (cadr strs+res))
          string-join (car strs+res)
          #:before-first "Todo: " ", " #:before-last " and ")
    (test (string-append (cadr strs+res) ".")
          string-join (car strs+res)
          ", " #:before-last " and " #:after-last ".")
    (test (string-append "Todo: " (cadr strs+res) ".")
          string-join (car strs+res)
          #:before-first "Todo: " ", " #:before-last " and " #:after-last ".")))

;; ---------- string-trim & string-normalize-spaces ----------
(let ()
  (define spaces '("" " " "  " "\r" "\r\n\t "))
  (define ++ string-append)
  (define-syntax-rule (with-spaces id E ...)
    (for ([id (in-list spaces)]) E ...))
  (define (both result arg)
    (test result string-trim arg)
    (test result string-normalize-spaces arg))
  (define (norm s) (if (equal? "" s) s " "))
  (with-spaces s1
    (both "" s1)
    (with-spaces s2
      (both "x" (++ s1 "x" s2))
      (both "xx" (++ s1 "xx" s2))
      (with-spaces s3
        (test (++ "x" s3 "x") string-trim (++ s1 "x" s3 "x" s2))
        (test (++ "x" (norm s3) "x")
              string-normalize-spaces (++ s1 "x" s3 "x" s2))
        (test (++ (norm s1) "x" (norm s3) "x" (norm s2))
              string-normalize-spaces (++ s1 "x" s3 "x" s2) #:trim? #f)
        (with-spaces s4
          (test (++ "x" (norm s3) "y" (norm s4) "z")
                string-normalize-spaces (++ s1 "x" s3 "y" s4 "z" s2))
          (test (++ (norm s1) "x" (norm s3) "y" (norm s4) "z" (norm s2))
                string-normalize-spaces (++ s1 "x" s3 "y" s4 "z" s2)
                                        #:trim? #f)))))
  (test "\t x \t" string-trim " \t x \t " #px" +")
  (test "  x"     string-trim "  x  " #:left? #f)
  (test "x  "     string-trim "  x  " #:right? #f)
  (test "  x  "   string-trim "  x  " #:left? #f #:right? #f)
  (test "x"       string-trim " x\t" #px" |\t")
  (test "x"       string-trim "\tx " #px" |\t")
  (test "\t x \t" string-trim " \t x \t " #px" |\t")
  (for* ([i+e '([""       ""  ""]
                ["a"      "a" "a"]
                ["aa"     ""  ""]
                ["aaa"    ""  ""] ; weird case
                ["aaaa"   ""  ""]
                ["aaaaa"  "a" ""]
                ["aa-aa"  "-" "-"]
                ["aaaaaa" "aa" ""]
                ["aa--aa" "--" "--"])]
         [sep '("aa" #rx"aa" #px"aa")])
    (define input     (car   i+e))
    (define expected  (cadr  i+e))
    (define expected+ (caddr i+e))
    (test expected  string-trim input sep)
    (test expected+ string-trim input sep #:repeat? #t))
  ;; this is obvious, but...
  (test "" string-trim "abaaba" "aba")
  ;; ...this is a version of the above weird case: it's questionable whether
  ;; this should return "" or "ba" (could also be "ab"), but it seems sensible
  ;; to do this (I haven't seen any existing trimmers that make any relevant
  ;; decision on this)
  (test "" string-trim "ababa" "aba"))

;test that mutable strings are not cached incorrectly
(let ([str (string-copy "_1_")])
  (test "x_2_" string-trim "_1_x_2_" str) ;add str to the internal cache
  (string-set! str 1 #\2)
  (test "_1_x" string-trim "_1_x_2_" str) ;verify that the new str is used
)
(let ([str (string-copy "_1_")])
  (test "x x_2_x" string-normalize-spaces "x_1_x_2_x" str) ;add str to the internal cache
  (string-set! str 1 #\2)
  (test "x_1_x x" string-normalize-spaces "x_1_x_2_x" str) ;verify that the new str is used
)

;; ---------- string-split ----------
(let ()
  (for ([s (in-list '("x y z" " x y z "  "\nx y z" "  \t x\r\r\ry \n\f\n   z\n"))])
    (test '("x" "y" "z") string-split s))
  (for ([s (in-list '(" " "   "  "\n\t\r"))])
    (test '() string-split s))
  (test '("x" "y" "z") string-split "axayaza" "a")
  (test '("" "x" "y" "z" "") string-split "axayaza" "a" #:trim? #f)
  (test '("foo" "bar" "baz") string-split "foo,bar;baz" #rx",|;"))

;test that mutable strings are not cached incorrectly
(let ([str (string-copy "_1_")])
  (test '("x" "x_2_x") string-split "x_1_x_2_x" str) ;add str to the internal cache
  (string-set! str 1 #\2)
  (test '("x_1_x" "x") string-split "x_1_x_2_x" str) ;verify that the new str is used
)

;; ---------- string-replace/* ----------
(let ()
  (test ""         string-replace "" "|" "?")
  (test "foo"      string-replace "foo" "|" "?")
  (test "foo\\bar" string-replace "foo\\bar" "\\" "\\")
  (test "foo[bar]" string-replace "foo]bar]" "]" "[" #:all? #f)
  (test "foo[bar[" string-replace "foo]bar]" "]" "[")
  (test "foo\\1bar" string-replace "foo===bar" #rx"(=+)" "\\1")
  (test "foo\\1bar" string-replace "foo===bar" #px"={3}" "\\1"))

;test that mutable string are not cached incorrectly
(let ([str (string-copy "_1_")])
  (test "!!! _2_" string-replace "_1_ _2_" str "!!!") ;add str to the internal cache
  (string-set! str 1 #\2)
  (test "_1_ !!!" string-replace "_1_ _2_" str "!!!") ;verify that the new str is used
)

;; ---------- string-prefix?/suffix? ----------
(let ()
  (test #t string-prefix? "racket" "")
  (test #t string-prefix? "racket" "r")
  (test #t string-prefix? "racket" "rack")
  (test #t string-prefix? "racket" "racket")
  (test #t string-suffix? "racket" "")
  (test #t string-suffix? "racket" "t")
  (test #t string-suffix? "racket" "cket")
  (test #t string-suffix? "racket" "racket")
  ;; --------------------
  (test #f string-prefix? ""       "racket")
  (test #f string-prefix? "racket" "R")
  (test #f string-prefix? "racket" "rak")
  (test #f string-prefix? "racket" "racket2")
  (test #f string-suffix? ""       "racket")
  (test #f string-suffix? "racket" "T")
  (test #f string-suffix? "racket" "r")
  (test #f string-suffix? "racket" "kat"))

;; ---------- string-contains? ----------

(let ()
  (test #t string-contains? "racket" "racket")
  (test #t string-contains? "racket" "cket")
  (test #t string-contains? "racket" "acke")
  (test #t string-contains? "racket" "t")
  (test #f string-contains? "racket" "b")
  (test #f string-contains? "racket" "R")
  (test #f string-contains? "RACKET" "r")
  (test #f string-contains? "racket" "kc")
  (test #f string-contains? "racket" "racketr")
  (test #t string-contains? "racket" "")
  (test #t string-contains? "" "")
  (test #f string-contains? "" "racket")
  (test #f string-contains? "racket" "a..e")
  (test #t string-contains? "ra..et" "a..e")
  ; string-contains? sometimes uses different code paths for short and long string,
  ; so add some long test too.
  (test #t string-contains? "racket012345678901234567890123456789012345678901234567890123456789racket"
                            "racket012345678901234567890123456789012345678901234567890123456789racket")
  (test #t string-contains? "racket012345678901234567890123456789012345678901234567890123456789racket"
                            "racket01234567890123456789")
  (test #t string-contains? "racket012345678901234567890123456789012345678901234567890123456789racket"
                            "01234567890123456789racket")
  (test #t string-contains? "racket012345678901234567890123456789012345678901234567890123456789racket"
                            "012345678901234567890123456789")
  (test #f string-contains? "racket012345678901234567890123456789012345678901234567890123456789racket"
                            "racket01234567890123456789racket")
  (test #t string-contains? "racket0123456789012345678901234567890123456789aaaaaaaaaaaaaaaaaaaaaaaaa"
                            "aaaaaaaaaaaaaaaaaaaaaaaaa")
  (test #t string-contains? "aaaaaaaaaaaaaaaaaaaaaaaaa0123456789012345678901234567890123456789racket"
                            "aaaaaaaaaaaaaaaaaaaaaaaaa")
  (test #f string-contains? "aaaaaaaaaaaaaaaaaaaaaaaa_012345678901234567890_aaaaaaaaaaaaaaaaaaaaaaaa"
                            "aaaaaaaaaaaaaaaaaaaaaaaaa")
  (test #t string-contains? "aaaaaaaaaaaaaaaaaaaaaaaaa012345678901234567890_aaaaaaaaaaaaaaaaaaaaaaaa"
                            "aaaaaaaaaaaaaaaaaaaaaaaaa")
  (test #t string-contains? "aaaaaaaaaaaaaaaaaaaaaaaa_012345678901234567890aaaaaaaaaaaaaaaaaaaaaaaaa"
                            "aaaaaaaaaaaaaaaaaaaaaaaaa")
  (test #t string-contains? "1234567890aaaaa123456789012345678901234567890aaaaa1234567890123456789012345678901234567890"
                            "1234567890123456789012345678901234567890")
  (test #f string-contains? "1234567890aaaaa123456789012345678901234567890aaaaa123456789012345678901234567890aaaa"
                            "1234567890123456789012345678901234567890")
  (test #f string-contains? "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
                            "yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy")
  (test #f string-contains? "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
                            "xxxxxxxxxxxxxxxxxxxxxxxxy")
  (test #f string-contains? "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
                            "yxxxxxxxxxxxxxxxxxxxxxxxx")
  (test #f string-contains? "xxxxxxxxxxxxxxxxxxxxxxxxyxxxxxxxxxxxxxxxxxxxxxxxxyxxxxxxxxxxxxxxxxxxxxx"
                            "xxxxxxxxxxxxxxxxxxxxxxxxx"))

;; ---------- build-kmp-table ----------

; The tables have one more coefficient than the usual tables,
; that can be used to get or count all the matches.
(let ()
  (test #(#f 0 0 0 0 0 0) build-kmp-table "racket")
  (test #(#f #f #f #f #f #f 5) build-kmp-table "rrrrrr")
  (test #(#f 0 #f 0 #f 0 4) build-kmp-table "ababab")
  (test #(#f 0 0 #f 0 0 #f 0 0 6) build-kmp-table "abcabcabc")
  (test #(#f 0 0 #f 0 0 #f 0 0 6) build-kmp-table "abbabbabb")
  (test #(#f #f 1 #f #f 1 #f #f 1 6) build-kmp-table "aabaabaab")
  (test #(#f #f 1 0 #f #f 1 0 #f #f 1 0 8 ) build-kmp-table "aabbaabbaabb")
  ; examples from https://en.wikipedia.org/wiki/Knuth–Morris–Pratt_algorithm
  (test #(#f 0 0 0 #f 0 2 0) build-kmp-table "abcdabd")
  (test #(#f 0 #f 1 #f 0 #f 3 2 0) build-kmp-table "abacababc"))

;; ---------- regexp-try-match ----------

(define (check-try-match expect pattern in-bstr
                         #:after [after-amt 0]
                         #:prefix [prefix #""])
  (define in (open-input-bytes in-bstr))
  (test expect regexp-try-match pattern in 0 #f #f prefix)

  ;; make sure suitable bytes remain:
  (define delta (- (+ (bytes-length in-bstr)
                      (bytes-length prefix))
                   after-amt
                   (bytes-length (car expect))))
  (test (bytes-append prefix in-bstr)
        bytes-append
        (subbytes prefix 0 (min after-amt (bytes-length prefix)))
        (subbytes in-bstr 0 (max 0 (- after-amt (bytes-length prefix))))
        (car expect)
        (read-bytes delta in))

  (define in2 (open-input-bytes in-bstr))
  (define out (open-output-bytes))
  (test expect regexp-try-match pattern in2 0 #f out prefix)
  (test (subbytes in-bstr 0 (max 0 (- after-amt (bytes-length prefix)))) get-output-bytes out))

(check-try-match '(#"hello") #px"he..." #"hello world")
(check-try-match '(#"" #"a") #px"^(?=(a))" #"a")
(check-try-match '(#"some" #"a") #px"^some(?=(a))" #"someathing")
(check-try-match '(#"some" #"a") #px"some(?=(a))" #"try someathing" #:after 4)
(check-try-match '(#"c" #"ab") #rx"(?<=(..))." #"abc" #:after 2)
(check-try-match '(#"b" #"!a") #rx"(?<=(..))." #"abc" #:prefix #"!" #:after 2)
(check-try-match '(#"" #"xa") #rx"(?<=(..))" #"aaa" #:prefix #"x" #:after 2)

;; ----------------------------------------

(report-errs)
