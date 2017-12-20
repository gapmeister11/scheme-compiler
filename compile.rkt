#lang racket

(provide compile-test)

(require "utils.rkt")
(require "top-level.rkt")
(require "desugar.rkt")
(require "cps.rkt")
(require "closure-convert.rkt")

(define debug #f)
(define optimize #f)
(define clang_loc "clang++")

(define recent-header #f)
(define (eval-llvm llvm-str)
  ; freshly compile the header / runtime library if not already
  (when (not recent-header)
        (set! recent-header #t)
        (system (string-append clang_loc (cond [debug " -g"] [optimize " -O2"] [else " "]) " -DNEDTRIE_ENABLE_STL_CONTAINERS -I include -std=c++11 header.cpp -S -emit-llvm -o header.ll")))
  (define header-str (read-string 299999 (open-input-file "header.ll" #:mode 'text)))
  (define llvm (string-append header-str "\n\n;;;;;;\n\n" llvm-str))
  (display llvm (open-output-file "combined.ll" #:exists 'replace))
  (system (string-append clang_loc " -std=c++11 " (cond [debug " -g"] [optimize " -O2"] [else " "]) " -pthread -c combined.ll"))
  (system (string-append clang_loc " -std=c++11 " (cond [debug " -g"] [optimize " -O2"] [else " "]) " -I include -pthread combined.o libgc-lib.a -o bin"))
  (match-define `(,out-port ,in-port ,id ,err-port ,callback) (process "./bin"))
  (define starttime (current-milliseconds))
  (let loop ()
    ;(sleep 1)
    (define time (current-milliseconds))
    (define status (callback 'status))
    (if (> time (+ starttime 12000))
        (begin (pretty-print '(eval-llvm "binary execution timed out")) (void))
        (if (eq? status 'done-ok)
            ; use a read to turn the printed value back into a racket value
            (let ([v (eval (read out-port) (make-base-namespace))])
              (callback 'kill)
              v)
            (if (eq? status 'done-error)
                (begin (pretty-print '(eval-llvm "bad status code")) (void))           
                (loop))))))

(define (runtime e) ; Add checks for some runtime errors (run immediately before top-level)

  ; Runtime errors
  (define error-div0 (gensym 'err))
  
  (define (rt-helper e)
    (match e
      [`(/ ,z ,ws ...)
       (define nz (gensym 'z))
       (define nws (map (lambda (x) (gensym 'w)) ws))
       `(letrec ([,nz ,(rt-helper z)] ,@(map (lambda (w nw)
                                               `(,nw ,(rt-helper w))) ws nws))
          (if (or ,@(map (lambda (x)
                           `(= ,x 0)) nws))
              (raise ,error-div0)
              (/ ,nz ,@nws)))]
      [`(define ,x ,e)
       `(define ,x ,(rt-helper e))]
      [`(define (,proc ,args ... ) ,es ..1)
       `(define (,proc ,@args) (begin ,@(map rt-helper es)))]
      [`(define (,proc ,args ... . ,lastarg) ,es ..1)
       `(define (,proc ,@args . ,lastarg) (begin ,@(map rt-helper es)))]
      [`(letrec* ([,xs ,ys] ...) ,es ..1)
       `(letrec* ,(map (lambda (x y)
                         `(,x ,(rt-helper y))) xs ys) ,@(map rt-helper es))]
      [`(letrec ([,xs ,ys] ...) ,es ..1)
       `(letrec ,(map (lambda (x y)
                        `(,x ,(rt-helper y))) xs ys) ,@(map rt-helper es))]
      [`(let* ([,xs ,ys] ...) ,es ..1)
       `(let* ,(map (lambda (x y)
                      `(,x ,(rt-helper y))) xs ys) ,@(map rt-helper es))]
      [`(let ([,xs ,ys] ...) ,es ..1)
       `(let ,(map (lambda (x y)
                     `(,x ,(rt-helper y))) xs ys) ,@(map rt-helper es))]
      [`(let ,proc ([,xs ,ys] ...) ,es ..1)
       `(let ,proc ,(map (lambda (x y)
                           `(,x ,(rt-helper y))) xs ys) ,@(map rt-helper es))]
      [`(lambda (,xs ...) ,es ..1)
       `(lambda ,xs ,@(map rt-helper es))]
      [`(lambda ,x ,es ..1)
       `(lambda ,x ,@(map rt-helper es))]
      [`(lambda (,xs ... . ,finx) ,es ..1)
       `(lambda (,@xs . ,finx) ,@(map rt-helper es))]
      [`(dynamic-wind ,pre ,body ,post)
       `(dynamic-wind ,(rt-helper pre) ,(rt-helper body) ,(rt-helper post))]
      [`(guard (,x ,clauses ...) ,e)
       `(guard (,x ,@(map (lambda (x)
                            (match x
                              [`(,e0 ,e1)
                               `(,(rt-helper e0) ,(rt-helper e1))]
                              [`(else ,es ..1)
                               `(else ,@(map rt-helper es))]
                              [`(,e)
                               `(,(rt-helper e))])) clauses)) ,(rt-helper e))]
      [`(raise ,e)
       `(raise ,(rt-helper e))]
      [`(delay ,e)
       `(delay ,(rt-helper e))]
      [`(force ,e)
       `(force ,(rt-helper e))]
      [`(and ,es ...)
       `(and ,@(map rt-helper es))]
      [`(or ,es ...)
       `(or ,@(map rt-helper es))]
      [`(cond ,clauses ...)
       `(cond ,@(map (lambda (x)
                            (match x
                              [`(,e0 ,es ..1)
                               `(,(rt-helper e0) ,@(map rt-helper es))]
                              [`(else ,es ..1)
                               `(else ,@(map rt-helper es))]
                              [`(,e)
                               `(,(rt-helper e))])) clauses))]
      [`(case ,e ,clauses ...)
       `(case ,(rt-helper e) ,@(map (lambda (x)
                                      (match x
                                        [`((,dats ...) ,es ..1)
                                         `(,dats ,@(map rt-helper es))]
                                        [`(else ,es ..1)
                                         `(else ,@(map rt-helper es))])) clauses))]
      [`(if ,e0 ,e1 ,e2)
       `(if ,(rt-helper e0) ,(rt-helper e1) ,(rt-helper e2))]
      [`(when ,e0 ,es ..1)
       `(when ,(rt-helper e0) ,@(map rt-helper es))]
      [`(unless ,e0 ,es ..1)
       `(unless ,(rt-helper e0) ,@(map rt-helper es))]
      [`(set! ,x ,e)
       `(set! ,x ,(rt-helper e))]
      [`(begin ,es ..1)
       `(begin ,@(map rt-helper es))]
      [`(call/cc ,e)
       `(call/cc ,(rt-helper e))]
      [`(apply ,e0 ,e1)
       `(apply ,(rt-helper e0) ,(rt-helper e1))]
      [`(quasiquote ,qq)
       (define (fix-qq qq)
         (match qq
           [`(quasiquote ,q)
            `(quasiquote ,(fix-qq q))]
           [(list 'unquote q)
            (list 'unquote (fix-qq q))]
           [(? datum? dat)
            dat]
           [`(,qqs ..1)
            (map fix-qq qqs)]
           [`(,qqs ..1 . ,lastq)
            `(,@(map rt-helper qqs) . ,(rt-helper lastq))]
           [e
            (rt-helper e)]))
       (list 'quasiquote (fix-qq qq))]
      [(? prim? p)
       p]
      [(? symbol? x)
       x]
      [(? datum? dat)
       dat]
      [`(quote ,(? datum? dat))
       `(quote ,dat)]
      [`(,fun ,args ...)
       `(,(rt-helper fun) ,@(map rt-helper args))]))
  (define errval (gensym 'err))
  `(let ([,error-div0 (quote ,(random 4294967087))])
     (guard [,errval (,error-div0 '"Error: division by zero")]
            (begin ,(rt-helper e)))))

(define (compile-test filename)
  (define fptr (open-input-file filename))
  (define scheme (top-level (runtime (read-begin fptr))))
  (define clo (closure-convert
               (cps-convert
                (anf-convert
                 (alphatize
                  (assignment-convert
                   (simplify-ir
                    (desugar scheme))))))))
  (define llvm (proc->llvm
                clo))
  (define clofile (open-output-file "clo.scm" #:exists 'truncate/replace))
  (pretty-print clo clofile)
  (close-output-port clofile)
  (if (regexp-match? #rx"fail-." filename)
      (eval-llvm llvm)
      (let ([control (eval-top-level scheme)] [test (eval-llvm llvm)])
        (equal? control test))))


(define cmd (vector->list (current-command-line-arguments)))

(if (memv "-O" cmd)
    (set! optimize #t)
    (when (memv "-g" cmd)
        (set! debug #t)))

(for-each (lambda (x)
            (when (regexp-match? #rx"-CL" x)
              (define cl (car (string-split x "-CL")))
              (set! clang_loc (string-append cl "/clang++")))) cmd)