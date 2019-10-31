#!/usr/bin/env racket
#lang racket/base

(require racket/cmdline
         racket/list
         racket/match
         racket/string
         ansi)

#|
TODO: Put the following commented text into the command-line help.

DGL Connector

Usage: ssh-hack alias

Make a config file at $HOME/.config/ssh-hack.rktd containing the following
structure:

(#s{service
    #s{ssh-server "nethack" "alt.org" 22}
    ("nao" "alt")
    "your-DGL-auth-username"
    "your-DGL-auth-password"}
 #s{service
   #s{ssh-server "ssh-username" "ssh-host" 22}
   ("aliases" "to" "use" "here") ; or #f to only match by ssh-host
   "your-other-DGL-auth-username"
   "your-other-DGL-auth-password"})
|#

(provide (all-defined-out))

(struct ssh-server [user host port] #:prefab)
(struct service [server aliases user password] #:prefab)

(define (aliases->string aliases)
  (if (and aliases (not (empty? aliases)))
      (string-append "[" (string-join aliases ",") "]")
      "(no aliases)"))

(define service->string
  (match-lambda
    [(struct* service ([aliases aliases] [user user]
                       [server (struct* ssh-server ([user ssh-user] [host host] [port port]))]))
     (format "~a at ~a@~a~a~a"
             user ssh-user host
             (if (= 22 port) "" (string-append " " (number->string port)))
             (if (or (not aliases) (empty? aliases))
                 ""
                 (string-append " " (aliases->string aliases))))]))

(define config-path (make-parameter (build-path (find-system-path 'home-dir) ".config" "ssh-hack.rktd")))

(define (read-config path)
  (match (read (open-input-file path))
    [(list ls ...) (sort ls string-ci<? #:key (compose1 ssh-server-host service-server))]
    [(and s (struct* service ())) (list s)]))

(define (get-services) (read-config (config-path)))

(define (ssh the-service)
  (parameterize (#;[current-subprocess-custodian-mode #f]
                 [current-environment-variables (environment-variables-copy (current-environment-variables))])
    (match-define (struct* service ([user user] [password password]
                                    [server (struct* ssh-server ([user ssh-user] [port port] [host host]))]))
      the-service)
    (define ssh-path (find-executable-path "ssh"))
    (unless ssh-path
      (error 'ssh "Cannot locate path of ssh executable"))
    (putenv "DGLAUTH" (string-append user ":" password))

    (match (system-type 'os)
      [(or 'macosx 'unix)
       (display (xterm-set-window-title (format "ssh-hack :: ~a" (service->string the-service))))
       (flush-output (current-output-port))]
      [_ (void)])

    (define-values (ssh-subprocess stdout stdin stderr)
      (subprocess (current-output-port)
                  (current-input-port)
                  (current-error-port)
                  ssh-path
                  "-oSendEnv=DGLAUTH"
                  (string-append "-p" (number->string port))
                  (string-append "-l" ssh-user)
                  host))
    (subprocess-wait ssh-subprocess)
    (subprocess-status ssh-subprocess)))

(module+ main
  (define alias
    (command-line
     #:program "ssh-hack"
     #:once-each
     [("-l" "--list") "List possible services"
      (for ([s (get-services)])
        (displayln (service->string s)))
      (exit 0)]
     [("-c" "--config") alternate-config-path "Specify alternate config path"
      (config-path (string->path alternate-config-path))]
     #:args (alias)
     alias))
  (define matches
    (filter (match-lambda
              [(struct* service ([aliases aliases] [server (struct* ssh-server ([host host]))]))
               (member alias (cons host aliases) string-ci=?)])
            (get-services)))
  (match matches
    [(list)
     (displayln "No matches :(" (current-error-port))
     (exit 1)]
    [(list ls ..2)
     (parameterize ([current-output-port (current-error-port)])
       (displayln "Multiple matching aliases/hostnames in the config file:")
       (for ([s ls])
         (displayln (format "  ~a" (service->string s))))
       (exit 1))]
    [(list a) (exit (ssh a))]))
