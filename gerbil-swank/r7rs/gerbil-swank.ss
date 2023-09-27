(define-library (drewc gerbil-swank r7rs gerbil-swank)
  (export start-swank
          *handlers*
          define-slime-handler
          register-slime-handler!
          find-handler
          write-message

          param:abort
          param:environment
          param:current-id
          $environment
          input-swank-forms
          repl-result-history-ref)
  (import (scheme base) (scheme file) (scheme write) (scheme read) (scheme eval) (scheme repl) (scheme process-context)  (scheme cxr) (scheme char)
          (std srfi |13|) (std srfi |1|)
          (only (gerbil/gambit) open-tcp-server pp random-integer table?)
          (only (gerbil/core) hash-ref hash-put! hash-for-each hash-length
                make-hash-table exit  hash->list filter hash-remove!
                values->list ;; values->list should go when let-values works
                )
          (only (gerbil/expander) module-context? module-context-ns expander-context-id expander-context-table current-expander-module-registry)
          (only (gerbil/runtime/error) display-exception)
          (drewc gerbil-swank swank)
          (drewc gerbil-swank core))
  (include "specific/gerbil.scm")
  (include "common/base.scm")
  (include "common/handlers.scm"))
