prelude: :gerbil/core
  (import :gerbil/expander :std/iter)



(export find-symbol find-expander-context symbol-expander-context)

(def (find-symbol string (context (gx#current-expander-context)))
    "=> /values/ symbol, status (one of inherited:, external: or internal"
    (let* ((s (string->symbol string))
           (binding (hash-get (expander-context-table context) s)))
      (values (if binding s #f)
              (cond ((not binding) #f)
                    ((import-binding? binding) inherited:)
                    ((extern-binding? binding) external:)
                    (else internal:)))))

  (def (find-expander-context context-designator)
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



  (def (symbol-expander-context symbol (context (gx#current-expander-context)))
    (if (uninterned-symbol? symbol)
      #f
      (let (binding (hash-get (expander-context-table context) symbol))
        (cond ((not binding) (gx#current-expander-context))
              ((import-binding? binding)
               (symbol-expander-context symbol (import-binding-context binding)))
              (else context)))))
