;;; Copyright (c) 2006, 2007 Abdulaziz Ghuloum and Kent Dybvig
;;; Copyright (c) 2008 Llewellyn Pritchard
;;; 
;;; Permission is hereby granted, free of charge, to any person obtaining a
;;; copy of this software and associated documentation files (the "Software"),
;;; to deal in the Software without restriction, including without limitation
;;; the rights to use, copy, modify, merge, publish, distribute, sublicense,
;;; and/or sell copies of the Software, and to permit persons to whom the
;;; Software is furnished to do so, subject to the following conditions:
;;; 
;;; The above copyright notice and this permission notice shall be included in
;;; all copies or substantial portions of the Software.
;;; 
;;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;;; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;;; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
;;; THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;;; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
;;; FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
;;; DEALINGS IN THE SOFTWARE. 

(library (psyntax main)
  (export
    trace-printer
    command-line
    load
    load/args
    load/unload
    ironscheme-build
    ironscheme-test
    emacs-mode?
    compile
    compile-system-libraries
    compile->closure)
  (import 
    (rnrs base)
    (rnrs exceptions)
    (rnrs control)
    (rnrs io simple)
    (rnrs lists)
    (only (rnrs conditions) serious-condition?)
    (only (rnrs exceptions) raise)
    (psyntax compat)
    (psyntax internal)
    (psyntax library-manager)
    (psyntax expander)
    (only (ironscheme core) get-command-line format)
    (ironscheme enums)
    (ironscheme files)
    (ironscheme cps)
    (ironscheme clr)
    (ironscheme library)
    (only (ironscheme) pretty-print))
    
  (define trace-printer (make-parameter pretty-print))
  
  (define command-line (make-parameter (get-command-line))) 
   
  (define emacs-mode? (make-parameter #f))
    
  (define (local-library-path filename)
    (cons (get-directory-name filename) (library-path)))

  (define (load/args filename . args)
    (apply load-r6rs-top-level filename 'load args)
    (void))
    
  (define (load/unload filename)
    (let ((libs (installed-libraries)))
      (load filename)
      (for-each
        (lambda (lib)
          (unless (memq lib libs)
            (uninstall-library lib)))
        (installed-libraries))))

  (define (load filename)
    (apply load-r6rs-top-level filename 'load (cdr (command-line)))
    (void))
    
  (define (ironscheme-test)
    (load "tests/r6rs/run.sps"))    
      
  (define ironscheme-build
    (case-lambda
      [()      (ironscheme-build #f)]
      [(cps?)  
        (call-with-output-file "build-options.ss"
          (lambda (p)
            (write `(define-option cps-mode ,cps?) p)
            (write `(define-option if-wants-letrec* ,(not cps?)) p)
            (newline p)))
        (load "ironscheme-buildscript.ss")]))
    
  (define foreground-color
    (case-lambda
      [()           (and (not (emacs-mode?)) (clr-static-prop-get console foregroundcolor))]
      [(color)      (and (not (emacs-mode?)) (clr-static-prop-set! console foregroundcolor color))])) 
      
  (define (system-exception? e)
    (clr-is SystemException e))         
    
  (define (eval-top-level x)
    (call/cc
      (lambda (k)
        (with-exception-handler
          (lambda (e)
            (let ((serious? (or (serious-condition? e) (system-exception? e))))
              (parameterize ((foreground-color (if serious? 'red 'yellow))
                             (current-output-port (current-error-port)))
                (when serious?
                  (display "Unhandled exception during evaluation:\n"))
                (display e)
                (newline))
              (if serious?
                (k))))
          (lambda ()
            (eval x (interaction-environment))))))) 
    
  (define (compile-system-libraries)
    (eval-top-level 
      `(begin
         (include "system-libraries.ss")
         (compile "system-libraries.ss"))))
    
  (define (compile filename)
    (load-r6rs-top-level filename 'compile))
    
  (define (compile->closure filename)
    (load-r6rs-top-level filename 'closure))
  
  (define (load-r6rs-top-level filename how . args)
    (parameterize ([library-path (local-library-path filename)])
      (let ((x* 
             (with-input-from-file filename
               (lambda ()
                 (let f ()
                   (let ((x (read-annotated)))
                     (if (eof-object? x) 
                         '()
                         (cons x (f)))))))))
        (case how
          ((closure)   (pre-compile-r6rs-top-level x*))
          ((load)      
            (parameterize ([command-line (cons filename (map (lambda (x) (format "~a" x)) args))])
              ((compile-r6rs-top-level x*))))
          ((compile)   
              (begin 
					      (compile-r6rs-top-level x*) ; i assume this is needed
					      (serialize-all serialize-library compile-core-expr)))))))

  (define fo (make-enumeration '(no-fail no-create no-truncate)))
 
  (current-precompiled-library-loader load-serialized-library)
  
  (set-symbol-value! 'default-exception-handler 
    (lambda (ex)
      (cond
        [(serious-condition? ex) (raise ex)]
        [else 
          (display ex)
          (newline)])))
      
  (set-symbol-value! 'load load)
  (set-symbol-value! 'compile compile)
  (set-symbol-value! 'compile->closure compile->closure)
  (set-symbol-value! 'eval-r6rs eval-top-level)
  (set-symbol-value! 'int-env-syms interaction-environment-symbols)
  (set-symbol-value! 'expanded2core expanded->core)
  
  (set-symbol-value! 'trace-printer trace-printer)
  (set-symbol-value! 'convert->cps convert->cps)
  (set-symbol-value! 'assertion-violation assertion-violation)
  (set-symbol-value! 'raise raise)
  (set-symbol-value! 'emacs-mode? emacs-mode?)
  
  (file-options-constructor (enum-set-constructor fo))
  
  (library-path (get-library-paths))
  
  (library-extensions (cons ".ironscheme.sls" (library-extensions)))
  
  (interaction-environment (new-interaction-environment))
  )
