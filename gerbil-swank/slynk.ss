(import :std/os/pid
        :std/sugar :std/format
        :gerbil/gambit
        :gerbil/expander
        :drewc/gerbil-swank/package
        (prefix-in :drewc/gerbil-swank/r7rs/gerbil-swank |rswank:|))


(def (slynk-version-string) "1.0.43")

(def (connection-info
      version: (v (slynk-version-string))
      features: (features '(:slynk))
      modules: (modules '("SLYNK/ARGLISTS"
                          "SLYNK/MREPL"
                         "SLYNK/FANCY-INSPECTOR"
                         "SLYNK/PACKAGE-FU"
                          "SLYNK/TRACE-DIALOG"
                         "SLYNK/STICKERS"
                         "SLYNK/INDENTATION"
                          "SLYNK/COMPLETION")))
  `(:pid ,(getpid) :version ,v
    :modules ,modules
    :features ,features
    :package (:name "(user)" :prompt "top")
    :style :spawn :encoding (:coding-systems ("utf-8-unix"))
    :machine (:instance ,(host-name) :type "X86-64")
    :lisp-implementation (:type "Scheme" :name "gerbil"
                          :version ,(gerbil-version-string) :program nil)))

(rswank:register-slime-handler! 'slynk:connection-info connection-info)


(def (:channel-send chann form)
  (rswank:write-message `(:channel-send ,chann ,form)))

(def emacs-channels (make-hash-table-eqv))

(def current-emacs-channel (make-parameter #f))

(defstruct emacs-channel (id package values)
  constructor: :init!)


(defmethod {:init! emacs-channel}
  (lambda (self (id (+ 1 (hash-length emacs-channels)))
                (package (find-package "(user)"))
                (values (make-hash-table)))
    (set! (emacs-channel-id self) id)
    (set! (emacs-channel-package self) package)
    (set! (emacs-channel-values self) values)
    (hash-put! emacs-channels id self)))

(def (find-emacs-channel id)
  (hash-get emacs-channels id))

(def (ensure-emacs-channel id)
  (or (find-emacs-channel id)
      (make-emacs-channel)))

(def (emacs-channel-prompt chan)
  (def pkg (emacs-channel-package chan))
  (def pn (package-name pkg))
  `(:prompt ,pn ,pn 0))
(defalias current-emacs-channel-abort rswank:param:abort)
(defalias current-emacs-channel-package rswank:param:environment)
(defalias current-emacs-channel-id rswank:param:current-id)

(def emacs-channel-handlers (make-hash-table))

(def (register-emacs-channel-handler! name fn)
  (hash-put! emacs-channel-handlers name fn))

(def (find-emacs-channel-handler name)
  (hash-get emacs-channel-handlers name))

(def (with-output-to-emacs-channel chan thunk)
  (def id (emacs-channel-id chan))
  (def OUT (open-string))
  (parameterize ((current-output-port OUT)
                 (current-error-port OUT))
    (try
     (spawn
      (lambda ()
;;; (:channel-send id `(:write-string "Spawning write thing"))
        (let lp ((o? (peek-char OUT)))
          #;(:channel-send
          id `(:write-string ,(with-output-to-string "o? =>" (cut write o?))))
          (if  (eof-object? o?) o?
               (begin
                 (:channel-send id `(:write-string ,(get-output-string OUT)))
                 (lp (peek-char OUT)))))))
     ;;; (:channel-send id `(:write-string "trying thunk\n"))

     (let ((ret (thunk)))
       (thread-yield!)
       #;(:channel-send
        id `(:write-string ,(with-output-to-string
                              " => " (cut write ret))))
       ret)
     (finally
      (force-output OUT)
      (close-port OUT)))))

(def (eval-in-emacs-channel sexp chan)
  (def vals (emacs-channel-values chan))
  (def n (hash-length vals))
  (def id (current-emacs-channel-id))
  (def pkg (emacs-channel-package chan))
  (def ret
    (with-output-to-emacs-channel
     chan (lambda () (parameterize ((gx#current-expander-context pkg))
                       (eval sexp)))))
  (def valufy (lambda (v)
                (set! n (+ 1 n))
              (hash-put! vals n v)
              (let ((str (with-output-to-string
                           "" (cut write v))))
                [str n str])))

  (:channel-send id `(:write-values (,(valufy ret))))
  (call-with-values (lambda _ ret)
    (lambda vs
      (unless (eq? (car vs) ret)
        (let ((strvs (map valufy vs)))
          (:channel-send id `(:write-values ,strvs))))
        ret)))

(register-emacs-channel-handler!
 ':process
 (lambda (str)
   (def id (current-emacs-channel-id))
   (def chan (find-emacs-channel id))
   (def sexp (with-input-from-string str (cut read)))
   (eval-in-emacs-channel sexp chan)
   `(:channel-send ,id ,(emacs-channel-prompt chan))))



(def (process-emacs-channel-form form)
  (def id (current-emacs-channel-id))
  (def name (car form))
  (def handler (find-emacs-channel-handler name))
  (if handler
    (try (apply handler (cdr form))
         (catch (e) ((current-emacs-channel-abort)
                     (with-output-to-string
                       "Handler Error: "
                       (cut display-exception e)))))
    ((current-emacs-channel-abort)
     (string-append "Cannot find emacs channel handler for: "
                    (symbol->string name)))))

(def (:emacs-channel-send id form)
  (let ((chan (find-emacs-channel id)))
    (def (abort msg)
      (:channel-send id `(:write-string ,msg))
      (:channel-send id '(:write-value nil))
      `(:channel-send ,id ,(emacs-channel-prompt chan)))
    (call/cc
      (lambda (exit)
        (parameterize ((current-emacs-channel-abort
                        (lambda (message)
                          (exit (abort message))))
                       (current-emacs-channel-id id))
          (process-emacs-channel-form form)
          #;(abort "mage it"))))))


(rswank:define-slime-handler
  (:emacs-channel-send id sexp) (:emacs-channel-send id sexp))

(rswank:register-slime-handler!
 'slynk-mrepl:create-mrepl
 (lambda (n)
   (def echan (ensure-emacs-channel n))
   (let ((msg (string-append
               "; SLY " (slynk-version-string)
             (with-output-to-string
               " ("
               (cut display echan))
             ")\n Global redirection not setup\n")))
     (:channel-send n `(:write-string ,msg))
     (:channel-send n `(:prompt "(user)" "top" 2 1))
        [n (+ 1 n)])))



(rswank:register-slime-handler!
 'slynk:autodoc (lambda (thing . args)
                  (list ':not-available 't)
                  #;(if (not (string? thing))
                    (set! thing ""))
                  #;(apply (rswank:find-handler 'swank:autodoc)
                    thing args)))

(rswank:register-slime-handler! 'slynk:slynk-add-load-paths
                                list)
