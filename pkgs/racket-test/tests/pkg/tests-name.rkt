#lang racket/base
(require rackunit
         pkg/name
         "util.rkt")

(this-test-is-run-by-the-main-test)

(define-syntax check-equal-values?
  (syntax-rules (values)
    [(_ expr (values a ...))
     (check-equal? (call-with-values (lambda () expr) list) (list a ...))])) 

(define (parse a b [bad-rx #f]
               #:link-dirs? [link-dirs? #f])
  (define reason #f)
  (define-values (name type) (package-source->name+type
                              a b
                              #:link-dirs? link-dirs?
                              #:must-infer-name? #f
                              #:complain (lambda (s r)
                                           (unless reason (set! reason r)))))
  (values name 
          type
          (if reason
              (if bad-rx
                  (not (regexp-match? bad-rx reason))
                  #f)
              (not bad-rx))))

(define (run-pkg-tests)
  (check-equal-values? (parse "" #f #rx"ill-formed") (values #f #f #f))

  (check-equal-values? (parse "fish" #f) (values "fish" 'name #t))
  (check-equal-values? (parse "fish" 'name) (values "fish" 'name #t))
  (check-equal-values? (parse "fish!" 'name #rx"disallowed") (values #f 'name #f))
  (check-equal-values? (parse "fish/" 'name #rx"disallowed") (values #f 'name #f))
  (check-equal-values? (parse "fish123A_B-C" 'name) (values "fish123A_B-C" 'name #t))
  (check-equal-values? (parse "fish123A_B-C!" 'name #rx"disallowed") (values #f 'name #f))

  (check-equal-values? (parse "fish.plt" #f) (values "fish" 'file #t))
  (check-equal-values? (parse "fish.zip" #f) (values "fish" 'file #t))
  (check-equal-values? (parse "fish.tar" #f) (values "fish" 'file #t))
  (check-equal-values? (parse "fish.tgz" #f) (values "fish" 'file #t))
  (check-equal-values? (parse "fish.tar.gz" #f) (values "fish" 'file #t))
  (check-equal-values? (parse "ocean/fish.tar.gz" #f) (values "fish" 'file #t))
  (check-equal-values? (parse "fish.plt" 'file) (values "fish" 'file #t))
  (check-equal-values? (parse "fish.tar.gz" 'file) (values "fish" 'file #t))
  (check-equal-values? (parse "fish.other" 'file #rx"archive") (values #f 'file #f))
  (check-equal-values? (parse "fish" 'file #rx"archive") (values #f 'file #f))
  (check-equal-values? (parse "fish!" 'file #rx"archive") (values #f 'file #f))
  (check-equal-values? (parse "" 'file #rx"ill-formed") (values #f 'file #f))

  (check-equal-values? (parse "fish/" #f) (values "fish" 'dir #t))
  (check-equal-values? (parse "./fish" #f) (values "fish" 'dir #t))
  (check-equal-values? (parse "sub/fish" #f) (values "fish" 'dir #t))
  (check-equal-values? (parse "fish/" 'dir) (values "fish" 'dir #t))
  (check-equal-values? (parse "fish/" 'link) (values "fish" 'link #t))
  (check-equal-values? (parse "fish" 'dir) (values "fish" 'dir #t))
  (check-equal-values? (parse "fish!/" 'dir) (values #f 'dir #t))
  (check-equal-values? (parse "/" 'dir #rx"no elements in path") (values #f 'dir #f))
  (check-equal-values? (parse (path->string (build-path 'same)) 'dir #rx"ending path") (values #f 'dir #f))

  (check-equal-values? (parse "fish/" #f #:link-dirs? #t) (values "fish" 'link #t))
  (check-equal-values? (parse "fish/" 'dir #:link-dirs? #t) (values "fish" 'dir #t))
  (check-equal-values? (parse "fish.plt" #f #:link-dirs? #t) (values "fish" 'file #t))

  (check-equal? (package-source->name "http://") #f)
  (check-equal-values? (parse "http://" #f #rx"path is empty") (values #f 'dir-url #f))

  (check-equal-values? (parse "http://racket-lang.org/fish.plt" #f) (values "fish" 'file-url #t))
  (check-equal-values? (parse "https://racket-lang.org/fish.plt" #f) (values "fish" 'file-url #t))
  (check-equal-values? (parse "http://racket-lang.org/fish.tar.gz" #f) (values "fish" 'file-url #t))
  (check-equal-values? (parse "http://racket-lang.org/fish" 'file-url #rx"archive") (values #f 'file-url #f))
  (check-equal-values? (parse "fish.zip" 'file-url) (values "fish" 'file-url #t))
  (check-equal-values? (parse "dir/fish.zip" 'file-url) (values "fish" 'file-url #t))
  (check-equal-values? (parse "fish/" 'file-url #rx"archive") (values #f 'file-url #f))
  (check-equal-values? (parse "http://racket-lang.org/fish!.zip" 'file-url) (values #f 'file-url #t))

  (check-equal-values? (parse "http://racket-lang.org/fish/" #f) (values "fish" 'dir-url #t))
  (check-equal-values? (parse "http://racket-lang.org/fish/" 'dir-url) (values "fish" 'dir-url #t))
  (check-equal-values? (parse "http://racket-lang.org/fish" 'dir-url) (values "fish" 'dir-url #t))
  (check-equal-values? (parse "http://racket-lang.org/fish.plt" 'dir-url) (values #f 'dir-url #t))
  (check-equal-values? (parse "http://racket-lang.org/fish" #f) (values "fish" 'dir-url #t))
  (check-equal-values? (parse "http://racket-lang.org/." 'file-url #rx"indicator") (values #f 'file-url #t))
  (check-equal-values? (parse "http://racket-lang.org/.." 'file-url #rx"indicator") (values #f 'file-url #t))

  (check-equal-values? (parse "github://notgithub.com/racket/fish/master" #f #rx"github.com") (values #f 'github #f))
  (check-equal-values? (parse "github://github.com/racket/fish/master" #f) (values "fish" 'github #t))
  (check-equal-values? (parse "github://github.com/racket/fish.rkt/master" #f) (values #f 'github #t))
  (check-equal-values? (parse "github://github.com/racket/fish/release" #f) (values "fish" 'github #t))
  (check-equal-values? (parse "github://github.com/racket/fish/release/catfish" #f) (values "catfish" 'github #t))
  (check-equal-values? (parse "github://github.com/racket/fish/release/catfish/" #f) (values "catfish" 'github #t))
  (check-equal-values? (parse "github://github.com/racket/fish/release/catfish/bill" #f) (values "bill" 'github #t))
  (check-equal-values? (parse "github://github.com/racket/fish/master" 'github) (values "fish" 'github #t))
  (check-equal-values? (parse "github://github.com/fish/master" 'github #rx"three") (values #f 'github #f))
  (check-equal-values? (parse "github://github.com/racket/fish.more/release" 'github) (values #f 'github #t))
  (check-equal-values? (parse "github://github.com/racket/./release" #f #rx"indicator") (values #f 'github #f))
  (check-equal-values? (parse "github://github.com/../fish/release" #f #rx"indicator") (values #f 'github #f))
  (check-equal-values? (parse "github://github.com/racket/fish/master" 'clone) (values "fish" 'clone #t))
  (check-equal-values? (parse "github://github.com/fish/master" 'clone #rx"three") (values #f 'clone #f))

  (check-equal-values? (parse "git://github.com/racket/fish" #f) (values "fish" 'github #t))
  (check-equal-values? (parse "git://github.com/racket/fish/" #f) (values "fish" 'github #t))
  (check-equal-values? (parse "git://github.com/racket/fish.git" #f) (values "fish" 'github #t))
  (check-equal-values? (parse "git://github.com/racket/fish.git/" #f) (values "fish" 'github #t))
  (check-equal-values? (parse "git://github.com/racket/fish.rkt" #f) (values #f 'github #t))
  (check-equal-values? (parse "git://github.com/racket/fish#release" #f) (values "fish" 'github #t))
  (check-equal-values? (parse "git://github.com/racket/fish?path=catfish#release" #f) (values "catfish" 'github #t))
  (check-equal-values? (parse "git://github.com/racket/fish?path=catfish/" #f) (values "catfish" 'github #t))
  (check-equal-values? (parse "git://github.com/racket/fish?path=catfish/bill" #f) (values "bill" 'github #t))
  (check-equal-values? (parse "git://github.com/racket/fish/?path=catfish/bill" #f) (values "bill" 'github #t))
  (check-equal-values? (parse "git://github.com/racket/fish/master" 'github #rx"two") (values #f 'github #f))
  (check-equal-values? (parse "git://github.com/racket/fish.more" 'github) (values #f 'github #t))
  (check-equal-values? (parse "git://github.com/racket/." #f #rx"indicator") (values #f 'github #f))
  (check-equal-values? (parse "git://github.com/../fish" #f #rx"indicator") (values #f 'github #f))
  (check-equal-values? (parse "git://github.com/racket/fish" 'clone) (values "fish" 'clone #t))
  (check-equal-values? (parse "racket/fish" 'github) (values "fish" 'github #t))
  (check-equal-values? (parse "git://github.com/racket/fish/?path=../bill" #f #rx"indicator") (values #f 'github #f))

  (check-equal-values? (parse "git://not-github.com/racket/fish" #f #f) (values "fish" 'git #t))
  (check-equal-values? (parse "git://not-github.com/fish" #f #f) (values "fish" 'git #t))
  (check-equal-values? (parse "git://not-github.com/fish.git" #f #f) (values "fish" 'git #t))
  (check-equal-values? (parse "git://not-github.com/fish.git/" #f #f) (values "fish" 'git #t))
  (check-equal-values? (parse "git://not-github.com/" #f #rx"empty") (values #f 'git #f))
  (check-equal-values? (parse "git://not-github.com/fish.git//" #f #rx"empty") (values #f 'git #f))
  (check-equal-values? (parse "git://not-github.com/fish#release" #f) (values "fish" 'git #t))
  (check-equal-values? (parse "git://not-github.com/fish?path=catfish/bill" #f) (values "bill" 'git #t))
  (check-equal-values? (parse "git://not-github.com/fish/?path=catfish/bill" #f) (values "bill" 'git #t))
  (check-equal-values? (parse "git://not-github.com/../fish.git/" #f) (values "fish" 'git #t))
  (check-equal-values? (parse "git://not-github.com/.././" #f #rx"indicator") (values #f 'git #f))
  (check-equal-values? (parse "git://not-github.com/racket/fish" 'clone #f) (values "fish" 'clone #t))
  (check-equal-values? (parse "git://not-github.com/.././" 'clone #rx"indicator") (values #f 'clone #f))
  (check-equal-values? (parse "git://not-github.com/fish/?path=../bill" #f #rx"indicator") (values #f 'git #f))

  (check-equal-values? (parse "http://racket-lang.org/racket/fish" 'git #f) (values "fish" 'git #t))
  (check-equal-values? (parse "https://racket-lang.org/racket/fish" 'git #f) (values "fish" 'git #t))
  (check-equal-values? (parse "https://racket-lang.org/racket/fish?path=catfish" 'git #f) (values "catfish" 'git #t))
  (check-equal-values? (parse "http://racket-lang.org/racket/fish.git" 'git #f) (values "fish" 'git #t))
  (check-equal-values? (parse "http://racket-lang.org/racket/fish.git" #f #f) (values "fish" 'git #t))
  (check-equal-values? (parse "http://racket-lang.org/racket/fish.git/" 'git #f) (values "fish" 'git #t))
  (check-equal-values? (parse "http://racket-lang.org/racket/fish.git/" #f #f) (values "fish" 'git #t))
  (check-equal-values? (parse "http://racket-lang.org/racket/fish.git#release" #f #f) (values "fish" 'git #t))
  (check-equal-values? (parse "http://racket-lang.org/racket/fish.git?path=catfish" #f #f) (values "catfish" 'git #t))
  (check-equal-values? (parse "http://racket-lang.org/racket/.." 'git #rx"indicator") (values #f 'git #f))

  (check-equal-values? (parse "git+http://racket-lang.org/racket/fish" 'git-url #f) (values "fish" 'git-url #t))
  (check-equal-values? (parse "git+https://racket-lang.org/racket/fish" 'git-url #f) (values "fish" 'git-url #t))
  (check-equal-values? (parse "git+https://racket-lang.org/racket/fish?path=catfish" 'git-url #f) (values "catfish" 'git-url #t))
  (check-equal-values? (parse "git+http://racket-lang.org/racket/fish.git" 'git-url #f) (values "fish" 'git-url #t))
  (check-equal-values? (parse "git+http://racket-lang.org/racket/fish.git" #f #f) (values "fish" 'git-url #t))
  (check-equal-values? (parse "git+https://racket-lang.org/racket/fish.git" #f #f) (values "fish" 'git-url #t))
  (check-equal-values? (parse "git+http://racket-lang.org/racket/fish.git/" 'git-url #f) (values "fish" 'git-url #t))
  (check-equal-values? (parse "git+http://racket-lang.org/racket/fish.git/" #f #f) (values "fish" 'git-url #t))
  (check-equal-values? (parse "git+http://racket-lang.org/racket/fish.git#release" #f #f) (values "fish" 'git-url #t))
  (check-equal-values? (parse "git+http://racket-lang.org/racket/fish.git?path=catfish" #f #f) (values "catfish" 'git-url #t))
  (check-equal-values? (parse "git+http://racket-lang.org/racket/.." 'git-url #rx"indicator") (values #f 'git-url #f))

  (check-equal-values? (parse "racket/fish" 'github) (values "fish" 'github #t))
  (check-equal-values? (parse "racket/fish.git" 'github) (values "fish" 'github #t))
  (check-equal-values? (parse "racket/fish/" 'github) (values "fish" 'github #t))
  (check-equal-values? (parse "racket/fish/x" 'github #rx"two") (values #f 'github #f))
  (check-equal-values? (parse "fish" 'github #rx"two") (values #f 'github #f))

  (check-equal-values? (parse "file://fish.plt" #f) (values #f 'dir #t)) ; missing root means an empty path
  (check-equal-values? (parse "file:///root/fish.plt" #f) (values "fish" 'file #t))
  (check-equal-values? (parse "file://fish" #f) (values #f 'dir #t)) ; missing root means an empty path
  (check-equal-values? (parse "file:///root/fish" #f) (values "fish" 'dir #t))
  (check-equal-values? (parse "file:///root/fish.zip?ignored=yes#alsoIgnored" #f) (values "fish" 'file #t))
  (check-equal-values? (parse "file:///root/fish?ignored=yes#alsoIgnored" #f) (values "fish" 'dir #t))

  (check-equal-values? (parse "file:///root/fish?type=link" #f) (values "fish" 'link #t))
  (check-equal-values? (parse "file:///root/fish?type=static-link" #f) (values "fish" 'static-link #t))
  (check-equal-values? (parse "file:///root/fish?type=sink" #f #rx"unrecognized") (values #f 'dir #f))

  (check-equal-values? (parse "random://racket-lang.org/fish.plt" #f #rx"scheme") (values #f #f #f))

  (check-equal-values? (parse "" #f) (values #f #f #f))
  (check-equal-values? (parse "" 'file) (values #f 'file #f))
  (check-equal-values? (parse "" 'link) (values #f 'link #f))
  (check-equal-values? (parse "" 'static-link) (values #f 'static-link #f))
  (check-equal-values? (parse "" 'file-url) (values #f 'file-url #f))
  (check-equal-values? (parse "" 'dir-url) (values #f 'dir-url #f))
  (check-equal-values? (parse "" 'git) (values #f 'git #f))
  (check-equal-values? (parse "" 'git-url) (values #f 'git-url #f))
  (check-equal-values? (parse "" 'github #rx"two path elements") (values #f 'github #f))

  (void))

(provide run-pkg-tests)

(module+ main
  (run-pkg-tests* run-pkg-tests))
