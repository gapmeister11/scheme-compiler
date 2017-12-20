#lang racket

(require "compile.rkt")

(provide test)

(define (test name)
  (match name
    ["all"
     (define tests (map (lambda (x)
                          (car (string-split (path->string x) ".scm"))) (directory-list "tests/")))
     (define results (map test tests))
     (if (ormap (lambda (x) x) results)
         (begin
           (display "All tests successful.\n")
           #t)
         (begin
           (for-each (lambda (r t)
                       (unless r
                         (display t)
                         (display " failed.\n"))) results tests)
           #f))]
    [else
     (define filename (string-append "tests/" name ".scm"))
     (if (file-exists? filename)
         (if (compile-test filename)
             #t
             (begin
               (display (string-append "Test " name " failed.\n"))
               #f))
         (begin
           (display (string-append "Test " name " does not exist\n"))
           #f))]))

(define cmd (vector->list (current-command-line-arguments)))

(define name (foldl (lambda (x t) (if (regexp-match #rx"^[^-].*$" x)
                         x
                         t)) #f cmd))

(when name
  (test name))