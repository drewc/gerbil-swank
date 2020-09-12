prelude: :gerbil/core
(import (rename-in :gerbil/core (load gerbil-load))
        :std/sugar :std/generic :gerbil/expander/module <expander-runtime> )
(export load)

(def (load thing . _)
  (def (mod? c)
    (and (syntax-error? c)
         (equal? (error-message c) "Bad syntax; illegal context")))
  (try
   (gerbil-load thing)
   (catch (mod? c) (eval `(begin (import-module ,thing #t #t) (import ,thing))))))
