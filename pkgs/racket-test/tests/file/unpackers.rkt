#lang racket/base
(require file/untar file/untgz file/unzip racket/file racket/system racket/set
         (except-in file/tar tar)
         tests/eli-tester)

(provide tests)

(define tmp      (find-system-path 'temp-dir))
(define tar-exe  (find-executable-path "tar"))
(define gzip-exe (find-executable-path "gzip"))
(define zip-exe  (find-executable-path "zip"))

(define work-dir (build-path tmp (format "unpacker-testing~a" (random 1000))))
(define a.tar    (build-path work-dir "a.tar"))
(define a.zip    (build-path work-dir "a.zip"))
(define ex1-dir  (build-path work-dir "ex1"))
(define more-dir (build-path ex1-dir "more"))

(define (file-or-directory-permissions* path permissions)
  (file-or-directory-permissions
   path
   (if (eq? 'windows (system-type))
       (if (regexp-match? #rx"w" permissions) #o777 #o555)
       (for/fold ([n 0]) ([p '(["r" #o400] ["w" #o200] ["x" #o100])])
	 (if (regexp-match? (car p) permissions) (bitwise-ior n (cadr p)) n)))))

(define (make-file path [mod-time #f] [permissions #f])
  (with-output-to-file path
    (lambda ()
      (for ([i (in-range (random 1000))])
        (write-bytes (make-bytes (random 100) (+ 32 (random 96)))))))
  (when mod-time    (file-or-directory-modify-seconds path mod-time))
  (when permissions (file-or-directory-permissions* path permissions)))

(define ((make-packer pack . flags) dir dest)
  (define-values [base name dir?] (split-path dir))
  (parameterize ([current-directory
                  (if (eq? 'relative base) (current-directory) base)])
    (void (apply system* pack `(,@flags ,dest ,name)))))

(define tar (make-packer tar-exe "-c" "-f"))
(define zip (make-packer zip-exe "-r" "-q"))

(define (diff src dest check-attributes?)
  (define (compare-attributes p1 p2 check-time?)
    (or (not check-attributes?)
        (and (or (not check-time?)
		 (= (file-or-directory-modify-seconds p1)
                    (file-or-directory-modify-seconds p2)))
	     (or (eq? 'windows (system-type)) ; tar on Windows don't preserve permissions
		 (equal? (file-or-directory-permissions p1)
			 (file-or-directory-permissions p2))))))
  (cond
   [(link-exists? src)
     (and (link-exists? dest)
          (diff (resolve-path src) (resolve-path dest) check-attributes?))]
    [(file-exists? src)
     (and (file-exists? dest)
          (= (file-size src) (file-size dest))
          (compare-attributes src dest #t)
          (equal? (file->bytes src) (file->bytes dest)))]
    [(directory-exists? src)
     (and (directory-exists? dest)
          (compare-attributes src dest (not (eq? 'windows (system-type))))
          (let* ([sort-paths (λ (l) (sort l bytes<? #:key path->bytes))]
                 [srcs       (sort-paths (directory-list src))]
                 [dests      (sort-paths (directory-list dest))])
            (and (equal? srcs dests)
                 (for/and ([src-item (in-list srcs)]
                           [dest-item (in-list dests)])
                   (diff (build-path src src-item)
                         (build-path dest dest-item)
                         check-attributes?))
                 ;; make dest writable to simplify clean-up:
                 (begin (file-or-directory-permissions* dest "rwx") #t))))]
    [else #t]))

(define (tar->entries a.tar)
  (define got '())
  (untar a.tar
         #:handle-entry (lambda (kind path content len attribs)
                          (set! got
                                (cons (tar-entry kind
                                                 path
                                                 (if (input-port? content)
                                                     (let ([bstr (read-bytes len content)])
                                                       (lambda ()
                                                         (open-input-bytes bstr)))
                                                     content)
                                                 len
                                                 attribs)
                                      got))
                          null))
  (reverse got))
  
(define (untar-tests*)
  (define links-ok? (not (eq? 'windows (system-type))))
  (make-directory* "ex1")
  (make-file (build-path "ex1" "f1") (- (current-seconds) 12) "rw")
  (make-file (build-path "ex1" "f2") (+ (current-seconds) 12) "rwx")
  (make-file (build-path "ex1" "f3") (- (current-seconds)  7) "r")
  (when links-ok?
    (make-file-or-directory-link "fnone" (build-path "ex1" "f4")))
  (make-directory* more-dir)
  (make-file (build-path more-dir "f4") (current-seconds) "rw")
  (file-or-directory-permissions* more-dir "rx") ; not "w"
  (tar "ex1" a.tar)
  (let ([got1 (tar->entries a.tar)])
    (define (check-find path)
      (unless (for/or ([e (in-list got1)])
                (equal? path (tar-entry-path e)))
        (error "missing in entries" path)))
    (define build-tar-path
      ;; untar always uses "/"
      (case-lambda
       [(a b) (string->path (string-append a "/" b))]
       [(a b c) (string->path (string-append a "/" b "/" c))]))
    (check-find (build-tar-path "ex1" "f1"))
    (check-find (build-tar-path "ex1" "f2"))
    (check-find (build-tar-path "ex1" "f3"))
    (when links-ok?
      (check-find (build-tar-path "ex1" "f4")))
    (check-find (build-tar-path "ex1" "more" "f4"))
    (define-values (i o) (make-pipe))
    (tar->output got1 o)
    (close-output-port o)
    (let ([got2 (tar->entries i)])
      (unless (= (length got1) (length got2))
        (error "entries lists not the same length"))
      (define (check what same?)
        (unless same?
          (error "entries differ at" what)))
      (for ([e1 (in-list got1)]
            [e2 (in-list got2)])
        (check 'kind (eq? (tar-entry-kind e1)
                          (tar-entry-kind e2)))
        (check 'path (equal? (tar-entry-path e1)
                             (tar-entry-path e2)))
        (check 'len (equal? (tar-entry-size e1)
                            (tar-entry-size e2)))
        (check 'attribs (equal? (tar-entry-attribs e1)
                                (tar-entry-attribs e2))))))
  (make-directory* "sub")
  (parameterize ([current-directory "sub"]) (untar a.tar))
  (test (diff "ex1" (build-path "sub" "ex1") #t))
  (delete-directory/files "sub")
  (untar a.tar #:dest "sub")
  (test (diff "ex1" (build-path "sub" "ex1") #t))
  (delete-directory/files "sub")
  (untgz a.tar #:dest "sub")
  (test (diff "ex1" (build-path "sub" "ex1") #t))
  (delete-directory/files "sub")
  (untar a.tar #:dest "sub" #:filter (lambda args #f))
  (when (directory-exists? "sub") (error "should not have been unpacked"))
  (when gzip-exe
    (void (system* gzip-exe a.tar))
    (untgz (path-replace-suffix a.tar #".tar.gz") #:dest "sub")
    (test (diff "ex1" (build-path "sub" "ex1") #t))
    (delete-directory/files "sub"))
  (file-or-directory-permissions* more-dir "rwx")
  
  ;; make sure top-level file extraction works
  (untgz (open-input-bytes
          ;; bytes gotten from 'tar' and 'gzip' command-line tools
          (bytes-append
           #"\37\213\b\b\3774\\Q\0\3robby.1.tar\0\3631Lf\2405000031Q"
           #"\0\321\346f\246`\332\300\b\302\207\1\5C#C#s\3c#cS\3\5\3CC33C"
           #"\6\5\3\232\273\f\bJ\213K\22\213\200N)\312OJ\252\304\243\16\250"
           #",-\r\217<\324\37pz\210\200\214\324\234\202\324\"\275\242\354\22"
           #"\332\331AR\374\233\233\2\343\337\330\330\310|4\376G\301(\30\5"
           #"\243\200\226\0\0\342 \234\3\0\b\0\0")))
  (test (file-exists? "L1c"))
  (test (file-exists? "helper.rkt"))
  (delete-file "L1c")
  (delete-file "helper.rkt")

  ;; check on [non-]permissive unpacking
  (unless (eq? (system-type) 'windows)
    (for ([target (in-list '("../x" "/tmp/abs" "ok"))])
      (define ok? (equal? target "ok"))
      (make-directory* "ex2")
      (make-file-or-directory-link target (build-path "ex2" "link"))
      (tar "ex2" a.tar)
      (make-directory "sub")
      (test (with-handlers ([exn:fail? (lambda (exn)
                                         (regexp-match? #rx"up-directory|absolute" (exn-message exn)))])
              (untar "a.tar" #:dest "sub")
              ok?))
      (test (equal? ok? (link-exists? (build-path "sub" "ex2" "link"))))
      (delete-directory/files "sub")

      (make-directory "sub")
      (untar "a.tar" #:dest "sub" #:permissive? #t)
      (test (link-exists? (build-path "sub" "ex2" "link")))
      (delete-directory/files "sub")
      (delete-directory/files "ex2"))))

(define ((make-unzip-tests* preserve-timestamps?))
  (make-directory* "ex1")
  (make-file (build-path "ex1" "f1"))
  (make-file (build-path "ex1" "f2"))
  (make-file (build-path "ex1" "f3"))
  (make-directory* more-dir)
  (make-file (build-path more-dir "f4"))
  (zip "ex1" a.zip)
  (make-directory* "sub")
  (parameterize ([current-directory "sub"])
    (if preserve-timestamps?
        (unzip a.zip #:preserve-timestamps? #t)
        (unzip a.zip)))
  (diff "ex1" (build-path "sub" "ex1") preserve-timestamps?)
  (delete-directory/files "sub")
  (unzip a.zip (make-filesystem-entry-reader #:dest "sub")
         #:preserve-timestamps? preserve-timestamps?)
  (diff "ex1" (build-path "sub" "ex1") preserve-timestamps?)
  (delete-directory/files "sub")
  (unzip a.zip (lambda (bytes dir? in) (void)))
  (when (directory-exists? "sub") (error "should not have been unpacked"))
  (define (directory-test src)
    (define zd (read-zip-directory src))
    (test (zip-directory? zd)
          (zip-directory-contains? zd "ex1/f1")
          (zip-directory-contains? zd #"ex1/f1")
          (zip-directory-contains? zd "ex1/more/f4")
          (zip-directory-contains? zd (string->path "ex1/more/f4"))
          (zip-directory-includes-directory? zd "ex1/more"))
    (define (check-not-there p)
      (test (not (zip-directory-contains? zd p)))
      (with-handlers ([exn:fail:unzip:no-such-entry?
                       (lambda (exn)
                         (test (exn:fail:unzip:no-such-entry-entry exn)
                               => (if (bytes? p) p (path->zip-path p))))])
        (unzip-entry src zd p #:preserve-timestamps? preserve-timestamps?)))
    (check-not-there #"f1")
    (for ([entry (in-list (zip-directory-entries zd))])
      (parameterize ([current-directory work-dir])
        (unzip-entry src zd entry (make-filesystem-entry-reader #:dest "sub")
                     #:preserve-timestamps? preserve-timestamps?)))
    (diff "ex1" (build-path "sub" "ex1") preserve-timestamps?)
    (delete-directory/files "sub"))
  (directory-test a.zip)
  (call-with-input-file a.zip directory-test))

(define (run-tests tester)
  (define (cleanup)
    (when (directory-exists? work-dir) (delete-directory/files work-dir)))
  (dynamic-wind
    cleanup
    (λ () (make-directory work-dir)
          (parameterize ([current-directory work-dir])
            (test do (tester))))
    cleanup))

(define (untar-tests) (when tar-exe (test do (run-tests untar-tests*))))
(define (unzip-tests [preserve-timestamps? #f])
  (when zip-exe (test do (run-tests (make-unzip-tests* preserve-timestamps?)))))

(define (untar-of-invalid-tests)
  ;; Make sure we don't get an internal error for this misformatted tar file:
  (define bad-tar.gz
    (bytes-append #"\37\213\b\b!D\363U\0\3test.tar\0\355\321A\n\302@\f\205\341\254=\305\334\240\223qb\316\323"
                  #"\205]YZl\274\277V\21\334\210(\fR\370\277M\26\t\344\301\213\343\22\235\264\225o\334m\235"
                  #"\352\226_\347\223h1\257\207\252V\\\262j\325*\311\32\347\272\273,\321\237S\222q8\365\21\357"
                  #"\357>\3557*\326\376\207ij\371\343\321\277\177\321\377\336r\221T\272\30\347\326\341\350?v\377"
                  #"\16\1\0\0\0\0\0\0\0\0\0\0\0\0\340'W\327\1)\27\0(\0\0"))
  (test (regexp-match?
         #rx"^unt"
         (with-handlers ([exn? exn-message])
           (untgz (open-input-bytes bad-tar.gz) #:filter (lambda args #f))))))

(module+ main (tests))
;; Use "main.rkt" with `raco test`, instead of this file

(define (tests)
  (test do (untar-tests)
        do (unzip-tests)
        do (unzip-tests #t)
        do (untar-of-invalid-tests)))
