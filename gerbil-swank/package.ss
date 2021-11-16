(export #t)
(import :gerbil/expander :std/sugar <expander-runtime>)

(extern namespace: #f &context? &context-t)

(def (package-name package)
  (def pkg (find-package package))
  (symbol->string ((if (&context? pkg) &context-t gx#expander-context-id) pkg)))

(def (find-package name)
  (cond ((expander-context? name) name)
        ((or (and (string? name)
                  (or (string=? name "(user)")
                      (string=? name "top")))
             (and (symbol? name) (eq? name 'nil)))
         (gx#current-expander-context))
        (else
         (let ((name (if (string? name)
                       (string->symbol name)
                       name)))
           (find (lambda (e) (eq? (expander-context-id e) name))
                 (filter expander-context? (map cdr (hash->list (gx#current-expander-module-registry)))))))))


(defrule (do-context-symbols (name package) body ...)
  (let ((cxt (find-package package)))
    (for-each (lambda (x) (let ((name (car x))) body ...))
              (table->list (expander-context-table cxt)))))

(defrule (do-symbols (name package) body ...)
  (let do-package ((cxt (find-package package)))
    (do-context-symbols (name cxt) body ...)
    (let ((pre (gx#core-context-prelude cxt)))
      (unless (or (eq? pre cxt) (not pre)) (do-package pre)))))
