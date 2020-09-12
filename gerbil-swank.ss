#!/usr/bin/env gxi
(define-library (drewc gerbil-swank)
  (export start-swank swank:*handlers* swank:define-slime-handler register-slime-handler!
	  swank:lookup-presented-object swank:lookup-presented-object-or-lose
	  repl-result-history-ref)
  (import (scheme base) (scheme file) (scheme write) (scheme read) (scheme eval) (scheme repl) (scheme process-context)  (scheme cxr) (scheme char)
          (std srfi |13|) (std srfi |1|)
          (only (gerbil/gambit) open-tcp-server pp random-integer table?)
          (only (gerbil/core) hash-ref hash-put! hash-for-each hash-length
                make-hash-table exit  hash->list filter hash-remove!
                values->list ;; values->list should go when let-values works
                ) 
          (only (gerbil/expander) module-context? module-context-ns expander-context-id expander-context-table current-expander-module-registry)
          (only (gerbil/gambit/exceptions) display-exception)
          (drewc gerbil-swank swank)
          (drewc gerbil-swank core))
  (include "specific/gerbil.scm")
  (include "common/base.scm")
  (include "common/handlers.scm"))

(define swank:*handlers* *handlers*)

(define-syntax swank:define-slime-handler
  (syntax-rules ()
    ((_ thedef thefun ...)
     (define-slime-handler thedef thefun ...))))
