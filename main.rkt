#lang racket/base

(require "private/ssh-hack.rkt")
(provide except-out (all-from-out "private/ssh-hack.rkt")
         main)

(module+ main
  (main))
