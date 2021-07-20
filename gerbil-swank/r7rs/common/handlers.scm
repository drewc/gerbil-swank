(define *listener-value* #f)

(define-syntax define-slime-handler
  (syntax-rules ()
    ((define-slime-handler (name . params) body0 body1 ...)
     (register-slime-handler! 'name (lambda params body0 body1 ...)))))

(define-slime-handler (:emacs-rex sexp env-name thread id)
  (call-with-current-continuation
   (lambda (exit)
     (parameterize ((param:abort (lambda (message)
                                   (exit `(:return (:abort ,message)
                                                   ,id))))
                    (param:environment ($environment env-name))
                  (param:current-id id))
       `(:return (:ok ,(process-form sexp env-name))
                 ,id)))))

(define-slime-handler (swank:connection-info)
  `(:pid 123
         :style :spawn
         :encoding (:coding-systems ("utf-8-unix"))
         :lisp-implementation (:type "Scheme" :name ,($scheme-name) :version 123 :program "/usr/bin/scheme")
         :machine (:instance "host" :type "X86-64")
         :features (:swank)
         :modules ("SWANK-ARGLISTS" "SWANK-REPL" "SWANK-PRESENTATIONS")
         :package (:name "(user)" :prompt "(user)")
         :version "2.24"))

(define-slime-handler (swank:swank-require packages)
  '())

(define-slime-handler (swank:init-presentations)
  '())

(define-slime-handler (cl:nth-value num form)
  (call-with-values
      (lambda () (process-form form (param:environment)))
    (lambda values (list-ref values num))))

(define-slime-handler (swank:lookup-presented-object num)
  (swank:lookup-presented-object num))

(define-slime-handler (swank-repl:create-repl . args)
  (list "(user)" "(user)"))

(define-slime-handler (swank-repl:listener-eval form)
  (let* ((form (replace-readtime-lookup-presented-object-or-lose form))
	 (results ($output-to-repl (lambda () (interactive-eval (cons 'begin (read-all (open-input-string form))))))))
    (for-each (lambda (val)
                (if (presentations?)
                    (present val ':repl-result)
                    (swank/write-string val 'repl-result)))
              results)
    '()))

(define-slime-handler (swank:quit-lisp)
  (exit 0))

(define-slime-handler (swank:list-all-package-names . args)
  ($all-package-names))

(define-slime-handler (swank:completions prefix env-name)
  (let ((completions+prefix ($completions prefix (unquote-string env-name))))
    (list (car completions+prefix)
          (cdr completions+prefix))))

(define-slime-handler (swank:simple-completions prefix env-name)
  ;; TODO: for now, just copy swank:completions
  (let ((completions+prefix ($completions prefix (unquote-string env-name))))
    (list (car completions+prefix)
          (cdr completions+prefix))))

(define-slime-handler (swank:fuzzy-completions string package . limits)
  (define (swank-completions->fuzzy completions+prefix)
    (let* ((c (car completions+prefix))
           (n (length c))
           (p (list (list 0 (cdr completions+prefix))))
           (classification-string "--------"))
      (list (map (lambda (c) (let ((score n))
                               (set! n (- n 1))
                               (list c (number->string score) p classification-string)))
                 c)
            0)))
  (swank-completions->fuzzy ($completions string (unquote-string package))))

(define-slime-handler (swank:compile-string-for-emacs form buffer position filename policy)
  ;; TODO: for now, just evaluate, copy of listener-eval
  (let ((results ($output-to-repl (lambda () (interactive-eval (cons 'begin (read-all (open-input-string form))))))))
    (for-each (lambda (val)
		(swank/write-string val 'repl-result))
              results)
    `(:compilation-result nil t 0.001 nil nil)))

(define-slime-handler (swank:fuzzy-completion-selected original-string completion)
  ;; This function is called by Slime when a fuzzy completion is selected by the
  ;; user. It is for future expansion to make testing, say, a machine learning
  ;; algorithm for completion scoring easier.

  ;; ORIGINAL-STRING is the string the user completed from, and COMPLETION is
  ;; the completion object (see docstring for SWANK:FUZZY-COMPLETIONS)
  ;; corresponding to the completion that the user selected.
  'nil)
(define-slime-handler (swank:load-file filename)
  (let ((results ($output-to-repl (lambda () (load filename (param:environment))))))
    'loaded))

(define-slime-handler (swank:set-package name)
  ($set-package name))

(define-slime-handler (swank:operator-arglist op-string env-name)
  (let* ((signature+doc ($function-parameters-and-documentation op-string))
         (signature (car signature+doc)))
    (if signature
        (write-to-string signature)
        "")))

(define-slime-handler (swank:autodoc expr . params)
  (let* ((op-string (find-string-before-swank-cursor-marker expr)))
    (if op-string
        (let* ((signature+doc ($function-parameters-and-documentation op-string))
               (signature (car signature+doc))
               (doc (cdr signature+doc)))
          (let ((answer (if signature (let* ((signature (highlight-at-cursor signature expr)))
                                        (with-output-to-string (lambda ()
                                                                 (write signature)
                                                                 (if (and doc
                                                                          (not (string=? "" doc)))
                                                                     (begin
                                                                       (display " -- ")
                                                                       (display doc))))))
                            ':not-available)))
            (list answer 't)))
        (list ':not-available 't))))

(define-slime-handler (swank:frame-locals-and-catch-tags nr)
  ;; (:return
  ;;  (:ok
  ;;   (((:name "X" :id 0 :value "1")
  ;;     (:name "Y" :id 0 :value "0"))
  ;;    nil))
  ;;  8)
  ($frame-locals-and-catch-tags nr))

(define-slime-handler (swank:throw-to-toplevel)
  (set! *throw-to-top-level* #t)
  (swank/abort (param:condition:msg)))

(define-slime-handler (swank:backtrace from to)
  ;; (:return
  ;;  (:ok
  ;;   (((:name "X" :id 0 :value "1")
  ;;     (:name "Y" :id 0 :value "0"))
  ;;    nil))
  ;;  8)
  (let ((trace ($condition-trace (param:active-condition))))
    (let ((from (min from (length trace)))
          (to (min to (length trace))))
      (take (list-tail trace from) (- to from)))))

(define-slime-handler (swank:init-inspector string-form)
  (reset-inspector)
  (let ((vals (interactive-eval (cons 'begin (read-all (open-input-string string-form))))))
    (inspect-object (car vals))))

(define-slime-handler (swank:inspector-range from to)
  (prepare-inspector-range (istate-parts inspector-state)
                           (istate-actions inspector-state)
                           (istate-content inspector-state)
                           from to))

(define-slime-handler (swank:inspect-nth-part index)
  (inspect-object (hash-table-ref/default (istate-parts inspector-state) index 'no-such-part)))

(define-slime-handler (swank:inspector-call-nth-action index)
  ((hash-table-ref/default (istate-actions inspector-state) index (lambda () #f)))
  (inspect-object (istate-object inspector-state)))

(define-slime-handler (swank:inspector-pop)
  (if (and inspector-state (istate-previous inspector-state))
      ;; bug in chibi with begin
      (let ()
        (set! inspector-state (istate-previous inspector-state))
        (istate->elisp inspector-state))
      'nil))

(define-slime-handler (swank:inspector-next)
  (if (istate-next inspector-state)
      (let ()
        (set! inspector-state (istate-next inspector-state))
        (istate->elisp inspector-state))
      'nil))

(define-slime-handler (swank:inspector-reinspect)
  (istate->elisp inspector-state))

(define-slime-handler (swank:inspector-toggle-verbose)
  ;; seems to toggle how the title is shown in sbcl
  (istate->elisp inspector-state))

(define-slime-handler (swank:inspector-history)
  ;; (:return
  ;;  (:ok "--- next/prev chain ---
  ;;   @2 #<BASE-CHAR {149}>
  ;;   @1 #<BIT {2}>
  ;;  *@0 #<(SIMPLE-VECTOR 3) {1001AF0EAF}>

  ;; --- all visited objects ---
  ;;  0 #<(SIMPLE-VECTOR 3) {1001AF0EAF}>
  ;;  1 #<BIT {2}>
  ;;  2 #<BASE-CHAR {149}>")
  ;;  14)
  (define (add-line current i result)
    (string-append result
                   " " (if (eq? current inspector-state) "*" " ")
                   "@" (number->string i)
                   " " (ellipsize (write-to-string (istate-object current)))
                   "\n"))
  (let ((first (let loop ((start inspector-state))
                 (if (istate-previous start)
                     (loop (istate-previous start))
                     start))))
    (let loop ((result "--- next/prev chain ---\n")
               (i 0)
               (current first))
      (if (istate-next current)
          (loop (add-line current i result)
                (+ i 1)
                (istate-next current))
          (add-line current i result)))))

(define-slime-handler (swank:pprint-inspector-part index)
  (with-output-to-string
    (lambda ()
      ($pretty-print (hash-table-ref/default (istate-parts inspector-state) index 'no-such-part)))))

;; inspector, M-RET
;; (define-slime-handler (swank:listener-save-value type index)
;;   'todo)

;; (define-slime-handler (swank:listener-get-value)
;;   'todo)
(define-slime-handler (swank:inspect-presentation id reset?)
  (when reset?
    (reset-inspector))
  (inspect-object (hash-table-ref/default *presentations* (unquote-number id) #f)))

(define-slime-handler (swank:inspect-frame-var frame index)
  (reset-inspector)
  (inspect-object ($frame-var-value frame index)))

(define-slime-handler (swank:frame-source-location index)
  ;; (:location
  ;;  (:file "/usr/share/sbcl-source/src/code/numbers.lisp")
  ;;  (:position 14095)
  ;;  (:line line column)
  ;;  (:snippet "(define-arith + 0\n    \"Return the sum of its arguments. With no args, returns 0.\")\n  (define-arith * 1\n    \"Return the product of its arguments. With no args, returns 1.\"))\n\n(defun - (number &rest more-numbers)\n  \"Subtract the second and all subsequent arg"))
  (let ((loc ($condition-location (list-ref (param:active-continuations) index))))
    (if loc
        (let ((file (list-ref loc 0))
              (position (list-ref loc 1))
              (line (list-ref loc 2))
              (column (list-ref loc 3)))
          `(:location
            (:file ,file)
            ,@(if position `((:position ,position)) '())
            ,@(if line `((:line ,line ,column)) '())
            (:snippet "")))
        `(:error "No location found."))))

(define-slime-handler (swank:interactive-eval form)
  (let* ((results ($output-to-repl (lambda () (interactive-eval (cons 'begin (read-all (open-input-string form)))))))
         (count (length results)))
    (cond ((= count 1)
           (string-append "=> " (display-to-string (car results))))
          ((= count 0)
           "; No value")
          (else
           (let ((vs (map display-to-string results)))
             (let loop ((vals (cdr vs))
                        (result (string-append "=> " (car vs))))
               (if (null? vals)
                   result
                   (loop (cdr vals)
                         (string-append result ", " (car vals))))))))))

(define-slime-handler (swank:buffer-first-change filename)
  'nil)

(define-slime-handler (swank:apropos-list-for-emacs name external-only? case-sensitive? package)
  (map (lambda (el)
         (let ((name (car el))
               (type (cadr el))
               (documentation (or (caddr el) ':not-documented)))
           `(:designator ,(write-to-string name) ,type ,documentation)))
   ($apropos name)))

(define-slime-handler (swank:describe-definition-for-emacs name type)
  (describe-symbol name))

(define-slime-handler (swank:describe-symbol name)
  (describe-symbol name))

(define-slime-handler (swank:describe-function name)
  (describe-symbol name))

(define-slime-handler (swank:list-threads)
  `((:id :name :status)
    (1 "repl-thread" "Running")))

(define-slime-handler (swank:clear-repl-results)
  ;; don't do anything, CL clears all presentations
  (set! *presentations* (make-hash-table))
  't)

(define-slime-handler (swank-repl:clear-repl-variables)
  ;; don't do anything, CL clears *** ** * /// // / +++ ++ + here
  'nil)

(define-slime-handler (swank-repl:listener-save-value fun . args)
  ;; fun is (quote ...)
  (set! fun (cadr fun))
  (case fun
    ((swank:inspector-nth-part)
     (let ((index (car args)))
       (set! *listener-value* (hash-table-ref/default (istate-parts inspector-state) index 'no-such-part))
       't))
    (else
     (swank/abort (string-append "Unknown swank-repl:listener-save-value function: " (symbol->string fun))))))

(define-slime-handler (swank-repl:listener-get-value)
  (if (presentations?)
      (present *listener-value* ':repl-result)
      (swank/write-string *listener-value* 'repl-result)))

(define-slime-handler (swank:complete-form expr)
  (let* ((op-string (find-string-before-swank-cursor-marker expr))
         (form (filter (lambda (el) (not (and (string? el) (string=? "" el)))) (find-expression-containing-swank-cursor-marker expr))))
    (if op-string
        (let* ((signature+doc ($function-parameters-and-documentation op-string))
               (signature (car signature+doc))
               (provided-param-count (- (length form) 1)))
          (let loop ((os (open-output-string))
                     (lst (list-tail signature provided-param-count))
                     (space? #f))
            (cond ((null? lst)
                   (get-output-string os))
                  ((symbol? lst)
                   (when space?
                       (display " " os))
                   (display lst os)
                   (display "..." os)
                   (get-output-string os))
                  ((list? lst)
                   (when space?
                     (display " " os))
                   (display (car lst) os)
                   (loop os (cdr lst) #t)))))
        ':not-available)))

(define-slime-handler (swank:value-for-editing name)
  (write-to-string (binding-value (string->symbol name))))

(define-slime-handler (swank:commit-edited-value name value-string)
  (let ((v (read-from-string value-string)))
    (interactive-eval `(set! ,(string->symbol name) ',v))
    't))

(define-slime-handler (swank:swank-expand-1 form)
  (let ((v (read-from-string form)))
    (write-to-string ($macroexpand-1 v))))

(define-slime-handler (swank:swank-macroexpand-all form)
  (let ((v (read-from-string form)))
    (write-to-string ($macroexpand-all v))))

(define-slime-handler (swank:inspect-current-condition)
  (inspect-object (param:active-condition)))

(define-slime-handler (swank::menu-choices-for-presentation-id id)
  'nil)

(define-slime-handler (swank::describe-to-string object)
  (object-documentation (write-to-string object) (interactive-eval object)))
