
(load-relative "loadtest.rktl")

(Section 'hash)

(require racket/hash)

;; ----------------------------------------
;; Hash-key sorting:

(let ([u/apple (string->uninterned-symbol "apple")]
      [u/banana (string->uninterned-symbol "banana")]
      [u/coconut (string->uninterned-symbol "coconut")]
      [apple (string->unreadable-symbol "apple")]
      [banana (string->unreadable-symbol "banana")]
      [coconut (string->unreadable-symbol "coconut")])
  (test (list #f #t
              #\a #\b #\c #\u3BB
              (- (expt 2 79))
              -3 -2 -1
              0
              1/2 0.75 8.5f-1
              1 2 3
              (expt 2 79)
              u/apple u/banana u/coconut
              apple banana coconut
              'apple 'banana 'coconut 'coconut+
              '#:apple '#:banana '#:coconut
              "Apple"
              "apple" "banana" "coconut"
              #"Apple"
              #"apple" #"banana" #"coconut"
              null
              (void)
              eof)
        'ordered
        (hash-map (hash #t 'x
                        #f 'x
                        #\a 'a #\b 'b #\c 'c #\u3BB 'lam
                        1 'a 2 'b 3 'c
                        1/2 'n 0.75 'n 8.5f-1 'n
                        0 'z
                        -1 'a -2 'b -3 'c
                        (expt 2 79) 'b
                        (- (expt 2 79)) 'b
                        "Apple" 'a
                        "apple" 'a "banana" 'b "coconut" 'c
                        #"Apple" 'a
                        #"apple" 'a #"banana" 'b #"coconut" 'c
                        u/apple 'a u/banana 'b u/coconut 'c
                        apple 'a banana 'b coconut 'c
                        'apple 'a 'banana 'b 'coconut 'c 'coconut+ '+
                        '#:apple 'a '#:banana 'b '#:coconut 'c
                        null 'one
                        (void) 'one
                        eof 'one)
                  (lambda (k v) k)
                  #t)))

;; ----------------------------------------

(test #hash([4 . four] [3 . three] [1 . one] [2 . two])
      hash-union #hash([1 . one] [2 . two]) #hash([3 . three] [4 . four]))
(test #hash([four . 4] [three . 3] [one . 1] [two . 2])
      hash-union #hash([one . 1] [two . 1]) #hash([three . 3] [four . 4] [two . 1])
      #:combine +)
(test #hash([1 . 1] [2 . 2] [3 . 3] [4 . 4])
      hash-union #hash([1 . 1]) #hasheq([2 . 2] [3 . 3]) #hasheq([4 . 4]))
(test #hasheq([1 . 1] [2 . 2] [3 . 3] [4 . 4])
      hash-union #hasheq([1 . 1]) #hash([2 . 2] [3 . 3]) #hash([4 . 4]))
(test #hash([1 . -2] [2 . 2])
      hash-union #hash([1 . 1] [2 . 2]) #hash([1 . 3])
      #:combine -)

(test #hash([4 . four] [3 . three] [1 . one] [2 . two])
      hash-union #hash([1 . one]) (make-hash '([2 . two] [3 . three] [4 . four])))
(test #hash([four . 4] [three . 3] [one . 1] [two . 2])
      hash-union #hash([one . 1] [two . 1]) (make-hash '([two . 1] [three . 3] [four . 4]))
      #:combine +)
(test #hash([1 . 1] [2 . 2] [3 . 3] [4 . 4])
      hash-union #hash([1 . 1]) (make-hasheq '([2 . 2] [3 . 3])) (make-hasheq '([4 . 4])))
(test #hasheq([1 . 1] [2 . 2] [3 . 3] [4 . 4])
      hash-union #hasheq([1 . 1]) (make-hash '([2 . 2] [3 . 3])) (make-hash '([4 . 4])))
(test #hash([1 . -2] [2 . 2])
      hash-union #hash([1 . 1]) (make-hash '([1 . 3] [2 . 2]))
      #:combine -)

(test #hash((a . 5) (b . 7))
      hash-intersect #hash((a . 1) (b . 2) (c . 3)) #hash((a . 4) (b . 5))
      #:combine +)
(test #hash((a . 5) (b . -3))
      hash-intersect #hash((a . 1) (b . 2) (c . 3)) #hash((a . 4) (b . 5))
      #:combine/key
      (lambda (k v1 v2) (if (eq? k 'a) (+ v1 v2) (- v1 v2))))

;; Does hash-intersect preserve the kind of the hash?
(test (hasheq "a" 11)
      hash-intersect (hasheq "a" 1 (string #\a) 2 (string #\a) 3)
      (hasheq "a" 10 (string #\a) 20)
      #:combine +)

(let ()
  (define h (make-hash))
  (hash-union! h #hash([1 . one] [2 . two]))
  (hash-union! h #hash([3 . three] [4 . four]))
  (test #t
        equal?
        (hash-copy
         #hash([1 . one] [2 . two] [3 . three] [4 . four]))
        h))
(let ()
  (define h (make-hash))
  (hash-union! h #hash([one . 1] [two . 1]))
  (err/rt-test (hash-union! h #hash([three . 3] [four . 4] [two . 1])) exn:fail?))
(let ()
  (define h (make-hash))
  (hash-union! h #hash([one . 1] [two . 1]))
  (hash-union! h #hash([three . 3] [four . 4] [two . 1])
               #:combine/key (lambda (k x y) (+ x y)))
  (test #t
        equal?
        (hash-copy
         #hash([one . 1] [two . 2] [three . 3] [four . 4]))
        h))

(let ()
  (struct a (n m)
          #:property
          prop:equal+hash
          (list (lambda (a b eql) (and (= (a-n a) (a-n b))
                                  (= (a-m a) (a-m b))))
                (lambda (a hc) (a-n a))
                (lambda (a hc) (a-n a))))

  (define ht0 (hash (a 1 0) #t))
  ;; A hash table with two keys that have the same hash code
  (define ht1 (hash (a 1 0) #t
                    (a 1 2) #t))
  ;; Another hash table with the same two keys, plus another
  ;; with an extra key whose hash code is different but the
  ;; same in the last 5 bits:
  (define ht2 (hash (a 1 0) #t
                    (a 1 2) #t
                    (a 33 0) #t))
  ;; A hash table with no collision, but the same last
  ;; 5 bits for both keys:
  (define ht3 (hash (a 1 0) #t
                    (a 33 0) #t))
  ;; A hash with the same (colliding) keys as h1 but
  ;; different values:
  (define ht4 (hash (a 1 0) #f
                    (a 1 2) #f))

  ;; Subset must compare a collision node with a subtree node (that
  ;; contains a collision node):
  (test #t hash-keys-subset? ht1 ht2)

  (test #t hash-keys-subset? ht3 ht2)
  (test #t hash-keys-subset? ht0 ht3)

  (test #t hash-keys-subset? ht0 ht2)
  (test #t hash-keys-subset? ht0 ht1)
  (test #f hash-keys-subset? ht2 ht1)
  (test #f hash-keys-subset? ht2 ht0)
  (test #f hash-keys-subset? ht1 ht0)
  (test #f hash-keys-subset? ht1 ht3)

  ;; Equality of collision nodes:
  (test #f equal? ht1 ht4)
  (let ([ht4a (hash-set ht4 (a 1 0) #t)]
        [ht4b (hash-set ht4 (a 1 2) #t)]
        [ht5 (hash-set* ht4
                        (a 1 0) #t
                        (a 1 2) #t)])
    (test #f equal? ht1 ht4a)
    (test #f equal? ht1 ht4b)
    (test #t equal? ht1 ht5)))

(let ()
  (define-syntax (define-hash-iterations-tester stx)
    (syntax-case stx ()
     [(_ tag -in-hash -in-pairs -in-keys -in-values)
      #'(define-hash-iterations-tester tag
          -in-hash -in-hash -in-hash -in-hash
          -in-pairs -in-pairs -in-pairs -in-pairs
          -in-keys -in-keys -in-keys -in-keys
          -in-values -in-values -in-values -in-values)]
     [(_ tag
         -in-immut-hash -in-mut-hash -in-weak-hash -in-ephemeron-hash
         -in-immut-hash-pairs -in-mut-hash-pairs -in-weak-hash-pairs -in-ephemeron-hash-pairs
         -in-immut-hash-keys -in-mut-hash-keys -in-weak-hash-keys -in-ephemeron-hash-keys
         -in-immut-hash-values -in-mut-hash-values -in-weak-hash-values -in-ephemeron-hash-values)
      (with-syntax 
       ([name 
         (datum->syntax #'tag 
           (string->symbol 
             (format "test-hash-iters-~a" (syntax->datum #'tag))))])
       #'(define (name lst1 lst2)
          (define ht/immut (make-immutable-hash (map cons lst1 lst2)))
          (define ht/mut (make-hash (map cons lst1 lst2)))
          (define ht/weak (make-weak-hash (map cons lst1 lst2)))
          (define ht/ephemeron (make-ephemeron-hash (map cons lst1 lst2)))
            
          (define fake-ht/immut
            (chaperone-hash 
                ht/immut
              (lambda (h k) (values k (lambda (h k v) v))) ; ref-proc
              (lambda (h k v) values k v) ; set-proc
              (lambda (h k) k) ; remove-proc
              (lambda (h k) k))) ; key-proc
          (define fake-ht/mut
            (impersonate-hash 
                ht/mut
              (lambda (h k) (values k (lambda (h k v) v))) ; ref-proc
              (lambda (h k v) values k v) ; set-proc
              (lambda (h k) k) ; remove-proc
              (lambda (h k) k))) ; key-proc
          (define fake-ht/weak
            (impersonate-hash 
                ht/weak
              (lambda (h k) (values k (lambda (h k v) v))) ; ref-proc
              (lambda (h k v) values k v) ; set-proc
              (lambda (h k) k) ; remove-proc
              (lambda (h k) k)))
          (define fake-ht/ephemeron
            (impersonate-hash 
                ht/ephemeron
              (lambda (h k) (values k (lambda (h k v) v))) ; ref-proc
              (lambda (h k v) values k v) ; set-proc
              (lambda (h k) k) ; remove-proc
              (lambda (h k) k))) ; key-proc
            
          (define ht/immut/seq (-in-immut-hash ht/immut))
          (define ht/mut/seq (-in-mut-hash ht/mut))
          (define ht/weak/seq (-in-weak-hash ht/weak))
          (define ht/ephemeron/seq (-in-ephemeron-hash ht/ephemeron))
          (define ht/immut-pair/seq (-in-immut-hash-pairs ht/immut))
          (define ht/mut-pair/seq (-in-mut-hash-pairs ht/mut))
          (define ht/weak-pair/seq (-in-weak-hash-pairs ht/weak))
          (define ht/ephemeron-pair/seq (-in-ephemeron-hash-pairs ht/ephemeron))
          (define ht/immut-keys/seq (-in-immut-hash-keys ht/immut))
          (define ht/mut-keys/seq (-in-mut-hash-keys ht/mut))
          (define ht/weak-keys/seq (-in-weak-hash-keys ht/weak))
          (define ht/ephemeron-keys/seq (-in-ephemeron-hash-keys ht/ephemeron))
          (define ht/immut-vals/seq (-in-immut-hash-values ht/immut))
          (define ht/mut-vals/seq (-in-mut-hash-values ht/mut))
          (define ht/weak-vals/seq (-in-weak-hash-values ht/weak))
          (define ht/ephemeron-vals/seq (-in-ephemeron-hash-values ht/ephemeron))
    
          (test #t =
           (for/sum ([(k v) (-in-immut-hash ht/immut)]) (+ k v))
           (for/sum ([(k v) (-in-mut-hash ht/mut)]) (+ k v))
           (for/sum ([(k v) (-in-weak-hash ht/weak)]) (+ k v))
           (for/sum ([(k v) (-in-ephemeron-hash ht/ephemeron)]) (+ k v))
           (for/sum ([(k v) (-in-immut-hash fake-ht/immut)]) (+ k v))
           (for/sum ([(k v) (-in-mut-hash fake-ht/mut)]) (+ k v))
           (for/sum ([(k v) (-in-weak-hash fake-ht/weak)]) (+ k v))
           (for/sum ([(k v) (-in-ephemeron-hash fake-ht/ephemeron)]) (+ k v))
           (for/sum ([(k v) ht/immut/seq]) (+ k v))
           (for/sum ([(k v) ht/mut/seq]) (+ k v))
           (for/sum ([(k v) ht/weak/seq]) (+ k v))
           (for/sum ([(k v) ht/ephemeron/seq]) (+ k v))
           (for/sum ([k+v (-in-immut-hash-pairs ht/immut)])
             (+ (car k+v) (cdr k+v)))
           (for/sum ([k+v (-in-mut-hash-pairs ht/mut)])
             (+ (car k+v) (cdr k+v)))
           (for/sum ([k+v (-in-weak-hash-pairs ht/weak)])
             (+ (car k+v) (cdr k+v)))
           (for/sum ([k+v (-in-ephemeron-hash-pairs ht/ephemeron)])
             (+ (car k+v) (cdr k+v)))
           (for/sum ([k+v (-in-immut-hash-pairs fake-ht/immut)]) 
             (+ (car k+v) (cdr k+v)))
           (for/sum ([k+v (-in-mut-hash-pairs fake-ht/mut)]) 
             (+ (car k+v) (cdr k+v)))
           (for/sum ([k+v (-in-weak-hash-pairs fake-ht/weak)]) 
             (+ (car k+v) (cdr k+v)))
           (for/sum ([k+v (-in-ephemeron-hash-pairs fake-ht/ephemeron)]) 
             (+ (car k+v) (cdr k+v)))
           (for/sum ([k+v ht/immut-pair/seq]) (+ (car k+v) (cdr k+v)))
           (for/sum ([k+v ht/mut-pair/seq]) (+ (car k+v) (cdr k+v)))
           (for/sum ([k+v ht/weak-pair/seq]) (+ (car k+v) (cdr k+v)))
           (for/sum ([k+v ht/ephemeron-pair/seq]) (+ (car k+v) (cdr k+v)))
           (+ (for/sum ([k (-in-immut-hash-keys ht/immut)]) k)
              (for/sum ([v (-in-immut-hash-values ht/immut)]) v))
           (+ (for/sum ([k (-in-mut-hash-keys ht/mut)]) k)
              (for/sum ([v (-in-mut-hash-values ht/mut)]) v))
           (+ (for/sum ([k (-in-weak-hash-keys ht/weak)]) k)
              (for/sum ([v (-in-weak-hash-values ht/weak)]) v))
           (+ (for/sum ([k (-in-ephemeron-hash-keys ht/ephemeron)]) k)
              (for/sum ([v (-in-ephemeron-hash-values ht/ephemeron)]) v))
           (+ (for/sum ([k (-in-immut-hash-keys fake-ht/immut)]) k)
              (for/sum ([v (-in-immut-hash-values fake-ht/immut)]) v))
           (+ (for/sum ([k (-in-mut-hash-keys fake-ht/mut)]) k)
              (for/sum ([v (-in-mut-hash-values fake-ht/mut)]) v))
           (+ (for/sum ([k (-in-weak-hash-keys fake-ht/weak)]) k)
              (for/sum ([v (-in-weak-hash-values fake-ht/weak)]) v))
           (+ (for/sum ([k (-in-ephemeron-hash-keys fake-ht/ephemeron)]) k)
              (for/sum ([v (-in-ephemeron-hash-values fake-ht/ephemeron)]) v))
           (+ (for/sum ([k ht/immut-keys/seq]) k)
              (for/sum ([v ht/immut-vals/seq]) v))
           (+ (for/sum ([k ht/mut-keys/seq]) k)
              (for/sum ([v ht/mut-vals/seq]) v))
           (+ (for/sum ([k ht/weak-keys/seq]) k)
              (for/sum ([v ht/weak-vals/seq]) v))
           (+ (for/sum ([k ht/ephemeron-keys/seq]) k)
              (for/sum ([v ht/ephemeron-vals/seq]) v)))
          
          (test #t =
           (for/sum ([(k v) (-in-immut-hash ht/immut)]) k)
           (for/sum ([(k v) (-in-mut-hash ht/mut)]) k)
           (for/sum ([(k v) (-in-weak-hash ht/weak)]) k)
           (for/sum ([(k v) (-in-ephemeron-hash ht/ephemeron)]) k)
           (for/sum ([(k v) (-in-immut-hash fake-ht/immut)]) k)
           (for/sum ([(k v) (-in-mut-hash fake-ht/mut)]) k)
           (for/sum ([(k v) (-in-weak-hash fake-ht/weak)]) k)
           (for/sum ([(k v) (-in-ephemeron-hash fake-ht/ephemeron)]) k)
           (for/sum ([(k v) ht/immut/seq]) k)
           (for/sum ([(k v) ht/mut/seq]) k)
           (for/sum ([(k v) ht/weak/seq]) k)
           (for/sum ([(k v) ht/ephemeron/seq]) k)
           (for/sum ([k+v (-in-immut-hash-pairs ht/immut)]) (car k+v))
           (for/sum ([k+v (-in-mut-hash-pairs ht/mut)]) (car k+v))
           (for/sum ([k+v (-in-weak-hash-pairs ht/weak)]) (car k+v))
           (for/sum ([k+v (-in-ephemeron-hash-pairs ht/ephemeron)]) (car k+v))
           (for/sum ([k+v (-in-immut-hash-pairs fake-ht/immut)]) (car k+v))
           (for/sum ([k+v (-in-mut-hash-pairs fake-ht/mut)]) (car k+v))
           (for/sum ([k+v (-in-weak-hash-pairs fake-ht/weak)]) (car k+v))
           (for/sum ([k+v (-in-ephemeron-hash-pairs fake-ht/ephemeron)]) (car k+v))
           (for/sum ([k+v ht/immut-pair/seq]) (car k+v))
           (for/sum ([k+v ht/mut-pair/seq]) (car k+v))
           (for/sum ([k+v ht/weak-pair/seq]) (car k+v))
           (for/sum ([k+v ht/ephemeron-pair/seq]) (car k+v))
           (for/sum ([k (-in-immut-hash-keys ht/immut)]) k)
           (for/sum ([k (-in-mut-hash-keys ht/mut)]) k)
           (for/sum ([k (-in-weak-hash-keys ht/weak)]) k)
           (for/sum ([k (-in-ephemeron-hash-keys ht/ephemeron)]) k)
           (for/sum ([k (-in-immut-hash-keys fake-ht/immut)]) k)
           (for/sum ([k (-in-mut-hash-keys fake-ht/mut)]) k)
           (for/sum ([k (-in-weak-hash-keys fake-ht/weak)]) k)
           (for/sum ([k (-in-ephemeron-hash-keys fake-ht/ephemeron)]) k)
           (for/sum ([k ht/immut-keys/seq]) k)
           (for/sum ([k ht/mut-keys/seq]) k)
           (for/sum ([k ht/weak-keys/seq]) k)
           (for/sum ([k ht/ephemeron-keys/seq]) k))
    
          (test #t =
           (for/sum ([(k v) (-in-immut-hash ht/immut)]) v)
           (for/sum ([(k v) (-in-mut-hash ht/mut)]) v)
           (for/sum ([(k v) (-in-weak-hash ht/weak)]) v)
           (for/sum ([(k v) (-in-ephemeron-hash ht/ephemeron)]) v)
           (for/sum ([(k v) (-in-immut-hash fake-ht/immut)]) v)
           (for/sum ([(k v) (-in-mut-hash fake-ht/mut)]) v)
           (for/sum ([(k v) (-in-weak-hash fake-ht/weak)]) v)
           (for/sum ([(k v) (-in-ephemeron-hash fake-ht/ephemeron)]) v)
           (for/sum ([(k v) ht/immut/seq]) v)
           (for/sum ([(k v) ht/mut/seq]) v)
           (for/sum ([(k v) ht/weak/seq]) v)
           (for/sum ([(k v) ht/ephemeron/seq]) v)
           (for/sum ([k+v (-in-immut-hash-pairs ht/immut)]) (cdr k+v))
           (for/sum ([k+v (-in-mut-hash-pairs ht/mut)]) (cdr k+v))
           (for/sum ([k+v (-in-weak-hash-pairs ht/weak)]) (cdr k+v))
           (for/sum ([k+v (-in-ephemeron-hash-pairs ht/ephemeron)]) (cdr k+v))
           (for/sum ([k+v (-in-immut-hash-pairs fake-ht/immut)]) (cdr k+v))
           (for/sum ([k+v (-in-mut-hash-pairs fake-ht/mut)]) (cdr k+v))
           (for/sum ([k+v (-in-weak-hash-pairs fake-ht/weak)]) (cdr k+v))
           (for/sum ([k+v (-in-ephemeron-hash-pairs fake-ht/ephemeron)]) (cdr k+v))
           (for/sum ([k+v ht/immut-pair/seq]) (cdr k+v))
           (for/sum ([k+v ht/mut-pair/seq]) (cdr k+v))
           (for/sum ([k+v ht/weak-pair/seq]) (cdr k+v))
           (for/sum ([k+v ht/ephemeron-pair/seq]) (cdr k+v))
           (for/sum ([v (-in-immut-hash-values ht/immut)]) v)
           (for/sum ([v (-in-mut-hash-values ht/mut)]) v)
           (for/sum ([v (-in-weak-hash-values ht/weak)]) v)
           (for/sum ([v (-in-ephemeron-hash-values ht/ephemeron)]) v)
           (for/sum ([v (-in-immut-hash-values fake-ht/immut)]) v)
           (for/sum ([v (-in-mut-hash-values fake-ht/mut)]) v)
           (for/sum ([v (-in-weak-hash-values fake-ht/weak)]) v)
           (for/sum ([v (-in-ephemeron-hash-values fake-ht/ephemeron)]) v)
           (for/sum ([v ht/immut-vals/seq]) v)
           (for/sum ([v ht/mut-vals/seq]) v)
           (for/sum ([v ht/weak-vals/seq]) v)
           (for/sum ([v ht/ephemeron-vals/seq]) v))))]))
  (define-hash-iterations-tester generic
    in-hash in-hash-pairs in-hash-keys in-hash-values)
  (define-hash-iterations-tester specific
    in-immutable-hash in-mutable-hash in-weak-hash in-ephemeron-hash
    in-immutable-hash-pairs in-mutable-hash-pairs in-weak-hash-pairs in-ephemeron-hash-pairs
    in-immutable-hash-keys in-mutable-hash-keys in-weak-hash-keys in-ephemeron-hash-keys
    in-immutable-hash-values in-mutable-hash-values in-weak-hash-values in-ephemeron-hash-values)
  
  (define lst1 (build-list 10 values))
  (define lst2 (build-list 10 add1))
  (test-hash-iters-generic lst1 lst2)
  (test-hash-iters-specific lst1 lst2)
  (define lst3 (build-list 100000 values))
  (define lst4 (build-list 100000 add1))
  (test-hash-iters-generic lst3 lst4)
  (test-hash-iters-specific lst3 lst4))


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Use keys that are a multiple of a power of 2 to
; get "almost" collisions that force the hash table
; to use a deeper tree.

(let ()
  (define vals (for/list ([j (in-range 100)]) (add1 j)))
  (define sum-vals (for/sum ([v (in-list vals)]) v))
  (for ([shift (in-range 150)])
    (define keys (for/list ([j (in-range 100)])
                   (arithmetic-shift j shift)))
    ; test first the weak table to ensure the keys are not collected
    (define ht/weak (make-weak-hash (map cons keys vals)))
    (define sum-ht/weak (for/sum ([v (in-weak-hash-values ht/weak)]) v))
    (define ht/mut (make-hash (map cons keys vals)))
    (define sum-ht/mut (for/sum ([v (in-mutable-hash-values ht/mut)]) v))
    (define ht/immut (make-immutable-hash (map cons keys vals)))
    (define sum-ht/immut (for/sum ([v (in-immutable-hash-values ht/immut)]) v))
    (test #t = sum-vals sum-ht/weak sum-ht/mut sum-ht/immut)))

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(let ()
  (define err-msg "no element at index")

;; Check that unsafe-weak-hash-iterate- ops do not segfault
;; when a key is collected before access; throw exception instead.
;; They are used for safe iteration in in-weak-hash- sequence forms
  (let ()
    (define ht #f)
    
    (define lst (build-list 10 add1))
    (set! ht (make-weak-hash `((,lst . val))))
    
    (define i (hash-iterate-first ht))
    
    ;; everything ok
    (test #t number? i)
    (test #t list? (hash-iterate-key ht i))
    (test #t equal? (hash-iterate-value ht i) 'val)
    (test #t equal? (cdr (hash-iterate-pair ht i)) 'val)
    (test #t equal? 
          (call-with-values (lambda () (hash-iterate-key+value ht i)) cons)
          '((1 2 3 4 5 6 7 8 9 10) . val))
    (test #f hash-iterate-next ht i)

    ;; keep `lst` live until here
    (test #t eq? lst (hash-iterate-key ht i))

    (unless (eq? 'cgc (system-type 'gc))
      ;; collect key, everything should error
      (collect-garbage)
      (test #t boolean? (hash-iterate-first ht))
      (err/rt-test (hash-iterate-key ht i) exn:fail:contract? err-msg)
      (err/rt-test (hash-iterate-value ht i) exn:fail:contract? err-msg)
      (err/rt-test (hash-iterate-pair ht i) exn:fail:contract? err-msg)
      (err/rt-test (hash-iterate-key+value ht i) exn:fail:contract? err-msg)
      (test #f hash-iterate-next ht i)))

;; Check that unsafe mutable hash table operations do not segfault
;; after getting valid index from unsafe-mutable-hash-iterate-first and -next.
;; Throw exception instead since they're used for safe iteration
  (let ()
    (define ht (make-hash '((a . b))))
    
    (define i (hash-iterate-first ht))
    
    ;; everything ok
    (test #t number? i)
    (test #t equal? (hash-iterate-key ht i) 'a)
    (test #t equal? (hash-iterate-value ht i) 'b)
    (test #t equal? (hash-iterate-pair ht i) '(a . b))
    (test #t equal? 
          (call-with-values (lambda () (hash-iterate-key+value ht i)) cons)
          '(a . b))
    (test #t boolean? (hash-iterate-next ht i))
    
    ;; remove element, everything should error
    (hash-remove! ht 'a)
    (test #t boolean? (hash-iterate-first ht))
    (err/rt-test (hash-iterate-key ht i) exn:fail:contract? err-msg)
    (err/rt-test (hash-iterate-value ht i) exn:fail:contract? err-msg)
    (err/rt-test (hash-iterate-pair ht i) exn:fail:contract? err-msg)
    (err/rt-test (hash-iterate-key+value ht i) exn:fail:contract? err-msg)
    (test #f hash-iterate-next ht i))
    

  (let ()
    (define ht (make-weak-hash '((a . b))))
    
    (define i (hash-iterate-first ht))
    
    ;; everything ok
    (test #t number? i)
    (test #t equal? (hash-iterate-key ht i) 'a)
    (test #t equal? (hash-iterate-value ht i) 'b)
    (test #t equal? (hash-iterate-pair ht i) '(a . b))
    (test #t equal? (call-with-values 
                        (lambda () (hash-iterate-key+value ht i)) cons)
                    '(a . b))
    (test #t boolean? (hash-iterate-next ht i))

    ;; remove element, everything should error
    (hash-remove! ht 'a)
    (test #t boolean? (hash-iterate-first ht))
    (err/rt-test (hash-iterate-key ht i) exn:fail:contract?)
    (err/rt-test (hash-iterate-value ht i) exn:fail:contract?)
    (err/rt-test (hash-iterate-pair ht i) exn:fail:contract?)
    (err/rt-test (hash-iterate-key+value ht i) exn:fail:contract?)
    (test #f hash-iterate-next ht i)))

;; ----------------------------------------

(define-syntax-rule (hash-remove-iterate-test make-hash (X ...) in-hash-X sel)
  (let ([ht (make-hash)])
    (arity-test in-hash-X 1 2)
    (test 'in-hash-X object-name in-hash-X)
    (define keys (for/list ([k (in-range 10)])
                   (gensym)))
    (define (add-keys!)
      (for ([k (in-list keys)]
            [i (in-naturals)])
        (hash-set! ht k i)))
    (add-keys!)
    (test 5 '(remove-during-loop make-hash in-hash-X)
          (for/sum ([(X ...) (in-hash-X ht #f)]
                    [i (in-naturals)])
            (when (= i 4)
              (for ([k (in-list keys)])
                (hash-remove! ht k)))
            (if (sel X ...) 1 0)))
    (add-keys!)
    (test 'ok '(remove-during-loop make-hash in-hash-X)
          (for/fold ([v 'ok]) ([(X ...) (in-hash-X ht #f)]
                               [i (in-naturals)])
            (when (= i 4)
              (set! keys #f)
              (collect-garbage))
            v))))

(define-syntax-rule (hash-remove-iterate-test* [make-hash ...] (X ...) in-hash-X in-Y-hash-X sel)
  (begin
    (hash-remove-iterate-test make-hash (X ...) in-hash-X sel) ...
    (hash-remove-iterate-test make-hash (X ...) in-Y-hash-X sel) ...))

(hash-remove-iterate-test* [make-hash make-hasheq make-hasheqv make-hashalw]
                          (k v) in-hash in-mutable-hash and)
(hash-remove-iterate-test* [make-hash make-hasheq make-hasheqv make-hashalw]
                          (k) in-hash-keys in-mutable-hash-keys values)
(hash-remove-iterate-test* [make-hash make-hasheq make-hasheqv make-hashalw]
                          (v) in-hash-values in-mutable-hash-values values)
(hash-remove-iterate-test* [make-hash make-hasheq make-hasheqv make-hashalw]
                           (p) in-hash-pairs in-mutable-hash-pairs car)

(hash-remove-iterate-test* [make-weak-hash make-weak-hasheq make-weak-hasheqv make-weak-hashalw]
                          (k v) in-hash in-weak-hash and)
(hash-remove-iterate-test* [make-weak-hash make-weak-hasheq make-weak-hasheqv make-weak-hashalw]
                          (k) in-hash-keys in-weak-hash-keys values)
(hash-remove-iterate-test* [make-weak-hash make-weak-hasheq make-weak-hasheqv make-weak-hashalw]
                          (v) in-hash-values in-weak-hash-values values)
(hash-remove-iterate-test* [make-weak-hash make-weak-hasheq make-weak-hasheqv make-weak-hashalw]
                           (p) in-hash-pairs in-weak-hash-pairs car)

;; ----------------------------------------
;; weak and ephemeron hash tables

(unless (eq? 'cgc (system-type 'gc))
  (let ([wht (make-weak-hash)]
        [eht (make-ephemeron-hash)])
    (define key1 (gensym "key"))
    (define key2 (gensym "key"))
    (define key3 (gensym "key"))

    (hash-set! wht key1 (list key1))
    (hash-set! wht key2 'ok)
    (hash-set! wht key3 'not-key3)
    (hash-set! eht key1 (list key1))
    (hash-set! eht key2 'ok)
    (hash-set! eht key3 (box key3))

    (test (list key1) hash-ref wht key1)
    (test 'ok hash-ref wht key2)
    (test (list key1) hash-ref eht key1)
    (test 'ok hash-ref eht key2)

    (collect-garbage)
    
    (test 1 values (hash-count wht))
    (test 1 values (hash-count eht))

    (test (list key1) hash-ref wht key1)
    (test (list key1) hash-ref eht key1)

    (void)))

;; ----------------------------------------
;; hash-ref-key

(let ()
  (arity-test hash-ref-key 2 3)

  (define (test-hash-ref-key ht eql? expected-retained-key expected-excised-key)
    (define actual-retained-key (hash-ref-key ht expected-excised-key))
    (define non-key (gensym 'nope))
    (test #t eql? expected-retained-key expected-excised-key)
    (test #t eq? actual-retained-key expected-retained-key)
    (test (eq? eql? eq?) eq? actual-retained-key expected-excised-key)
    (test #t eq? (hash-ref-key ht non-key 'absent) 'absent)
    (test #t eq? (hash-ref-key ht non-key (lambda () 'absent)) 'absent)
    (err/rt-test (hash-ref-key ht non-key) exn:fail:contract?))

  (define (test-hash-ref-key/mut ht eql? expected-retained-key expected-excised-key)
    (hash-set! ht expected-retained-key 'here)
    (hash-set! ht expected-excised-key 'there)
    (test-hash-ref-key ht eql? expected-retained-key expected-excised-key))

  (define (test-hash-ref-key/immut ht eql? expected-retained-key expected-excised-key)
    (define ht1 (hash-set (hash-set ht expected-excised-key 'here)
                          expected-retained-key
                          'there))
    (test-hash-ref-key ht1 eql? expected-retained-key expected-excised-key))

  ;; equal?-based hashes
  (let* ([k1 "hello"]
         [k2 (substring k1 0)])
    (test-hash-ref-key/mut (make-hash) equal? k1 k2)
    (test-hash-ref-key/mut (make-weak-hash) equal? k1 k2)
    (test-hash-ref-key/immut (hash) equal? k1 k2))

  ;; equal-always?-based hashes
  (let* ([k1 "hello"]
         [k2 (string->immutable-string (substring k1 0))])
    (test-hash-ref-key/mut (make-hashalw) equal-always? k1 k2)
    (test-hash-ref-key/mut (make-weak-hashalw) equal-always? k1 k2)
    (test-hash-ref-key/immut (hashalw) equal-always? k1 k2))

  ;; eqv?-based hashes
  (let ([k1 (expt 2 64)]
        [k2 (expt 2 64)])
    (test-hash-ref-key/mut (make-hasheqv) eqv? k1 k2)
    (test-hash-ref-key/mut (make-weak-hasheqv) eqv? k1 k2)
    (test-hash-ref-key/immut (hasheqv) eqv? k1 k2))

  ;; eq?-based hashes
  (test-hash-ref-key/mut (make-hasheqv) eq? 'foo 'foo)
  (test-hash-ref-key/mut (make-weak-hasheqv) eq? 'foo 'foo)
  (test-hash-ref-key/immut (hasheqv) eq? 'foo 'foo))

;; ----------------------------------------
;; Run a GC concurrent to `hash-for-each` or `hash-map`
;; to make sure a disappearing key doesn't break the
;; iteration

(define (check-concurrent-gc-of-keys hash-iterate)
  (define gc-thread
    (thread
     (lambda ()
       (let loop ([n 10])
         (unless (zero? n)
           (collect-garbage)
           (sleep)
           (loop (sub1 n)))))))

  (let loop ()
    (unless (thread-dead? gc-thread)
      (let ([ls (for/list ([i 100])
                  (gensym))])
        (define ht (make-weak-hasheq))
        (for ([e (in-list ls)])
          (hash-set! ht e 0))
        ;; `ls` is unreferenced here here on
        (define counter 0)
        (hash-iterate
         ht
         (lambda (k v)
           (set! counter (add1 counter))
           'ok))
        '(printf "~s @ ~a\n" counter j))
      (loop))))

(check-concurrent-gc-of-keys hash-for-each)
(check-concurrent-gc-of-keys hash-map)
(check-concurrent-gc-of-keys (lambda (ht proc)
                               (equal? ht (hash-copy ht))))
(check-concurrent-gc-of-keys (lambda (ht proc)
                               (equal-hash-code ht)))

;; ----------------------------------------
;; Make sure a new `equal?`-based key is used when the "new" value is
;; `eq?` to the old one:

(let ()
  (define ht (hash))
  (define f (string-copy "apple"))
  (define g (string-copy "apple"))
  (define ht2 (hash-set (hash-set ht f 1) g 1))
  (test 1 hash-count ht2)
  (test #t eq? (car (hash-keys ht2)) g))

;; ----------------------------------------
;; Regression test to make sure all elements are still
;; reachable by iteration in a copy of a mutable hash table:

(let ([ht (make-hash)])
  (for ([i 113])
    (hash-set! ht i 1))
  
  (define new-ht (hash-copy ht))

  (test (hash-count ht) hash-count new-ht)
  (test (for/sum ([k (in-hash-keys ht)])
          k)
        'sum
        (for/sum ([k (in-hash-keys new-ht)])
          k))
  (test (hash-count ht)
        'count
        (for/sum ([v (in-hash-values new-ht)])
          v)))

;; ----------------------------------------
;; Make sure hash-table iteration can call an applicable struct

(let ()
  (struct proc (f) #:property prop:procedure (struct-field-index f))

  (test '(2) hash-map (hash 'one 1) (proc (lambda (k v) (add1 v))))
  (test '(2) hash-map (hasheq 'one 1) (proc (lambda (k v) (add1 v))))
  (test '(2) hash-map (hasheqv 'one 1) (proc (lambda (k v) (add1 v))))
  (test '(2) hash-map (hashalw 'one 1) (proc (lambda (k v) (add1 v))))

  (test (void) hash-for-each (hash 'one 1) (proc void))
  (test (void) hash-for-each (hasheq 'one 1) (proc void))
  (test (void) hash-for-each (hasheqv 'one 1) (proc void))
  (test (void) hash-for-each (hashalw 'one 1) (proc void))

  (test (hash 'one 2) hash-map/copy (hash 'one 1) (proc (lambda (k v) (values k (add1 v)))))
  (test (hasheq 'one 2) hash-map/copy (hasheq 'one 1) (proc (lambda (k v) (values k (add1 v)))))
  (test (hasheqv 'one 2) hash-map/copy (hasheqv 'one 1) (proc (lambda (k v) (values k (add1 v)))))
  (test (hashalw 'one 2) hash-map/copy (hashalw 'one 1) (proc (lambda (k v) (values k (add1 v)))))

  (test (hash 'one 2)
        hash-map/copy
        (make-hash '((one . 1)))
        (proc (lambda (k v) (values k (add1 v))))
        #:kind 'immutable)
  (test (hasheq 'one 2)
        hash-map/copy
        (make-hasheq '((one . 1)))
        (proc (lambda (k v) (values k (add1 v))))
        #:kind 'immutable)
  (test (hasheqv 'one 2)
        hash-map/copy
        (make-hasheqv '((one . 1)))
        (proc (lambda (k v) (values k (add1 v))))
        #:kind 'immutable)
  (test (hashalw 'one 2)
        hash-map/copy
        (make-hashalw '((one . 1)))
        (proc (lambda (k v) (values k (add1 v))))
        #:kind 'immutable))

;; ----------------------------------------

(for ([make-hash (in-list (list make-hash make-weak-hash make-ephemeron-hash))]
      [hash-clear! (in-list (list hash-clear!
                                  (lambda (ht)
                                    (hash-for-each ht (lambda (k v) (hash-remove! ht k))))))]
      [op (in-list (list
                    (lambda (ht ht2) (hash-set! ht ht #t))
                    (lambda (ht ht2) (equal? ht ht2))
                    (lambda (ht ht2) (equal-hash-code ht))
                    (lambda (ht ht2) (equal-secondary-hash-code ht))
                    (lambda (ht ht2) (hash-map ht (lambda (k v) (hash-clear! ht) k)))
                    (lambda (ht ht2) (hash-for-each ht (lambda (k v) (hash-clear! ht) k)))))])
  (define amok? #f)

  (define ht (make-hash))
  (define ht2 (make-hash))

  (struct a (x)
    #:property prop:equal+hash (list (lambda (a1 a2 eql?)
                                       (when amok?
                                         (hash-clear! ht))
                                       (eql? (a-x a1) (a-x a2)))
                                     (lambda (a1 hc)
                                       (when amok?
                                         (hash-clear! ht))
                                       (a-x a1))
                                     (lambda (a2 hc)
                                       (when amok?
                                         (hash-clear! ht))
                                       (a-x a2))))

  (define saved null)
  (define (save v)
    (set! saved (cons v saved))
    v)

  (for ([i (in-range 1000)])
    (hash-set! ht (save (a i)) #t)
    (hash-set! ht2 (save (a i)) #t))

  (set! amok? #t)

  ;; This operation can get stuck or raise an exception,
  ;; but it should not crash
  (let* ([fail? #f]
         [t (thread
             (lambda ()
               (with-handlers ([exn:fail:contract? void]
                               [exn:fail? (lambda (x)
                                            (set! fail? #t)
                                            (raise x))])
                 (op ht ht2))))])
    (sync (system-idle-evt))
    (test #f `(no-crash? ,op) fail?)))

;; ----------------------------------------
;; check `hash-keys` on a table with weakly held keys:

(test #t 'hash-keys 
      (for/and ([i 10000])
        (define ht (make-weak-hasheq))
        (for ([i (in-range 1000)])
          (hash-set! ht (number->string i) i))
        (list? (hash-keys ht))))

;; ----------------------------------------

(test #t hash-ephemeron? (hash-copy-clear (make-ephemeron-hash)))
(test #t hash-ephemeron? (hash-copy-clear (make-ephemeron-hasheq)))
(test #t hash-ephemeron? (hash-copy-clear (make-ephemeron-hasheqv)))
(test #t hash-ephemeron? (hash-copy-clear (make-ephemeron-hashalw)))

(test #f hash-ephemeron? (hash-copy-clear (make-hash)))
(test #f hash-ephemeron? (hash-copy-clear (make-hasheq)))
(test #f hash-ephemeron? (hash-copy-clear (make-hasheqv)))
(test #f hash-ephemeron? (hash-copy-clear (make-hashalw)))

(test #t hash-equal? (hash-copy-clear (make-ephemeron-hash)))
(test #t hash-eq? (hash-copy-clear (make-ephemeron-hasheq)))
(test #t hash-eqv? (hash-copy-clear (make-ephemeron-hasheqv)))
(test #t hash-equal-always? (hash-copy-clear (make-ephemeron-hashalw)))

;; ----------------------------------------

(for ([make-immutable-hash
       (in-cycle
        (list make-immutable-hash make-immutable-hasheq make-immutable-hasheqv))]
      [make-hash
       (in-list
        (list make-immutable-hash make-immutable-hasheq make-immutable-hasheqv
              make-hash make-hasheq make-hasheqv
              make-weak-hash make-weak-hasheq make-weak-hasheqv
              make-ephemeron-hash make-ephemeron-hasheq make-ephemeron-hasheqv))])
  (define (10*v k v) (values k (* 10 v)))
  (test (make-hash '((a . 10) (b . 20))) hash-map/copy (make-hash '((a . 1) (b . 2))) 10*v)
  (test (make-immutable-hash '((a . 10) (b . 20)))
        hash-map/copy
        (make-hash '((a . 1) (b . 2)))
        10*v
        #:kind 'immutable))

;; ----------------------------------------
;; regression test to make sure this doesn't take too long:

(test #t integer? (equal-hash-code (- (expt 2 10000000))))

;; ----------------------------------------

(report-errs)
