(import :gerbil/expander :std/iter)



(export find-symbol find-context symbol-context)

(def (find-symbol string (context (gx#current-expander-context)))
  (let* ((s (string->symbol string))
         (binding (hash-get (expander-context-table context) s)))
    (values (if binding s #f)
            (cond ((not binding) #f)
                  ((import-binding? binding) inherited:)
                  ((extern-binding? binding) external:)
                  (else internal:)))))

(def (find-context context-designator)
  (if (expander-context? context-designator)
    context-designator 
    (let ((tbl (gx#current-expander-module-registry))
          (symbol (if (string? context-designator)
                    (string->symbol context-designator)
                    context-designator))
          (string (if (symbol? context-designator)
                    (symbol->string context-designator)
                    context-designator)))
      (or (hash-get tbl symbol)
          (hash-get tbl string)
          (call/cc (lambda (cc)
                     (for ((values k v)
                           (in-hash tbl))
                       (when (eq? symbol (expander-context-id v))
                         (cc v)))
                     (cc #f)))))))



(def (symbol-context symbol (context (gx#current-expander-context)))
    (let (binding (hash-get (expander-context-table context) symbol))
        (cond ((not binding) #f)
              ((import-binding? binding)
               (symbol-context symbol (import-binding-context binding)))
              (else context))))
