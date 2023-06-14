#lang info
(define collection "ssh-hack")
(define version "1.0.0")
(define deps '("base"
               "ansi"))
(define racket-launcher-names '("ssh-hack"))

;; It seems dream2nix isn't detecting the launcher so it can't find the load path.  FIXME.
(define racket-launcher-libraries '("main.rkt"))
