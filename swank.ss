(import :drewc/gerbil-swank/context :std/sugar :gerbil/expander )
    (export swank:function-parameters-and-documentation)

    (def (swank:function-parameters-and-documentation string (context (gx#current-expander-context)))
      (def (further-decompile-args lst)
        (def (remove-underscores-and-trailing-numbers str)
          (def last (- (string-length str) 1))
          (cond ((char-numeric? (string-ref str last))
                 (remove-underscores-and-trailing-numbers (substring str 0 last)))
                ((char=? (string-ref str last) #\_)
                 (remove-underscores-and-trailing-numbers (substring str 0 last)))
                ((char=? (string-ref str 0) #\_)
                 (remove-underscores-and-trailing-numbers (substring str 1 (+ last 1))))
                (else
                 (string->symbol str))))
        (def (xmap fun lst)
          (if (null? lst)
            '()
            (if (not (pair? lst))
              'args
              (cons (fun (car lst)) (xmap fun (cdr lst))))))
        (try 
         (xmap (lambda (sym)
                 (let ((s (symbol->string sym)))
                   (remove-underscores-and-trailing-numbers s)))
               lst)
         (catch (_) 'args)))
    
      ;; If there's a symbol in this context, return it.
      (def symbol
        (let (s (find-symbol string context ))
          (if s (with ((values s _) s) s))))
    
    
      ;;tell me the context from which the symbol comes
      (def doc-context
        (when symbol (symbol-context symbol)))
    
      ;; If it's a procedure, return it. 
      (def proc 
        (if symbol
          (let (v (try (##eval symbol context)
                       (catch (_) #f)))
            (if (and v (procedure? v))
              v
              #f))
          #f))
      ;; If we have a function, try to find the args 
      (def args
        (when proc
          (let (form 
                (try (##decompile proc)
                     (catch (_) 'args)))
            (if (pair? form)
              (case (car form)
                ((lambda ##lambda)
                 (further-decompile-args (cadr form)))
                (else form))
              'args))))
    
    ;;; otherwise, gimmie the binding and be done with it.
    
      (def binding (when symbol (resolve-identifier symbol 0 context)))
    
      (def syntax (if (and symbol (syntax-binding? binding))
                    (begin0 #t (set! args 'syntax))
                    #f))
    
      (if (or proc syntax)
        (cons (cons symbol args)
              (with-output-to-string
                (lambda ()
                  (display "Context: ")
                  (display (expander-context-id doc-context)))))
        (cons #f #f)))
