
(load-relative "loadtest.rktl")

(Section 'reading)
(define core-readstr
  (lambda (s)
    (let* ([o (open-input-string s)]
	   [read (lambda () (read o))])
      (let loop ([last eof])
	(let ([v (read)])
	  (if (eof-object? v)
	      last
	      (loop v)))))))

(define (readstr s)
  (if (current-readtable)
      (core-readstr s)
      ;; Try using a readtable that behaves the same as the default,
      ;; since that triggers some different paths in the reader:
      (let* ([normal (with-handlers ([exn:fail? values])
                       (core-readstr s))]
             [c-normal (adjust-result-to-compare normal)]
             [rt (adjust-result-to-compare
                  (with-handlers ([exn:fail? values])
                    (parameterize ([current-readtable (make-readtable (current-readtable))])
                      (core-readstr s))))])
        (if (equal? c-normal rt)
            (if (exn? normal)
                (raise normal)
                normal)
            (list "different with readtable" s c-normal rt)))))

(require racket/extflonum)

(define (adjust-result-to-compare v)
  ;; Make results from two readstrs comparable
  (cond
   [(hash? v)
    (for/fold ([ht (hash)]) ([(k hv) (in-hash v)])
      (hash-update ht
                   (if (eq? k v) 'SELF k)
                   (lambda (vht)
                     (hash-set vht hv #t))
                   (hash)))]
   [(exn? v) (exn-message v)]
   [(extflonum? v) (format "~s" v)]
   [else v]))

(define readerrtype
  (lambda (x) x))

; Make sure {whitespace} == {delimiter}
(let ([with-censor (load-relative "censor.rktl")])
  (with-censor
   (lambda ()
     (let loop ([n 0])
       (unless (= n 256)
	 (let* ([c0 (integer->char n)]
		[c (if (read-case-sensitive)
		       c0
		       (char-downcase c0))])
	   (cond
	    [(char-whitespace? c)
	     (test 'b readstr (string #\a c #\b))]
	    [(char=? #\\ c) (test 'ab readstr (string #\a c #\b))]
	    [(char=? #\; c) (test 'a readstr (string #\a c #\b))]
	    [(char=? #\' c) (test ''b readstr (string #\a c #\b))]
	    [(char=? #\` c) (test '`b readstr (string #\a c #\b))]
	    [(char=? #\, c) (test ',b readstr (string #\a c #\b))]
	    [else
	     (test (string->symbol (string #\a c #\b))
		   'readstr
		   (with-handlers ([void 
				    (lambda (x) 
				      (string->symbol (string #\a c #\b)))])
		     (readstr (string #\a c0 #\b))))]))
	 (loop (add1 n)))))))

(err/rt-test (readstr ")") exn:fail:read?)
(err/rt-test (readstr "[)") exn:fail:read?)
(err/rt-test (readstr "[}") exn:fail:read?)
(err/rt-test (readstr "8 )") exn:fail:read?)
(err/rt-test (readstr "(. )") exn:fail:read?)
(err/rt-test (readstr "(. 8)") exn:fail:read?)
(err/rt-test (readstr "(8 . )") exn:fail:read?)
(err/rt-test (readstr "(8 . ]") exn:fail:read?)
(err/rt-test (readstr "(8 . 9 . )") exn:fail:read?)
(err/rt-test (readstr "(8 . 9 . ]") exn:fail:read?)
(err/rt-test (readstr "(8 . 9 . 1 . )") exn:fail:read?)
(err/rt-test (readstr "(8 . 9 . 1 . 10)") exn:fail:read?)
(err/rt-test (readstr "(8 . 9 . #;1)") exn:fail:read?)
(err/rt-test (readstr "(8 . 9 . ;\n)") exn:fail:read?)
(err/rt-test (readstr "(8 . 9 . #|x|#)") exn:fail:read?)

(let ([w-suffix
       (lambda (s)
         (test #t readstr (string-append "#t" s))
         (test #t readstr (string-append "#T" s))
         (test #t readstr (string-append "#true" s))
         (test #f readstr (string-append "#f" s))
         (test #f readstr (string-append "#F" s))
         (test #f readstr (string-append "#false" s)))])
  (w-suffix "")
  (w-suffix " ")
  (w-suffix ";")
  (err/rt-test (readstr "#True") exn:fail:read?)
  (err/rt-test (readstr "#tru")  exn:fail:read:eof?)
  (err/rt-test (readstr "#truer") exn:fail:read?)
  (err/rt-test (readstr "#False") exn:fail:read?)
  (err/rt-test (readstr "#fals")  exn:fail:read:eof?)
  (err/rt-test (readstr "#falser") exn:fail:read?))

(parameterize ([read-decimal-as-inexact #f])
  (test 1 readstr "1.0")
  (test 100000 readstr "1e5")
  (test 100000 readstr "1#e4")
  (test 10 readstr "1#")
  (test 1/2 readstr "1#/20")
  (test 1/2 readstr "10/2#")
  (test 1/2 readstr "1#/2#")
  (test 1/2 string->number "1#/2#")
  (test 10+3i readstr "1#+3i")
  (test 1+30i readstr "1+3#i")
  (err/rt-test (readstr "1#/0") exn:fail:read?)
  (err/rt-test (readstr "1/0#") exn:fail:read?)
  (err/rt-test (readstr "1#/0#") exn:fail:read?)
  (test #f string->number "1#/0")
  (test #f string->number "1/0#"))

(test (integer->char 0) readstr "#\\nul")
(test (integer->char 0) readstr "#\\Nul")
(test (integer->char 0) readstr "#\\NuL")
(test (integer->char 0) readstr "#\\null")
(test (integer->char 0) readstr "#\\Null")
(test (integer->char 0) readstr "#\\NulL")
(test (integer->char 8) readstr "#\\Backspace")
(test (integer->char 8) readstr "#\\BacksPace")
(test (integer->char 9) readstr "#\\tab")
(test (integer->char 9) readstr "#\\Tab")
(test (integer->char 9) readstr "#\\TaB")
(test (integer->char 10) readstr "#\\newline")
(test (integer->char 10) readstr "#\\Newline")
(test (integer->char 10) readstr "#\\NewLine")
(test (integer->char 10) readstr "#\\linefeed")
(test (integer->char 10) readstr "#\\Linefeed")
(test (integer->char 10) readstr "#\\LinefEeD")
(test (integer->char 11) readstr "#\\vtab")
(test (integer->char 11) readstr "#\\Vtab")
(test (integer->char 11) readstr "#\\VtAb")
(test (integer->char 12) readstr "#\\page")
(test (integer->char 12) readstr "#\\Page")
(test (integer->char 12) readstr "#\\PaGe")
(test (integer->char 13) readstr "#\\return")
(test (integer->char 13) readstr "#\\Return")
(test (integer->char 13) readstr "#\\retUrn")
(test (integer->char 127) readstr "#\\rubout")
(test (integer->char 127) readstr "#\\Rubout")
(test (integer->char 127) readstr "#\\RubOut")
(test (integer->char #x1) readstr "#\\u1")
(test (integer->char #x10) readstr "#\\u10")
(test (integer->char #x100) readstr "#\\u100")
(test (integer->char #x1000) readstr "#\\u1000")
(test (integer->char #xa) readstr "#\\ua")
(test (integer->char #xa7) readstr "#\\uA7")
(test (integer->char #xa77) readstr "#\\ua77")
(test (integer->char #xa77C) readstr "#\\uA77C")
(test 0 readstr "#\\u10000")
(test 'a readstr "#\\ua000a")
(test 'x readstr "#\\ua000x")
(test (integer->char #xa) readstr "#\\Ua")
(test (integer->char #xa7) readstr "#\\UA7")
(test (integer->char #xa77) readstr "#\\Ua77")
(test (integer->char #xa77C) readstr "#\\UA77C")
(test (integer->char #x10000) readstr "#\\U10000")
(test (integer->char #x100000) readstr "#\\U100000")
(test (integer->char #x10FFFF) readstr "#\\U10FFFF")
(test (integer->char #x10FFFF) readstr "#\\U0010FFFF")
(test (integer->char #x0) readstr "#\\U00000000")
(test 1 readstr "#\\U000000011")

(err/rt-test (readstr "#\\uD800") exn:fail:read?)
(err/rt-test (readstr "#\\uD900") exn:fail:read?)
(err/rt-test (readstr "#\\UDFFF") exn:fail:read?)
(err/rt-test (readstr "#\\UFFFFFF") exn:fail:read?)
(err/rt-test (readstr "#\\U110000") exn:fail:read?)
(err/rt-test (readstr "#\\U1000000") exn:fail:read?)
(err/rt-test (readstr "#\\U10000000") exn:fail:read?)
(err/rt-test (readstr "#\\UFFFFFFFF") exn:fail:read?)

(define (astring n) (string (integer->char n)))

(test (astring 7) readstr "\"\\a\"")
(test (astring 8) readstr "\"\\b\"")
(test (astring 9) readstr "\"\\t\"")
(test (astring 10) readstr "\"\\n\"")
(test (astring 11) readstr "\"\\v\"")
(test (astring 12) readstr "\"\\f\"")
(test (astring 13) readstr "\"\\r\"")
(test #\u1B string-ref (readstr "\"\\e\"") 0)
(test #\u0 string-ref (readstr "\"\\0\"") 0)
(test #\u8 string-ref (readstr "\"\\10\"") 0)
(test #\uC string-ref (readstr "\"\\14\"") 0)
(test (integer->char #o114)  string-ref (readstr "\"\\114\"") 0)
(test (integer->char #o111)  string-ref (readstr "\"\\1111\"") 0)
(test (astring #x24) readstr "\"\\x24\"")
(test (string #\u24 #\space) readstr "\"\\x24 \"")
(test (string #\u24 #\5) readstr "\"\\x245\"")
(test (astring #x1024) readstr "\"\\u1024\"")
(test (astring #x1C24) readstr "\"\\u1C24\"")
(test (string #\u0001) readstr "\"\\u1\"")
(test (string #\u0001 #\space) readstr "\"\\u1 \"")
(test (string #\u0001) readstr "\"\\u01\"")
(test (string #\u0001 #\space) readstr "\"\\u01 \"")
(test (string #\u0001) readstr "\"\\u001\"")
(test (string #\u0001 #\space) readstr "\"\\u001 \"")
(test (string #\u0001) readstr "\"\\u0001\"")
(test (string #\u0001 #\space) readstr "\"\\u0001 \"")
(test (string #\u0001 #\1) readstr "\"\\u00011\"")
(test (string #\U10000) readstr "\"\\uD800\\uDC00\"")
(test (string #\U1D11E) readstr "\"\\uD834\\uDD1E\"")

(err/rt-test (readstr "\"\\c\"") exn:fail:read?)
(err/rt-test (readstr "\"\\777\"") exn:fail:read?)
(err/rt-test (readstr "\"\\uD800\"") exn:fail:read?)
(err/rt-test (readstr "\"\\UB0000000\"") exn:fail:read?)
(err/rt-test (readstr "\"\\UFFFFFFFF\"") exn:fail:read?)
(err/rt-test (readstr "\"\\uD800\\u\"") exn:fail:read?)
(err/rt-test (readstr "\"\\uD800\\uD\"") exn:fail:read?)
(err/rt-test (readstr "\"\\uD800\\uD\"") exn:fail:read?)
(err/rt-test (readstr "\"\\uD800\\uDD\"") exn:fail:read?)
(err/rt-test (readstr "\"\\uD800\\uDD1\"") exn:fail:read?)

(test "abc" readstr "#<<EOS\nabc\nEOS\n")
(test "abc\ndef" readstr "#<<EOS\nabc\ndef\nEOS\n")
(test "\n" readstr "#<<EOS\n\n\nEOS\n")
(test "abc" readstr "#<<EOS\nabc\nEOS\n   ")
(test "abc" readstr "#<<EOS\nabc\nEOS")
(test "ok\r\nmore\r" readstr "#<<EOS\r\nok\r\nmore\r\nEOS\r")
(test "" readstr "#<<EOS\nEOS\n")
(err/rt-test (readstr "#<<EOS\nabc\nEO") exn:fail:read?)
(err/rt-test (readstr "#<<EOS\r\nabc\nEOS") exn:fail:read?)

(test (bytes 7) readstr "#\"\\a\"")
(test (bytes 8) readstr "#\"\\b\"")
(test (bytes 9) readstr "#\"\\t\"")
(test (bytes 10) readstr "#\"\\n\"")
(test (bytes 11) readstr "#\"\\v\"")
(test (bytes 12) readstr "#\"\\f\"")
(test (bytes 13) readstr "#\"\\r\"")
(test #x1B bytes-ref (readstr "#\"\\e\"") 0)
(test #x0 bytes-ref (readstr "#\"\\0\"") 0)
(test #x8 bytes-ref (readstr "#\"\\10\"") 0)
(test #xC bytes-ref (readstr "#\"\\14\"") 0)
(test #o114 bytes-ref (readstr "#\"\\114\"") 0)
(test #o111 bytes-ref (readstr "#\"\\1111\"") 0)
(test (bytes #x24) readstr "#\"\\x24\"")
(test (bytes #x24 32) readstr "#\"\\x24 \"")
(test (bytes #x24 53) readstr "#\"\\x245\"")

(err/rt-test (readstr "#\"\\c\"") exn:fail:read?)
(err/rt-test (readstr "#\"\\777\"") exn:fail:read?)
(err/rt-test (readstr "#\"\\u0040\"") exn:fail:read?)
(err/rt-test (readstr "#\"\u0100\"") exn:fail:read?)
(err/rt-test (readstr "#\"\u03BB\"") exn:fail:read?)

(define (check-all-numbers number-table)
  (let loop ([l number-table])
    (unless (null? l)
      (let* ([pair (car l)]
             [v (car pair)]
             [s (cadr pair)])
        (for ([s (in-list (list s (string-upcase s)))])
          (cond
            [(memq v '(X DBZ NOE))
             (err/rt-test (readstr s) exn:fail:read?)
             (test #f string->number s)
             (test #t string? (string->number s 10 'read))]
            [v 
             (test v readstr s)
             (test (if (symbol? v) #f v) string->number s)
             (test (if (symbol? v) #f v) string->number s 10 'read)]
            [else 
             (test (string->symbol s) readstr s)
             (test #f string->number s)
             (test #f string->number s 10 'read)
             (unless (regexp-match "#" s)
               (err/rt-test (readstr (string-append "#d" s)) exn:fail:read?)
               (test #f string->number (string-append "#d" s))
               (test #t string? (string->number (string-append "#d" s) 10 'read)))])))
      (loop (cdr l)))))

(load-relative "numstrs.rktl")
(check-all-numbers number-table)

;; single-flonums disabled by default
(check-all-numbers '((10.0 "1f1")
                     (10.0 "#i1f1")))

(when (single-flonum-available?)
  (parameterize ([read-single-flonum #t])
    (define def (call-with-input-file*
                 (build-path (or (current-load-relative-directory)
                                 (current-directory))
                             "numstrs.rktl")
                 (lambda (i) (read i))))
    (check-all-numbers (eval (caddr def)))))

(unless (single-flonum-available?)
  (parameterize ([read-single-flonum #t])
    (err/rt-test (read (open-input-string "3.4f5"))
                 exn:fail:unsupported?)))

(test 5 string->number "5" 10 'number-or-false)
(test 5 string->number "5.0" 10 'number-or-false 'decimal-as-exact)
(test 5.0 string->number "5.0" 10 'number-or-false 'decimal-as-inexact)
(test 5.0 string->number "5.0f0" 10 'number-or-false 'decimal-as-inexact 'double)
(if (single-flonum-available?)
    (test (real->single-flonum 5.0) string->number "5.0f0" 10 'number-or-false 'decimal-as-inexact 'single)
    (err/rt-test (string->number "5.0f0" 10 'number-or-false 'decimal-as-inexact 'single)
                 exn:fail:unsupported?))

(define (make-exn:fail:read:eof?/span start span)
  (lambda (exn)
    (and (exn:fail:read:eof? exn)
         (pair? (exn:fail:read-srclocs exn))
         (let ([srcloc (car (exn:fail:read-srclocs exn))])
           (and (equal? start (srcloc-position srcloc))
                (equal? span (srcloc-span srcloc)))))))

(test 5 readstr "#| hi |# 5")
(test 5 readstr "#| #| #| #| hi |# |# |# |# 5")
(test '(5) readstr "(#| #| #| #| hi |# |# |# |# 5)")
(test '(10 1) readstr "(10 #|z#|#f|#z|# 1)")
(test 17 readstr "#|z#|#f|#z|# 17")
(test 17 readstr "#|#|x|#|# 17")

(err/rt-test (readstr "#\\silly") exn:fail:read?)
(err/rt-test (readstr "#\\nully") exn:fail:read?)
(err/rt-test (readstr "#\\nu") exn:fail:read?)
(err/rt-test (readstr "#\\733") exn:fail:read?)
(err/rt-test (readstr "#\\433") exn:fail:read?)
(err/rt-test (readstr "#\\longerthanthrityonecharcterswhichisthebufsize") exn:fail:read?)
(err/rt-test (readstr "#\\rcase") exn:fail:read?)
(err/rt-test (readstr "#\\pcase") exn:fail:read?)
(err/rt-test (readstr "#\\tcase") exn:fail:read?)
(err/rt-test (readstr "#\\vcase") exn:fail:read?)
(err/rt-test (readstr "#\\bcase") exn:fail:read?)
(err/rt-test (readstr "#\\lcase") exn:fail:read?)

(err/rt-test (readstr "(hi") (make-exn:fail:read:eof?/span 1 1))
(err/rt-test (readstr "\"hi") (make-exn:fail:read:eof?/span 1 1))
(err/rt-test (readstr "\"hi\\") exn:fail:read:eof?)
(err/rt-test (readstr "#(hi") (make-exn:fail:read:eof?/span 1 2))
(err/rt-test (readstr "#[hi") exn:fail:read:eof?)
(err/rt-test (readstr "#{hi") exn:fail:read:eof?)
(err/rt-test (readstr "#4(hi") exn:fail:read:eof?)
(err/rt-test (readstr "#4[hi") exn:fail:read:eof?)
(err/rt-test (readstr "#4{hi") exn:fail:read:eof?)
(err/rt-test (readstr "|hi") (make-exn:fail:read:eof?/span 1 3))
(err/rt-test (readstr "hi\\") exn:fail:read:eof?)
(err/rt-test (readstr "#\\") (make-exn:fail:read:eof?/span 1 2))
(err/rt-test (readstr "#\\12") exn:fail:read:eof?)
(err/rt-test (readstr "#| hi") exn:fail:read:eof?)
(err/rt-test (readstr "(1 #| hi") exn:fail:read:eof?)
(err/rt-test (readstr "'") (make-exn:fail:read:eof?/span 1 1))
(err/rt-test (readstr "' ") (make-exn:fail:read:eof?/span 1 1))
(err/rt-test (readstr "`") (make-exn:fail:read:eof?/span 1 1))
(err/rt-test (readstr "` ") (make-exn:fail:read:eof?/span 1 1))
(err/rt-test (readstr ",@") (make-exn:fail:read:eof?/span 1 2))
(err/rt-test (readstr ",@ ") (make-exn:fail:read:eof?/span 1 2))
(err/rt-test (readstr ",") (make-exn:fail:read:eof?/span 1 1))
(err/rt-test (readstr ", ") (make-exn:fail:read:eof?/span 1 1))
(err/rt-test (readstr "#'") (make-exn:fail:read:eof?/span 1 2))
(err/rt-test (readstr "#' ") (make-exn:fail:read:eof?/span 1 2))
(err/rt-test (readstr "#&") (make-exn:fail:read:eof?/span 1 2))
(err/rt-test (readstr "#& ") (make-exn:fail:read:eof?/span 1 2))

(err/rt-test (readstr ".") exn:fail:read?)
(err/rt-test (readstr "a .") exn:fail:read?)
(err/rt-test (readstr "a . b") exn:fail:read?)
(err/rt-test (readstr "( . )") exn:fail:read?)
(err/rt-test (readstr "(1 .") exn:fail:read:eof?)
(err/rt-test (readstr "(1 .   ") exn:fail:read:eof?)
(err/rt-test (readstr "(1 . 2") exn:fail:read:eof?)
(err/rt-test (readstr "( . 8)") exn:fail:read?)
(err/rt-test (readstr "(0 . 8 9)") exn:fail:read?)
(err/rt-test (readstr "( . 8 9)") exn:fail:read?)
(err/rt-test (readstr "(1 . 2 3 . 4)") exn:fail:read?)
(err/rt-test (readstr "(1 . 2 . 3 . 4)") exn:fail:read?)
(err/rt-test (readstr "(1 . 2 .3)") exn:fail:read?)
(err/rt-test (readstr "(1 . 2 .a)") exn:fail:read?)
(err/rt-test (readstr "#(8 . )") exn:fail:read?)
(err/rt-test (readstr "#( . )") exn:fail:read?)
(err/rt-test (readstr "#( . 8)") exn:fail:read?)
(err/rt-test (readstr "#(0 . 8 9)") exn:fail:read?)
(err/rt-test (readstr "#( . 8 9)") exn:fail:read?)
(err/rt-test (readstr "#( 8 . 9)") exn:fail:read?)
(err/rt-test (readstr "#( 8 . (9))") exn:fail:read?)
(err/rt-test (readstr "#(1 . 2 . 3)") exn:fail:read?)

(err/rt-test (readstr "#Q") exn:fail:read?)
(err/rt-test (readstr "##") exn:fail:read?)
(err/rt-test (readstr "#?") exn:fail:read?)
(err/rt-test (readstr "#-1()") exn:fail:read?)
(err/rt-test (readstr "#<a>") exn:fail:read?)
(err/rt-test (readstr "#") exn:fail:read:eof?)

(test #(1 a c) readstr "#[1 a c]")
(test #(1 a c) readstr "#{1 a c}")
(test #(1 a a) readstr "#3[1 a]")
(test #(1 a a) readstr "#3{1 a}")
(parameterize ([read-square-bracket-as-paren #f]
	       [read-curly-brace-as-paren #f]
	       [read-accept-quasiquote #f])
  (err/rt-test (readstr "[2") exn:fail:read?)
  (err/rt-test (readstr "{2") exn:fail:read?)
  (err/rt-test (readstr "}2") exn:fail:read?)
  (err/rt-test (readstr "]2") exn:fail:read?)
  (err/rt-test (readstr "#{1}") exn:fail:read?)
  (err/rt-test (readstr "#[1]") exn:fail:read?)
  (err/rt-test (readstr "#2{1}") exn:fail:read?)
  (err/rt-test (readstr "#2[1]") exn:fail:read?)
  (err/rt-test (readstr ",2") exn:fail:read?)
  (err/rt-test (readstr ",@2") exn:fail:read?)
  (err/rt-test (readstr "`2") exn:fail:read?))

(test '(1 2 3) readstr "(2 . 1 . 3)")
(test '(1 2 3 4) readstr "(2 . 1 . 3 4)")
(test '(1 2 3 4) readstr "(2 3 . 1 . 4)")
(test '(2 . 0.4) readstr "(2 . .4)")

(err/rt-test (readstr "#ha") exn:fail:read:eof?)
(err/rt-test (readstr "#ham") exn:fail:read?)
(err/rt-test (readstr "#hash") exn:fail:read:eof?)
(err/rt-test (readstr "#hashe") exn:fail:read:eof?)
(err/rt-test (readstr "#hasheq") exn:fail:read:eof?)
(err/rt-test (readstr "#hasheqv") exn:fail:read:eof?)
(err/rt-test (readstr "#hashalw") exn:fail:read:eof?)
(err/rt-test (readstr "#hash(") (make-exn:fail:read:eof?/span 1 6))
(err/rt-test (readstr "#hash((1") exn:fail:read:eof?)
(err/rt-test (readstr "#hash((1 .") exn:fail:read:eof?)
(err/rt-test (readstr "#hash((1 . 2)") exn:fail:read:eof?)
(err/rt-test (readstr "#hash(1)") exn:fail:read?)
(err/rt-test (readstr "#hash(1 2)") exn:fail:read?)
(err/rt-test (readstr "#hash(1 . 2)") exn:fail:read?)
(err/rt-test (readstr "#hash((1))") exn:fail:read?)
(err/rt-test (readstr "#hash((1 2))") exn:fail:read?)
(err/rt-test (readstr "#hash((1. 2))") exn:fail:read?)
(err/rt-test (readstr "#hash((1 .2))") exn:fail:read?)
(err/rt-test (readstr "#hash((1 . 2 3))") exn:fail:read?)
(err/rt-test (readstr "#hash((1 . 2) . ((3 . 4)))") exn:fail:read?)
(err/rt-test (readstr "#hash((1 . 2) . (3 . 4) . (5 . 6))") exn:fail:read?)
(err/rt-test (readstr "#hash((1 . 2 . 3))") exn:fail:read?)
(err/rt-test (readstr "#hash(#0=(1 . 2))") exn:fail:read?)
(err/rt-test (readstr "#hash#0=((1 . 2))") exn:fail:read?)
(err/rt-test (readstr "#hash((1 #0=(2)))") exn:fail:read?)
(err/rt-test (readstr "#0=#hash#0#") exn:fail:read?)
(err/rt-test (readstr "#0=#hash(#0#)") exn:fail:read?)
(err/rt-test (readstr "#hash([1 . 2))") exn:fail:read?)
(err/rt-test (readstr "#hash([1 . ;; a\n))") exn:fail:read?)
(err/rt-test (readstr "#hash([;; a\n . 1))") exn:fail:read?)

(test #t eq? (readstr "#hash()") (hash))
(test #t eq? (readstr "#hasheq()") (hasheq))
(test #t eq? (readstr "#hasheqv()") (hasheqv))
(test #t eq? (readstr "#hashalw()") (hashalw))

(define (test-ht t size eq? key val)
  (test #t hash? t)
  (test eq? hash-eq? t)
  (test size length (hash-map t cons))
  (test 'nope hash-ref t 'not-there (lambda () 'nope))
  (test val hash-ref t key (lambda () #f)))
(test-ht (readstr "#hash()") 0 #f 'none #f)
(test-ht (readstr "#hash((1 . 2))") 1 #f 1 2)
(test-ht (readstr "#hash([1 . 2])") 1 #f 1 2)
(test-ht (readstr "#hash[(1 . 2)]") 1 #f 1 2)
(test-ht (readstr "#hash({1 . 2})") 1 #f 1 2)
(test-ht (readstr "#hash{(1 . 2)}") 1 #f 1 2)
(test-ht (readstr "#hash{[1 . 2]}") 1 #f 1 2)
(test-ht (readstr "#hasheq((1 . 2))") 1 #t 1 2)
(test-ht (readstr "#hasheqv((1 . 2))") 1 #f 1 2)
(test-ht (readstr "#hashalw((1 . 2))") 1 #f 1 2)
(test-ht (readstr "#hash((\"apple\" . 1))") 1 #f "apple" 1)
(test-ht (readstr "#hasheq((\"apple\" . 1))") 1 #t "apple" #f)
(test-ht (readstr "#hasheqv((\"apple\" . 1))") 1 #f "apple" #f)
;; NOTE: these strings produced by the `read` are mutable! so not equal-always?
(test-ht (readstr "#hashalw((\"apple\" . 1))") 1 #f "apple" #f)
(test-ht (readstr "#hash((\"apple\" . 1) (\"apple\" . 10))") 1 #f "apple" 10)
(test-ht (readstr "#hasheq((\"apple\" . 1) (\"apple\" . 10))") 2 #t "apple" #f)
(test-ht (readstr "#hasheqv((\"apple\" . 1) (\"apple\" . 10))") 2 #f "apple" #f)
;; NOTE: these strings produced by the `read` are mutable! so not equal-always?
(test-ht (readstr "#hashalw((\"apple\" . 1) (\"apple\" . 10))") 2 #f "apple" #f)
(test-ht (readstr "#hash((apple . 1) (apple . 10))") 1 #f 'apple 10)
(test-ht (readstr "#hasheq((apple . 1) (apple . 10))") 1 #t 'apple 10)
(test-ht (readstr "#hasheqv((apple . 1) (apple . 10))") 1 #f 'apple 10)
(test-ht (readstr "#hashalw((apple . 1) (apple . 10))") 1 #f 'apple 10)
(test-ht (readstr "#hasheq((#0=\"apple\" . 1) (#0# . 10))") 1 #t "apple" #f)
(test-ht (readstr "#hash((#0=\"apple\" . 1) (\"banana\" . #0#))") 2 #f "banana" "apple")
(test-ht (readstr "#hash((a . 1) (b . 2) (c . 3) (e . 4) (f . 5) (g . 6) (h . 7) (i . 8))") 8 #f 'f 5)
(let ([t (readstr "#0=#hash((\"apple\" . #0#))")])
  (test-ht t 1 #f "apple" t))
(test-ht (readstr "#hash((#hash((1 . 2)) . 11) (#hash((3 . 4)) . 12))") 2 #f #hash((1 . 2)) 11)
(test-ht (readstr "#hash((#hash((1 . 2)) . 11) (#hash((3 . 4)) . 12))") 2 #f #hash((3 . 4)) 12)
(let ([t (readstr "#0=#hasheq((#0# . 17))")])
  (test-ht t 1 #t t 17))
(let ([t (readstr "#0=#hash((#0# . 17))")])
  ;; Don't look for t, because that's a hash on a circular object!
  (test-ht t 1 #f 'none #f))
(test-ht (readstr "#hash( [ 1 . 2 ] )")
         1 #f 1 2)
(test-ht (readstr "#hash( ;abc\n[ 1 . 2 ] )")
         1 #f 1 2)
(test-ht (readstr "#hash( [ ;abc\n1 . 2 ] )")
         1 #f 1 2)
(test-ht (readstr "#hash( [ 1;abc\n. 2 ] )")
         1 #f 1 2)
(test-ht (readstr "#hash( [ 1 .;abc\n2 ] )")
         1 #f 1 2)
(test-ht (readstr "#hash( [ 1 . 2;abc\n] )")
         1 #f 1 2)
(test-ht (readstr "#hash( [ 1 . 2 ];abc\n)")
         1 #f 1 2)

(define (test-write-ht writer t . strings)
  (let ([o (open-output-string)])
    (writer t o)
    (test #t (car strings) (and (member (get-output-string o) strings) #t))))
(parameterize ([print-hash-table #f])
  (test-write-ht write #hash((1 . 2)) "#<hash>"))

(parameterize ([print-hash-table #t])
  (test-write-ht write #hash((1 . 2)) "#hash((1 . 2))")
  (test-write-ht write #hash((1 . 2) (3 . 4)) "#hash((1 . 2) (3 . 4))" "#hash((3 . 4) (1 . 2))")
  (test-write-ht write #hash(("apple" . |coconut !|)) "#hash((\"apple\" . |coconut !|))")
  (test-write-ht display #hash(("apple" . |coconut !|)) "#hash((apple . coconut !))")
  (test-write-ht write (read (open-input-string "#3=#hash((1 . #3#))")) "#0=#hash((1 . #0#))")
  (test-write-ht write (read (open-input-string "#hash((#37=(1 2) . #37#))")) "#hash(((1 2) . (1 2)))")
  (test-write-ht write (read (open-input-string "#hash((a . #9=(1 2)) (b . #9#))"))
		 "#hash((a . (1 2)) (b . (1 2)))"
		 "#hash((b . (1 2)) (a . (1 2)))")
  (parameterize ([print-graph #t])
    (test-write-ht write (read (open-input-string "#hash((#33=(1 2) . #33#))")) "#hash((#0=(1 2) . #0#))")
    (test-write-ht write (read (open-input-string "#hash((a . #7=(1 2)) (b . #7#))"))
		   "#hash((a . #0=(1 2)) (b . #0#))"
		   "#hash((b . #0=(1 2)) (a . #0#))")))


(test #t regexp? (readstr "#rx\".\""))
(test '("abc") regexp-match #rx"a.." "123abcdef")
(test #t pregexp? (readstr "#px\".\""))
(test '("abc") regexp-match #px"a.." "123abcdef")
(test #t byte-regexp? (readstr "#rx#\".\""))
(test '(#"abc") regexp-match #rx#"a.." "123abcdef")
(test #t byte-pregexp? (readstr "#px#\".\""))
(test '(#"abc") regexp-match #px#"a.." "123abcdef")

(err/rt-test (readstr "#r") (make-exn:fail:read:eof?/span 1 2))
(err/rt-test (readstr "#rx") exn:fail:read:eof?)
(err/rt-test (readstr "#rx\"") (make-exn:fail:read:eof?/span 1 4))
(err/rt-test (readstr "#rx\"x") (make-exn:fail:read:eof?/span 1 4))
(err/rt-test (readstr "#ra") exn:fail:read?)
(err/rt-test (readstr "#rxa") exn:fail:read?)
(err/rt-test (readstr "#rx\"?\"") exn:fail:read?)
(err/rt-test (readstr "#rx#") exn:fail:read:eof?)
(err/rt-test (readstr "#rx#\"") exn:fail:read:eof?)
(err/rt-test (readstr "#rx#a") exn:fail:read?)
(err/rt-test (readstr "#rx#\"?\"") exn:fail:read?)
(err/rt-test (readstr "#p") exn:fail:read:eof?)
(err/rt-test (readstr "#px") exn:fail:read:eof?)
(err/rt-test (readstr "#px\"") exn:fail:read:eof?)
(err/rt-test (readstr "#pa") exn:fail:read?)
(err/rt-test (readstr "#pxa") exn:fail:read?)
(err/rt-test (readstr "#px\"?\"") exn:fail:read?)
(err/rt-test (readstr "#px#") exn:fail:read:eof?)
(err/rt-test (readstr "#px#\"") exn:fail:read:eof?)
(err/rt-test (readstr "#px#a") exn:fail:read?)
(err/rt-test (readstr "#px#\"?\"") exn:fail:read?)

(test 2 vector-length (readstr "#2()"))
(test 0 vector-ref (readstr "#2()") 1)
(test 2 vector-length (readstr "#000000000000000000000000000000002()"))

(test 0 syntax->datum (vector-ref (syntax-e (read-syntax #f (open-input-string "#2()"))) 1))

(err/rt-test (readstr "#2(1 2 3)") exn:fail:read?)
(err/rt-test (readstr "#2000000000000000(1 2 3)") (readerrtype exn:fail:out-of-memory?))
(err/rt-test (readstr "#111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111x1(1 2 3)") exn:fail:read?)

(test #t (lambda (x) (eq? (car x) (cdr x))) (readstr "(#1=(1 2) . #0001#)"))
(test #t (lambda (x) (and (box? x) (eq? x (unbox x)))) (readstr "#0=#&#0#"))
(test #t (lambda (x) (and (vector? x) (eq? x (vector-ref x 0)) (eq? x (vector-ref x 1)))) (readstr "#0=#2(#0#)"))
(test #t (lambda (x) (and (vector? x) (eq? (vector-ref x 1) (vector-ref x 2)))) (readstr "#3(#0=(1 2) #0#)"))
(test '(1 1 1) readstr "(#0=1 #1=#0# #1#)")

(err/rt-test (read-syntax #f (open-input-string "(#0=1 #1=#0# #1#)")) exn:fail:read?)
(let ()
  (define (stx-placeholder-get* stx)
    (if (placeholder? (syntax-e stx))
        (stx-placeholder-get* (placeholder-get (syntax-e stx)))
        stx))

  (let ()
    (define stxs (syntax->list
                  (parameterize ([read-accept-graph #f]
                                 [read-syntax-accept-graph #t])
                    (read-syntax #f (open-input-string "(#0=1 #1=#0# #1#)")))))
    (test #t (lambda (xs) (andmap (lambda (x) (placeholder? (syntax-e x))) xs)) stxs)
    (test '(1 1 1) (lambda (xs) (map (lambda (x) (syntax-e (stx-placeholder-get* x))) xs)) stxs))

  (test #t
        (lambda (stx)
          (define lst-stx (placeholder-get (syntax-e stx)))
          (eq? lst-stx (placeholder-get (syntax-e (cdr (syntax-e lst-stx))))))
        (parameterize ([read-syntax-accept-graph #t])
          (read-syntax #f (open-input-string "#0=(1 . #0#)")))))

;; Show that syntax, expansion, etc. do not preserve vector sharing
(test #f 
      (lambda (x) (and (vector? x) (eq? (vector-ref x 0) (vector-ref x 1)))) 
      #2((1 2)))

;; Immutable vectors and boxes from `read-syntax`
(test #t immutable? (syntax-e (read-syntax #f (open-input-string "#(a b c)"))))
(test #t immutable? (syntax-e (read-syntax #f (open-input-string "#5(a b c)"))))
(test #t immutable? (syntax-e (read-syntax #f (open-input-string "#&a"))))
(test #f immutable? (read (open-input-string "#(a b c)")))
(test #f immutable? (read (open-input-string "#5(a b c)")))
(test #f immutable? (read (open-input-string "#&a")))

(define (graph-error-tests readstr graph-ok?)
  (err/rt-test (readstr "#0#") exn:fail:read?)
  (err/rt-test (readstr "#0=#0#") exn:fail:read?)
  (err/rt-test (readstr "#0=#0#") exn:fail:read?)
  (err/rt-test (readstr "(#0# #0=7)") exn:fail:read?)
  (err/rt-test (readstr "(#0=7 #1#)") exn:fail:read?)
  (err/rt-test (readstr "(#0=7 #0=7)") exn:fail:read?)
  (err/rt-test (readstr "#0=") (if graph-ok?
                                   exn:fail:read:eof?
                                   exn:fail:read?))
  (err/rt-test (readstr "#0") exn:fail:read:eof?)
  (err/rt-test (readstr "#012345678=7") exn:fail:read?)
  (err/rt-test (readstr "(#12345678=7 #012345678#)") exn:fail:read?)
  (err/rt-test (readstr "#111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111x1=(1 2 3)") exn:fail:read?)
  (parameterize ([read-accept-graph #f])
    (err/rt-test (readstr "#1=1") exn:fail:read?)
    (err/rt-test (readstr "#1#") exn:fail:read?)))
(graph-error-tests readstr #t)
(graph-error-tests (lambda (s)
		     (read-syntax "string" (open-input-string s)))
                   #f)

;; Long symbol:
(test 'abcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefg
      readstr "abcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefgabcdefg")

(test 3 string-length (readstr (string #\" #\a #\nul #\b #\")))
(test (string->symbol (string #\a #\nul #\b)) 'sym (readstr (string #\a #\nul #\b)))
(test (string->symbol (string #\1 #\nul #\b)) 'sym (readstr (string #\1 #\nul #\b)))

; Test read/write invariance on symbols and use of pipe quotes
(define (test-write-sym with-bar without-bar s)
  (let ([sym (string->symbol s)])
    (parameterize ([read-case-sensitive #t])
      (let ([p (open-output-string)])
	(write sym p)
	(test with-bar 'write-sym-with-bar (get-output-string p))
	(test sym read (open-input-string (get-output-string p))))
      (let ([p (open-output-string)])
	(parameterize ([read-accept-bar-quote #f])
	  (write sym p)
	  (test without-bar 'write-sym-no-bar (get-output-string p))
	  (test sym read (open-input-string (get-output-string p)))))
      (let ([p (open-output-string)])
	(display sym p)
	(test s 'display-sym (get-output-string p))))))

(test-write-sym "a->b" "a->b" "a->b")
(test-write-sym "|a,b|" "a\\,b" "a,b")
(test-write-sym "a\\|b" "a|b" "a|b")
(test-write-sym "|a\\b|" "a\\\\b" "a\\b")

(test 'a 'quote '\a)
(test '|\a| 'quote '\\a)
(test 'a 'quote '||||a||)
#ci(test (string->symbol "aaa") 'quote 'aAa)
#ci(test (string->symbol "aAa") 'quote 'A\AA)
#ci(test (string->symbol "aAa") 'quote '|aAa|)
#ci(test (string->symbol "aAa") 'quote 'A|A|A)

(load-relative "numstrs.rktl")
(let loop ([l number-table])
  (cond
   [(null? l) 'done]
   [(or (number? (caar l)) (memq (caar l) '(X DBZ NOE)))
    (test-write-sym (string-append "|" (cadar l) "|") 
		    (string-append "\\" (cadar l)) 
		    (cadar l))
    (loop (cdr l))]
   [else
    (test-write-sym (cadar l) (cadar l) (cadar l))
    (loop (cdr l))]))

(let ()
  (define BOM-utf8 (bytes #xEF #xBB #xBF))
  
  (test "it-works" symbol->string
        (read (open-input-bytes
               (bytes-append BOM-utf8 #"it-works"))))

  (test '(1 2 3) read (open-input-bytes
                       (bytes-append BOM-utf8
                                     #"(" BOM-utf8 BOM-utf8
                                     #"1" BOM-utf8
                                     #"2" BOM-utf8
                                     #"3" BOM-utf8 BOM-utf8 #")"
                                     BOM-utf8)))

  (test #t procedure?
        (parameterize ([read-accept-reader #t])
          (read-language (open-input-bytes
                          (bytes-append BOM-utf8 #"#lang racket/base"))))))

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Test mid-stream EOF

(define (test-mid-stream-eof use-peek?)
(define no-peek? #f)
  (define chars (map (lambda (x)
		       (if (char? x) (char->integer x) x))
		     (append
		      (string->list "1 2")
		      (list eof)
		      (string->list "\"a\" \"b\"")
		      (list eof)
		      (string->list "(a) (b)")
		      (list eof)
		      (string->list "eof"))))
  (define cp (make-input-port
	      'mid-stream
	      (lambda (b)
		(if (null? chars)
		    eof
		    (let ([c (car chars)])
		      (set! chars (cdr chars))
		      (cond 
		       [(eof-object? c)
			eof]
		       [else
			(bytes-set! b 0 c)
			1]))))
	      (and use-peek?
		   (lambda (b skip progress-evt)
		     (when (positive? skip)
		       (error 'ouch!))
		     (if (null? chars)
			 eof
			 (let ([c (car chars)])
			   (cond 
			    [(eof-object? c)
			     eof]
			    [else
			     (bytes-set! b 0 c)
			     1])))))
	      void))
  (define (f) (read cp))

  (test 1 f)
  (test 2 f)
  (test eof f)
  (test "a" f)
  (test "b" f)
  (test eof f)
  (test '(a) f)
  (test '(b) f)
  (test eof f)
  (test 'eof f)
  (test eof f)
  (test eof f))

(test-mid-stream-eof #f)
(test-mid-stream-eof #t)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Test non-character results for getc

(define-struct special (size))

(define a-special (make-special 1))
(define b-special (make-special 1))
(define special-comment (make-special 1))

(define (make-p stream special-size check-pos)
  ;; The `stream' arg is a list of strings and non-strings;
  ;;  characters from the strings are returned one by one,
  ;;  and the non-strings are returns as "special" literals.
  ;; The `special-size' arg meansures the size (in char
  ;;  positions) of a non-string special literal.
  (let* ([pos 0]
	 [incpos! (lambda () (set! pos (add1 pos)))]
	 [read-one (lambda (str)
		     (let loop ([s stream][p pos])
		       (if (null? s)
			   eof
			   (let ([i (car s)])
			     (if (bytes? i)
				 (if ((bytes-length i) . > . p)
				     (begin
				       (incpos!)
				       (bytes-set! str 0 (bytes-ref i p))
				       1)
				     (loop (cdr s) (- p (bytes-length i))))
				 ;; a special:
				 (cond
				  [(zero? p) (incpos!)
				   (if (and (number? i) 
					    (or (inexact? i)
						(negative? i)))
				       i ; creates an error
				       (lambda (where line col pos)
					 (check-pos where line col pos)
					 (cond
					  [(symbol? i) (i)]
					  [(eq? i special-comment)
					   (make-special-comment i)]
					  [(number? i)
					   (if (inexact? i)
					       (make-special-comment i)
					       'aha)]
					  [else i])))]
				  [else (loop (cdr s) (sub1 p))]))))))])
    (make-input-port
     'specializer
     ;; Non-blocking read string:
     (lambda (str)
       (read-one str))
     ;; Peek char
     (lambda (str skip progress-evt)
       (let ([old-p pos])
	 (let loop ([skip skip])
	   (unless (zero? skip)
	     (read-one str)
	     (loop (sub1 skip))))
	 (begin0
	  (read-one str)
	  (set! pos old-p))))
     ;; Close proc
     (lambda () #t))))

;; Read without specials:
(let* ([p (make-p `(#"(list "
		    #"a"
		    #" "
		    #"b"
		    #"))")
		  special-size
		  (lambda (w l c p)
		    (error "shouldn't get here")))]
       [_ (port-count-lines! p)]
       [v (syntax-e (read-syntax 'ok p))])
  (test 'list syntax-e (car v))
  (test 'a syntax-e (cadr v))
  (test 'b syntax-e (caddr v))
  (test 1 syntax-line (car v))
  (test 1 syntax-column (car v))
  (test 1 syntax-line (cadr v))
  (test 6 syntax-column (cadr v))
  (test 1 syntax-line (caddr v))
  (test 8 syntax-column (caddr v)))

;; Without specials, with newlines:
(let* ([p (make-p `(#"(list\n"
		    #"a"
		    #"\n"
		    #"b"
		    #"))")
		  special-size
		  (lambda (w l c p)
		    (error "shouldn't get here")))]
       [_ (port-count-lines! p)]
       [v (syntax-e (read-syntax 'ok p))])
  (test 'list syntax-e (car v))
  (test 'a syntax-e (cadr v))
  (test 'b syntax-e (caddr v))
  (test 1 syntax-line (car v))
  (test 1 syntax-column (car v))
  (test 2 syntax-line (cadr v))
  (test 0 syntax-column (cadr v))
  (test 3 syntax-line (caddr v))
  (test 0 syntax-column (caddr v)))
  
;; Simple read:
(let* ([p (make-p `(#"(list "
		    ,a-special
		    #" "
		    ,b-special
		    #"))")
		  special-size
		  (lambda (w l c p)
		    (test #f 'no-place1 w)
		    (test 1 'no-place2 l)
		    (test (and p (sub1 p)) 'no-place3 c)
		    (test #f not (memq p '(7 9)))))]
       [_ (port-count-lines! p)]
       [v (read p)])
  (test 'list car v)
  (test a-special cadr v)
  (test b-special caddr v))

;; Read with newlines
(let* ([p (make-p `(#"(list\n"
		    ,a-special
		    #"\n"
		    ,b-special
		    #"))")
		  special-size
		  (lambda (w l c p)
		    (test l 'no-place4 l)
		    (test #f 'no-place5 w)
		    (test 0 'no-place6 c)
		    (test #f not (memq p '(7 9)))
		    (test #f not (memq l '(2 3)))))]
       [_ (port-count-lines! p)]
       [v (read p)])
  (test 'list car v)
  (test a-special cadr v)
  (test b-special caddr v))

(require (only-in racket/port [relocate-input-port relocate-input-port]))
(define (shift-port p count-lines? deltas)
  (let ([p (relocate-input-port p 
				(add1 (car deltas))
				(cadr deltas)
				(add1 (caddr deltas)))])
    (when count-lines?
      (port-count-lines! p))
    p))

;; Read with src loc:
(let* ([p (make-p `(#"(list "
		    ,a-special
		    #" "
		    ,b-special
		    #" end))")
		  special-size
		  (lambda (w l c p)
		    (test 'dk 'dk-place w)
		    (test 8 'no-place7 l)
		    (test p + c 631)
		    (test #f not (memq p '(707 709)))))]
       [_ (port-count-lines! p)]
       [v (read-syntax 'dk (shift-port p #t '(7 70 700)))]
       [l (syntax->list v)]
       [v2 (syntax->datum v)])
  (test 'list car v2)
  (test a-special cadr v2)
  (test b-special caddr v2)
  (test 'end cadddr v2)
  
  (test 702 syntax-position (car l))
  (test 707 syntax-position (cadr l))
  (test 709 syntax-position (caddr l))
  (test 711 syntax-position (cadddr l))

  ;; Read with specials as syntax syntax already:
  (let* ([stx v]
	 [p (make-p `(#"(list "
		      ,stx
		      #" end))")
		    (lambda (x)
		      ;; it's 1 wide
		      1)
		    (lambda (w l c p)
		      (test 'dk 'dk-place w)
		    (test #f 'no-place8 l)
		    (test #f 'no-place9 c)
		    (test 7 'place p)))]
	 [v (read-syntax 'dk p)]
	 [l (syntax->list v)])
    ;; make sure syntax object is intact:
    (test stx cadr l)
    (test 9 syntax-position (caddr l))

    ;; Check that plain read performs a syntax->datum:
    (let* ([p (make-p `(#"(list "
			,stx
			#" end))")
		      (lambda (x) 100)
		    (lambda (w l c p)
		      (test #f 'no-place10 w)
		      (test #f 'no-place11 l)
		      (test #f 'no-place12 c)
		      (test 7 'place p)))]
	   [v (read p)])
      (test `(list (list ,a-special ,b-special end) end) values v))))

;; Check that syntax read with with a list special
;;  syntaxizes the list.
(let* ([p (make-p `(#"(list "
		    ,(list a-special b-special)
		    #" end))")
		  (lambda (x)
		    1)
		  (lambda (w l c p)
		    (test 'dk 'dk-place w)
		    (test #f 'no-place13 l)
		    (test #f 'no-place14 c)
		    (test 7 'place p)))]
       [v (read-syntax 'dk p)]
       [l (syntax->list v)])
  (test #t syntax? (cadr l))
  (test #t list? (syntax-e (cadr l)))
  (test a-special syntax-e (car (syntax-e (cadr l))))
  (test b-special syntax-e (cadr (syntax-e (cadr l))))
  (test 9 syntax-position (caddr l)))

;; Test delimitting and unsupported positions:
(test (list 1 a-special) read (make-p (list #"(1" a-special #")") (lambda (x) 1) void))
(test (list 1) read (make-p (list #"(1" special-comment #")") (lambda (x) 1) void))
(test (list 'a a-special 'b) read (make-p (list #"(a" a-special #"b)") (lambda (x) 1) void))
(test (list #\a a-special) read (make-p (list #"(#\\a" a-special #")") (lambda (x) 1) void))
(test (list #\newline a-special) read (make-p (list #"(#\\newline" a-special #")") (lambda (x) 1) void))
(test (list #\newline) read (make-p (list #"(#\\newline" special-comment #")") (lambda (x) 1) void))
(test a-special read-char-or-special (make-p (list a-special) (lambda (x) 1) void))

;; Type error triggered by symbol 'z --- make sure it's propagated:
(err/rt-test (read (make-p (list #"(a" 'z #")") (lambda (x) 1) void)))
;; Negative number triggers bad special result:
(err/rt-test (read (make-p (list #"(a" -42 #")") (lambda (x) 1) void)))
;; Inexact number triggers bad special-comment result:
(err/rt-test (read (make-p (list #"(a" 42.0 #")") (lambda (x) 1) void)))

(define (run-delim-special a-special)
  (test (list 5) read (make-p (list #"(; \"" a-special #"\n5)") (lambda (x) 1) void))
  (test (list 5) read (make-p (list #"(#| \"" a-special #" |# 5)") (lambda (x) 1) void))
  (test (list 5) read (make-p (list #"(;" a-special #"\n 5)") (lambda (x) 1) void))
  (test 5 read (make-p (list #"#| \"" a-special #" |# 5") (lambda (x) 1) void))
  (test 5 read (make-p (list #";" a-special #"\n 5") (lambda (x) 1) void))
  (err/rt-test (read (make-p (list #"\"a" a-special #"\"") (lambda (x) 1) void)) exn:fail:read:non-char?)
  (err/rt-test (read (make-p (list #"\"" a-special #"\"") (lambda (x) 1) void)) exn:fail:read:non-char?)
  (err/rt-test (read (make-p (list #"\"\\" a-special #"\"") (lambda (x) 1) void)) exn:fail:read:non-char?)
  (err/rt-test (read (make-p (list #"\"\\x" a-special #"\"") (lambda (x) 1) void)) exn:fail:read:non-char?)
  (err/rt-test (read (make-p (list #"\"\\x1" a-special #"\"") (lambda (x) 1) void)) exn:fail:read:non-char?)
  (err/rt-test (read (make-p (list #"#\\" a-special #"") (lambda (x) 1) void)) exn:fail:read:non-char?)
  (err/rt-test (read (make-p (list #"#\\12" a-special #"") (lambda (x) 1) void)) exn:fail:read:non-char?)
  (err/rt-test (read (make-p (list #"#" a-special #"") (lambda (x) 1) void)) exn:fail:read:non-char?)
  (err/rt-test (read (make-p (list #"x\\" a-special #"y") (lambda (x) 1) void)) exn:fail:read:non-char?)
  (err/rt-test (read (make-p (list #"|" a-special #"y|") (lambda (x) 1) void)) exn:fail:read:non-char?)
  (err/rt-test (read (make-p (list #"|x" a-special #"y|") (lambda (x) 1) void)) exn:fail:read:non-char?))
(run-delim-special a-special)
(run-delim-special special-comment)
(parameterize ([current-readtable (make-readtable #f)])
  (run-delim-special special-comment))

(require racket/flonum
         racket/fixnum)

(define (run-comment-special [special-comment special-comment]
                             #:skip-num? [skip-num? #f])
  (test (list 5) read (make-p (list #"(" special-comment #"5)") (lambda (x) 1) void))
  (test (list 5) read (make-p (list #"(5" special-comment #")") (lambda (x) 1) void))
  (test (cons 1 5) read (make-p (list #"(1 . " special-comment #"5)") (lambda (x) 1) void))
  (test (cons 1 5) read (make-p (list #"(1 . 5" special-comment #")") (lambda (x) 1) void))
  (err/rt-test (read (make-p (list #"(1 . " special-comment #")") (lambda (x) 1) void)) exn:fail:read?)
  (test (list 2 1 5) read (make-p (list #"(1 . 2 . " special-comment #"5)") (lambda (x) 1) void))
  (test (list 2 1 a-special 5) read (make-p (list #"(1 . 2 ." a-special #"5)") (lambda (x) 1) void))
  (test (list 2 1 5) read (make-p (list #"(1 . " special-comment #"2 . 5)") (lambda (x) 1) void))
  (test (list 2 1 5) read (make-p (list #"(1 . 2 " special-comment #" . 5)") (lambda (x) 1) void))
  (test (vector 1 2 5) read (make-p (list #"#(1 2 " special-comment #"5)") (lambda (x) 1) void))
  (unless skip-num?
    (test (flvector 1.0) read (make-p (list #"#fl(1.0 " special-comment #")") (lambda (x) 1) void))
    (test (fxvector 1) read (make-p (list #"#fx(1 " special-comment #")") (lambda (x) 1) void)))
  (test (hash 1 'a) read (make-p (list #"#hash(" special-comment #"(1 . a))") (lambda (x) 1) void))
  (test (hash 1 'a) read (make-p (list #"#hash((" special-comment #"1 . a))") (lambda (x) 1) void))
  (test (hash 1 'a) read (make-p (list #"#hash((1 " special-comment #". a))") (lambda (x) 1) void))
  (test (hash 1 'a) read (make-p (list #"#hash((1 ." special-comment #" a))") (lambda (x) 1) void))
  (test (hash 1 'a) read (make-p (list #"#hash((1 . a" special-comment #"))") (lambda (x) 1) void))
  (test (hash 1 'a) read (make-p (list #"#hash((1 . a)" special-comment #")") (lambda (x) 1) void))
  (err/rt-test (read (make-p (list #"#fl(1.0 " a-special #")") (lambda (x) 1) void)) exn:fail:read?)
  (err/rt-test (read (make-p (list #"#fx(1 " a-special #")") (lambda (x) 1) void)) exn:fail:read?))
(run-comment-special)
(parameterize ([current-readtable (make-readtable #f)])
  (run-comment-special))
(parameterize ([current-readtable (make-readtable #f
                                                  #\* 'terminating-macro (lambda args
                                                                           (make-special-comment #f)))])
  (run-comment-special #"*"))
(parameterize ([current-readtable (make-readtable #f
                                                  #\* 'dispatch-macro (lambda args
                                                                        (make-special-comment #f)))])
  (run-comment-special #" #* " #:skip-num? #t))

(let ()
  ;; check that minimal characters are read to determine that wrong
  ;; characters won't produce a comment via the readtable
  (define (check-consumed s n [read read])
    (define i (open-input-bytes s))
    (err/rt-test/once (read i) exn:fail:read?)
    (test n file-position i))
  (check-consumed #"(1 . x yzq)" 8)
  (parameterize ([current-readtable (make-readtable #f
                                                    #\y 'terminating-macro (lambda (ch in . args)
                                                                             (read-char in)))])
    (check-consumed #"(1 . x yzq)" 9))
  (check-consumed #"(1 . x #yzq)" 8)
  (parameterize ([current-readtable (make-readtable #f
                                                    #\y 'dispatch-macro (lambda (ch in . args)
                                                                          (read-char in)))])
    (check-consumed #"(1 . x #yzq)" 10))
  (check-consumed #"#hash(yzq)" 7)
  (check-consumed #"#hash(#yzq)" 7)
  (check-consumed #"yzq #lang" 1 read-language)
  (check-consumed #"#yzq #lang" 2 read-language))

;; Test read-char-or-special:
(let ([p (make-p (list #"x" a-special #"y") (lambda (x) 5) void)])
  (test #\x peek-char-or-special p)
  (test 0 file-position p)
  (test #\x peek-char-or-special p 0)
  (test a-special peek-char-or-special p 1)
  (test #\y peek-char-or-special p 2)
  (test 0 file-position p)
  (test #\x read-char-or-special p)
  (test 1 file-position p)
  (test a-special peek-char-or-special p)
  (test 1 file-position p)
  (test a-special read-char-or-special p)
  (test 2 file-position p)
  (test #\y peek-char-or-special p)
  (test 2 file-position p)
  (test #\y read-char-or-special p)
  (test 3 file-position p))

;; Test read-char-or-special:
(let ([p (make-p (list #"x" a-special #"y") (lambda (x) 5) void)])
  (test #\x peek-char-or-special p)
  (test 0 file-position p)
  (test #\x peek-char-or-special p 0)
  (test a-special peek-char-or-special p 1)
  (test #\y peek-char-or-special p 2)
  (test 0 file-position p)
  (test #\x read-char-or-special p)
  (test 1 file-position p)
  (test a-special peek-char-or-special p)
  (test 1 file-position p)
  (test a-special read-char-or-special p)
  (test 2 file-position p)
  (test #\y peek-char-or-special p)
  (test 2 file-position p)
  (test #\y read-char-or-special p)
  (test 3 file-position p))

;; Reading something like a symbol should stop at a special
;; without calling the special-producing procedure:
(let* ([pos 0]
       [p (make-input-port
           'voids
           (lambda (s)
             (if (pos . < . 3)
                 (begin
                   (set! pos (add1 pos))
                   (bytes-set! s 0 (char->integer #\a))
                   1)
                 (lambda args (error "oops/read"))))
           (lambda (s skip progress-evt)
             (cond
              [((+ skip pos) . < . 3)
               (begin
                 (bytes-set! s 0 (char->integer #\a))
                 1)]
              [((+ skip pos) . < . 4)
               (lambda args (error "oops/peek"))]
              [else eof-object]))
           void)])
  (test 'aaa read p))

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Test read-syntax offsets:

(let ([p (open-input-string " a ")])
  (let ([v (read-syntax 'ok (shift-port p #f (list 70 700 7000)))])
    (test #f syntax-line v)
    (test #f syntax-column v)
    (test 7002 syntax-position v)))

(let ([p (open-input-string " a ")])
  (port-count-lines! p)
  (let ([v (read-syntax 'ok (shift-port p #t (list 70 700 7000)))])
    (test 71 syntax-line v)
    (test 701 syntax-column v)
    (test 7002 syntax-position v)))

(let ([p (open-input-string " \n a ")])
  (port-count-lines! p)
  (let ([v (read-syntax 'ok (shift-port p #t (list 70 700 7000)))])
    (test 72 syntax-line v)
    (test 1 syntax-column v)
    (test 7004 syntax-position v)))

;; Check exception record:
(let ([p (open-input-string " . ")])
  (let ([x (with-handlers ([values values])
	     (read-syntax 'ok (shift-port p #f (list 70 700 7000))))])
    (test 'ok srcloc-source (car (exn:fail:read-srclocs x)))
    (test #f srcloc-line (car (exn:fail:read-srclocs x)))
    (test #f srcloc-column (car (exn:fail:read-srclocs x)))
    (test 7002 srcloc-position (car (exn:fail:read-srclocs x)))))
    
(let ([p (open-input-string " . ")])
  (port-count-lines! p)
  (let ([x (with-handlers ([values values])
	     (read-syntax 'ok (shift-port p #t (list 70 700 7000))))])
    (test 'ok srcloc-source (car (exn:fail:read-srclocs x)))
    (test 71 srcloc-line (car (exn:fail:read-srclocs x)))
    (test 701 srcloc-column (car (exn:fail:read-srclocs x)))
    (test 7002 srcloc-position (car (exn:fail:read-srclocs x)))))

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(let ([p (open-output-bytes)])
  (display void p)
  (test "#<procedure:void>" get-output-string p)
  (let ([try-bad
	 (lambda (x)
	   (test (void) (list x)
		 (parameterize ([print-unreadable #f])
		   (display x p)))
	   (err/rt-test (parameterize ([print-unreadable #f])
			  (write x p))
                        exn:fail?))]
	[try-good
	 (lambda (x)
	   (test (void) (list x)
		 (parameterize ([print-unreadable #f])
		   (write x p))))])
    (try-bad void)
    (try-bad (lambda () 10))
    (try-bad (seconds->date (current-seconds)))
    (try-bad (let ()
	   (define-struct s (x))
	   (make-s 10)))
    (try-bad #'apple)
    
    (try-good 'ex)
    (try-good '(1 ex))
    (try-good '(1 . ex))
    (try-good #(1 2))
    (try-good #&(1))
    (try-good 1)
    (try-good 1.0)
    (try-good "apple")
    (try-good #"apple")
    (try-good #rx"ok")
    (try-good #rx#"ok")
    (try-good #f)))

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Test #reader

(err/rt-test (parameterize ([read-accept-reader #f])
	       (read (open-input-string "#reader racket/base 10")))
	     exn:fail:read?)
(test 10 'ten (parameterize ([read-accept-reader #t])
	       (read (open-input-string "#reader racket/base 10"))))

(module reader-test-module racket/base
  (define (my-read port)
    `(READ ,(read port)))
  (define (my-read-syntax name port)
    `(READ-SYNTAX ,(read-syntax name port)))
  (provide (rename-out [my-read read]
                       [my-read-syntax read-syntax])))

(test `(READ 10) 'ten 
      (parameterize ([read-accept-reader #t])
	(read (open-input-string "#reader 'reader-test-module 10"))))
(test `(READ-SYNTAX 10) 'ten 
      (syntax->datum
       (parameterize ([read-accept-reader #t])
	 (read-syntax '??? (open-input-string "#reader 'reader-test-module 10")))))

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Test 'paren-shape property

(test #f syntax-property (read-syntax 'x (open-input-string "(1 2 3)")) 'paren-shape)
(test #\[ syntax-property (read-syntax 'x (open-input-string "[1 2 3]")) 'paren-shape)
(test #\[ syntax-property (read-syntax 'x (open-input-string "[1 . 3]")) 'paren-shape)
(test #\[ syntax-property (read-syntax 'x (open-input-string "[1 . 3 . 2]")) 'paren-shape)
(test #\[ syntax-property (read-syntax 'x (open-input-string "#[1 2]")) 'paren-shape)
(test #\{ syntax-property (read-syntax 'x (open-input-string "{1 2 3}")) 'paren-shape)
(test #\{ syntax-property (read-syntax 'x (open-input-string "#{1 2}")) 'paren-shape)

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Check `read/recursive`

(let ()
  (define in (open-input-string "abc"))
  (test 'abc read/recursive in))

(let ()
  (define in2 (open-input-string "(#0=(abc) #z(#0#))"))
  (parameterize ([current-readtable
                  (make-readtable (current-readtable)
                                  #\z
                                  'dispatch-macro
                                  (lambda (char in name line col pos)
                                    (define v (read/recursive in))
                                    v))])
    (define v (read in2))
    (test '((abc) ((abc))) values v)
    (test #t eq? (car v) (caadr v))))

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Test read error on a character not in any port

(err/rt-test (read/recursive (open-input-string ";") #\. #f) exn:fail:read?)

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Some hash-table reading trickyness with readtables

(test #hash((apple . (red round))
            (banana . (yellow long)))
      values
      (parameterize ([current-readtable
                      (make-readtable #f
                                      #\! 'terminating-macro (lambda (ch port . args)
                                                               (read/recursive port)))])
        (read (open-input-string
               "!#hash((apple . (red round)) (banana . (yellow long)))"))))

(test #hash((apple . (red round))
            (banana . (yellow long)))
      values
      (parameterize ([current-readtable
                      (make-readtable #f
                                      #\! 'terminating-macro (lambda (ch port . args)
                                                               (read/recursive port))
                                      #\* 'terminating-macro (lambda args
                                                               (make-special-comment #f)))])
        (read (open-input-string
               "!#hash((apple . (red round)) * (banana . (yellow long)))"))))

(test #t hash?
      (parameterize ([current-readtable
                      (make-readtable #f
                                      #\% 'terminating-macro
                                      (lambda (char port . args)
                                        (let ([v (read/recursive port)])
                                          v)))])
        (let ([ht (read (open-input-string "#0=' % % #hash((a . #0#) (b . \"banana\"))"))])
          (cadr (hash-ref (cadr ht) 'a)))))

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(parameterize ([read-accept-dot #f])
  (err/rt-test (read (open-input-string ".")) exn:fail:read?))
(parameterize ([current-readtable (make-readtable (current-readtable) #\. #\a #f)])
  (test '|.| read (open-input-string ".")))
(parameterize ([current-readtable (make-readtable (current-readtable) #\. #\a #f)]
               [read-accept-dot #f])
  (test '|.| read (open-input-string ".")))
(parameterize ([read-accept-dot #f]
               [current-readtable (make-readtable (current-readtable) #\w #\. #f)])
  (err/rt-test (read (open-input-string "w")) exn:fail:read?))
(parameterize ([current-readtable (make-readtable (current-readtable) #\w #\. #f)])
  (err/rt-test (read (open-input-string "w")) exn:fail:read?))

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(let ([s "#0=(1 #hasheq((#0# . (1))) 2 . #&(3 #(#0#)))"])
  (test s
        format
        "~s"
        (make-reader-graph (let ([p (make-placeholder #f)]) 
                             (placeholder-set! p (list* 1
                                                        (make-immutable-hasheq (list (list p 1))) 
                                                        2 
                                                        (box (list 3 (vector p))))) 
                             p)))
  (test s format "~s" (read (open-input-string s))))

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Prefab

(test #t struct? (readstr "#s(v)"))
(test #t struct? (readstr "#s(v 1)"))
(test #t struct? (readstr "#s((v 1) 1)"))
(test #t struct? (readstr "#s((v 1 #()) 1)"))
(test #t struct? (readstr "#s((v 0 (1 #f) #()) 1)"))
(test #t struct? (readstr "#s((v (1 #f) #()) 1)"))
(test #t struct? (readstr "#s((v #(0)) 1)"))
(test #t struct? (readstr "#0=#s(v #0#)"))
(let ([v1 (readstr "#0=#s(v #0#)")])
  (define-struct v (self) #:prefab)
  (test #t eq? v1 (v-self v1)))
(err/rt-test (readstr "#s((v 2) 1)") exn:fail:read?)
(err/rt-test (readstr "#s((v 0) 1)") exn:fail:read?)
(err/rt-test (readstr "#s((v 0) 1)") exn:fail:read?)
(err/rt-test (readstr "#s((v 1 (1 #f) #()) 1)") exn:fail:read?)
(err/rt-test (readstr "#s((v 0 (2 #f) #()) 1)") exn:fail:read?)
(err/rt-test (readstr "#s((v 0 (2 #f) #(0)) 1)") exn:fail:read?)

(err/rt-test (readstr "#s(1 2)") (lambda (x)
                                   (and (exn:fail:read? x)
                                        (not (exn:fail:read:eof? x)))))
(err/rt-test (readstr "#s(1 2") exn:fail:read:eof?)
(err/rt-test (read-syntax 's (open-input-string "#s((a #(0)) 1)"))
             (lambda (x)
               (and (exn:fail:read? x)
                    (not (exn:fail:read:eof? x)))))

(test #t struct? (syntax-e (read-syntax 'string (open-input-string "#s(v)"))))

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; read-language

(test #t procedure? (read-language (open-input-string "#lang racket/base")))
(test #t procedure? (read-language (open-input-string ";;\n#lang racket/base")))
(test #t procedure? (read-language (open-input-string ";;\n#|\n\n   |#\n#lang racket/base")))
(test #t procedure? (read-language (open-input-string "#! /bin/env \n#lang racket/base")))
(test #t procedure? (read-language (open-input-string "#!/bin/env \n#lang racket/base")))
(test #t procedure? (read-language (open-input-string "#!racket/base")))
(let ([check-nothing
       (lambda (str exn?)
         (err/rt-test (read-language (open-input-string str)) exn?)
         (test 'no read-language (open-input-string str) (lambda () 'no)))])
  (check-nothing "" exn:fail:read:eof?)
  (check-nothing ";" exn:fail:read:eof?)
  (check-nothing "#| |#" exn:fail:read:eof?)
  (check-nothing "8 9" exn:fail:read?))
(err/rt-test (read-language (open-input-string "#l") void) exn:fail:read:eof?)
(err/rt-test (read-language (open-input-string "#la") void) exn:fail:read:eof?)
(err/rt-test (read-language (open-input-string ";;\n;\n#la") void) exn:fail:read:eof?)
(err/rt-test (read-language (open-input-string ";;\n;\n#lx") void) exn:fail:read?)
(test (void) read-language (open-input-string ";;\n;\n#xa") void)
;; Check error-message formatting:
(err/rt-test (read (open-input-string "#l"))
             (lambda (exn) (regexp-match? #rx"`#l`" (exn-message exn))))
;; Make sure read-language error here is this can comes from read-language
;; and not from an ill-formed srcloc construction:
(let ()
  (define p (open-input-string ";\n"))
  (port-count-lines! p)
  (err/rt-test (read-language p)
               (lambda (exn) (regexp-match? #rx"read-language" (exn-message exn)))))

(parameterize ([read-accept-reader #t])
  (err/rt-test (read (open-input-string "#lang"))
               (lambda (exn) (regexp-match? #rx"expected a single space" (exn-message exn))))
  (err/rt-test (read (open-input-string "#lang "))
               (lambda (exn) (regexp-match? #rx"expected a non-empty sequence of" (exn-message exn))))
  (err/rt-test (read (open-input-string "#lang  "))
               (lambda (exn) (regexp-match? #rx"expected a single space" (exn-message exn))))
  (err/rt-test (read (open-input-string "#lang  x"))
               (lambda (exn) (regexp-match? #rx"expected a single space" (exn-message exn))))
  (err/rt-test (read (open-input-string "#lang ."))
               (lambda (exn) (regexp-match? #rx"expected only" (exn-message exn))))
  (err/rt-test (read (open-input-string "#lang x."))
               (lambda (exn) (regexp-match? #rx"expected only" (exn-message exn))))
  (err/rt-test (read (open-input-string "#lang \n"))
               (lambda (exn) (regexp-match? #rx"expected only" (exn-message exn))))
  (err/rt-test (read (open-input-string "#lang \nx"))
               (lambda (exn) (regexp-match? #rx"expected only" (exn-message exn)))))

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(require racket/flonum
         racket/fixnum)
(test #t flvector? (readstr "#fl(1.5 0.33 0.3)"))
(test #t fxvector? (readstr "#fx(1000 76 100000)"))
(test #t fxvector? (readstr "#fx(#x10 #X10 #d9 #D9 #b111 #B111 #o77 #O77)"))
(err/rt-test (readstr "#fx(4.2235 4.2235)") exn:fail:read?)
(test #t equal? (flvector 1.5 0.33 0.3 0.3 0.3 0.3 0.3 0.3 0.3 0.3) (readstr "#fl10(1.5 0.33 0.3)"))
(test #t equal? (fxvector 1000 76 100000 100000 100000 100000 100000 100000 100000 100000) (readstr "#fx10(1000 76 100000)"))
(test #t equal? (flvector 0.0 0.0 0.0) (readstr "#fl3()"))
(test #t equal? (flvector 2.0 1.0 1.0) (readstr "#fl3(2 1)"))
(test #t equal? (flvector 2.0 1.0) (readstr "#fl(2 #;5 1)"))
(test #t equal? (flvector 2.0 1.0) (readstr "#fl(2 #|5|# 1)"))
(test #t equal? (flvector 2.0 1.0) (readstr "#fl(2 ;5\n 1)"))
(test #t equal? (fxvector 0 0 0) (readstr "#fx3()"))
(test #t equal? (fxvector 2 1 1) (readstr "#fx3(2 1)"))

(err/rt-test (readstr "#fl(1.5") exn:fail:read:eof?)
(err/rt-test (readstr "#fl(1.5 0.33 0.3 (1 2))") exn:fail:read?)
(err/rt-test (readstr "#fx(1000 76 100000 (1 2))") exn:fail:read?)
(err/rt-test (readstr "#fl(1.5 0.33 0.3 'a)") exn:fail:read?)
(err/rt-test (readstr "#fx(1000 76 100000 'a)") exn:fail:read?)
(err/rt-test (readstr "#fli(1.5 0.33 0.3 'a)") exn:fail:read?)
(err/rt-test (readstr "#fxi(1000 76 100000 'a)") exn:fail:read?)
(err/rt-test (readstr "#fi(1000 76 100000 'a)") exn:fail:read?)
(err/rt-test (readstr "#fx(1 . 2)") exn:fail:read?)
(err/rt-test (readstr "#fx(1 . 2 . 3)") exn:fail:read?)

(err/rt-test (read-syntax 'x (open-input-string "#fx()")) exn:fail:read?)
(err/rt-test (read-syntax 'x (open-input-string "#fl()")) exn:fail:read?)

(parameterize ([current-readtable (make-readtable
                                   #f
                                   #f 'non-terminating-macro (lambda args 3.0))])
  (test #t equal? (flvector 3.0) (readstr "#fl(3)")))

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(require racket/extflonum)

(test #t extflonum? (readstr "0.0t0"))
(test #t extflonum? (readstr "-0.0t0"))
(test #t extflonum? (readstr "3.0t0"))
(test #t extflonum? (readstr "#b1.0t0"))
(test #t extflonum? (readstr "#d3.0t0"))
(test #t extflonum? (readstr "#o3.0t0"))
(test #t extflonum? (readstr "#x3.0t0"))
(test #f string->number "3.0t0")

(test #t extflonum? (parameterize ([read-decimal-as-inexact #f])
                      (readstr "3.0t0")))

(when (extflonum-available?)
  (test 3t0 readstr "3.0t0")
  (test 3t0 readstr "#b11.0t0")
  (test 9t0 readstr "#o11.0t0")
  (test 17t0 readstr "#x11.0t0"))

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; read-cdot

(parameterize ([read-cdot #true])
  (test '(#%dot a b)                     readstr "a.b")
  (test '(#%dot (#%dot a b) c)           readstr "a.b.c")
  (test '(#%dot (#%dot (#%dot a b) c) d) readstr "a.b.c.d")
  (test '(#%dot a (#%dot b c))           readstr "a.(#%dot b c)")
  (test '(#%dot a (m b c))               readstr "a.(m b c)")
  (test '(#%dot (#%dot a (m b c)) (n d e)) readstr "a.(m b c).(n d e)")
  (test '(#%dot (#%dot (#%dot (#%dot (#%dot a (m b c)) x) (n d e)) y) z)
        readstr "a.(m b c).x.(n d e).y.z")
  (test '(#%dot (f a) b)                     readstr "(f a).b")
  (test '(#%dot (#%dot (f a) b) c)           readstr "(f a).b.c")
  (test '(#%dot (#%dot (#%dot (f a) b) c) d) readstr "(f a).b.c.d")
  (test '(#%dot (f a) (#%dot b c))           readstr "(f a).(#%dot b c)")
  (test '(#%dot (f a) (m b c))               readstr "(f a).(m b c)")
  (test '(#%dot (#%dot (f a) (m b c)) (n d e)) readstr "(f a).(m b c).(n d e)")
  (test '(#%dot (#%dot (#%dot (#%dot (#%dot (f a) (m b c)) x) (n d e)) y) z)
        readstr "(f a).(m b c).x.(n d e).y.z")
  (test '(#%dot 1.2 a) readstr "#i1.2 .a")
  (test '(#%dot 1.0 a) readstr "#b1.0 .a")
  (test '(#%dot 1.25 a) readstr "#o1.2 .a")
  (test '(#%dot 1.2 a) readstr "#d1.2 .a")
  (test '(#%dot 1.125 a) readstr "#x1.2 .a")
  (test '(#%dot (#%dot 1 2) a) readstr "1.2 .a")
  (test 'a.b readstr "|a.b|")
  (test 'a.b readstr "a|.|b")
  (test 'a.b readstr "a|.b|")
  (test 'a.b readstr "a\\.b")
  (err/rt-test (readstr "x.") exn:fail:read:eof?)
  (err/rt-test (readstr "1.") exn:fail:read:eof?))

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; srcloc->string

(test "x.rkt" srcloc->string (make-srcloc "x.rkt" #f #f #f #f))
(test "x.rkt::90" srcloc->string (make-srcloc "x.rkt" #f #f 90 #f))
(test "x.rkt" srcloc->string (make-srcloc "x.rkt" #f 80 #f #f))

(test "x.rkt::90" srcloc->string (make-srcloc "x.rkt" #f 80 90 #f))
(test "x.rkt::90" srcloc->string (make-srcloc "x.rkt" 70 #f 90 #f))
(test "x.rkt:70:80" srcloc->string (make-srcloc "x.rkt" 70 80 #f #f))
(test "x.rkt:70:80" srcloc->string (make-srcloc "x.rkt" 70 80 90 #f))

(test "x.rkt:10:11" srcloc->string (make-srcloc "x.rkt" 10 11 100 8))
(test "x.rkt::100" srcloc->string (make-srcloc "x.rkt" #f #f 100 8))
(test "x.rkt::100" srcloc->string (chaperone-struct (make-srcloc "x.rkt" #f #f 100 8)
                                                    srcloc-line (lambda (s v) v)))
(err/rt-test (srcloc->string 1))

(let ([go (lambda (adjust)
            (parameterize ([current-directory-for-user (adjust (build-path (car (filesystem-root-list)) "Users" "robby"))])
              (test
               "tmp.rkt:1:2"
               srcloc->string
               (srcloc (build-path (car (filesystem-root-list)) "Users" "robby" "tmp.rkt")
                       1 2 3 4))))])
  (go values)
  (go path->directory-path))

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Make sure that a module load triggered by `#lang` or `#reader` is in
;; a root namespace, including the call to the loaded function

(module provides-a-reader-to-check-phase racket/base
  (provide read read-syntax)

  (define (check)
    (unless (zero? (namespace-base-phase (current-namespace)))
      (error "reader callback with current namespace at the wrong phase:"
             (namespace-base-phase (current-namespace)))))

  (check)

  (define (read . args) (check) 'ok)
  (define (read-syntax . args) (check) #''ok))

;; Check in top level:
(test 'ok
      'reader-module-phase
      (let-syntax ([anything
                    (lambda (stx)
                      (parameterize ([read-accept-reader #t])
                        (read-syntax 'm (open-input-string "#lang reader 'provides-a-reader-to-check-phase"))))])
        (anything)))

;; Check module:
(module m racket/base
  (require (for-syntax racket/base))
  (let-syntax ([anything
                (lambda (stx)
                  (parameterize ([read-accept-reader #t])
                    (read-syntax 'm (open-input-string "#lang reader 'provides-a-reader-to-check-phase"))))])
    (anything)))


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(parameterize ([read-case-sensitive #t])
  (define (myread [in (current-input-port)])
    (parameterize-read
     (lambda () (read in))))

  (define (parameterize-read do-read)
    (parameterize ([current-readtable (make-a-readtable (current-readtable))])
      (do-read)))
  
  (define (make-a-readtable base)
    (make-readtable base
                    #\! 'dispatch-macro read-directive
                    #f  'non-terminating-macro (reparameterize-read base)))

  (define (reparameterize-read base)
    (case-lambda
      [(c in)                  (read/recursive in c base)]
      [(c in src line col pos) (read-syntax/recursive src in c base)]))
  
  (define (read-directive c in src line col pos)
    (read-case-sensitive #f)
    (make-special-comment #f))

  ;; Parameter change takes effect for recursive read:
  (test 'abc myread (open-input-string "#!ABC"))
  ;; Change also sticks:
  (test 'abc myread (open-input-string "ABC")))

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(test #t eq?
      (datum-intern-literal (make-string 10 #\x))
      (datum-intern-literal (make-string 10 #\x)))

;; make sure this doesn't take too long and use so much memory
;; that we crash:
(test #t integer? (datum-intern-literal (- (expt 2 10000000))))

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; readtable has `report-errs`:
(load-relative "readtable.rktl")
