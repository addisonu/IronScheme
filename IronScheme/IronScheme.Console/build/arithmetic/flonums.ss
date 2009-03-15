(library (ironscheme arithmetic flonums)
  (export
    flonum?
    
    fl=?
    fl<?
    fl<=?
    fl>?
    fl>=?
    
    flinteger?
    flzero?
    flpositive?
    flnegative?
    flodd?
    fleven?
    flfinite?
    flinfinite?
    flnan?
    
    flmax
    flmin
    
    fl+
    fl*
    
    fl-
    fl/
    
    flabs
    
    fldiv-and-mod
    fldiv
    flmod
    fldiv0-and-mod0
    fldiv0
    flmod0
    
    flnumerator
    fldenominator
    
    flfloor
    flceiling
    fltruncate
    flround
    
    flexp
    fllog
    flsin
    flcos
    fltan
    flasin
    
    flacos
    flatan
    flsqrt
    flexpt)
    
  (import
    (ironscheme integrable)
    (ironscheme unsafe) 
    (ironscheme clr)
    (except (rnrs)
    
    flinteger?
    flzero?
    flpositive?
    flnegative?
    flodd?
    fleven?  
    
    flfinite?
    flinfinite?
    flnan?    
    
    flmax
    flmin      
    
    flabs
    
    fldiv-and-mod
    flmod
    fldiv0-and-mod0
    flmod0
    fldiv
    fldiv0
    
    flfloor
    flceiling
    fltruncate
    flround
    
    flexp
    fllog
    flsin
    flcos
    fltan
    flasin
    
    flacos
    flatan
    flsqrt
    flexpt
    
    fl=?
    fl<?
    fl<=?
    fl>?
    fl>=?
    
    fl+
    fl-
    fl*
    fl/
    flnumerator
    fldenominator
    ))
    
    
  (define-syntax define-fl
    (lambda (x)
      (syntax-case x ()
        [(_ (name formals ...) body body* ...)
          (with-syntax (((checks ...) 
            (map (lambda (f)
                   (with-syntax ((f f))
                     #'(unless (flonum? f) 
                        (assertion-violation 'name "not a flonum" f))))
                  #'(formals ...))))
            #'(define (name formals ...)
                checks ...
                (let ()
                  body body* ...)))])))
                  
  (define-syntax define-fl*
    (lambda (x)
      (syntax-case x ()
        [(_ (name formals ...) body body* ...)
          (with-syntax ((uname 
            (datum->syntax #'name
              (string->symbol
                (string-append 
                  (symbol->string (syntax->datum #'name))
                  "*")))))
            #'(begin
                (define-integrable (uname formals ...) body body* ...)
                (define-fl (name formals ...) (uname formals ...))))])))                        
                  
  (define-syntax define-fl-comparer 
    (lambda (x)
      (syntax-case x ()
        [(_ name)
          (with-syntax ((uname 
              (datum->syntax #'name
                (string->symbol
                  (string-append "$"
                    (symbol->string (syntax->datum #'name)))))))
            #'(define name
                (case-lambda
                  [(x1 x2)
                    (unless (flonum? x1)
                      (assertion-violation 'name "not a flonum" x1))
                    (unless (flonum? x2)
                      (assertion-violation 'name "not a flonum" x2))
                    (uname x1 x2)]
                  [(x1 x2 . rest)
                    (let f ((a x1)(b (cons x2 rest)))
                      (cond 
                        [(null? b) #t]
                        [(name a ($car b))
                          (f ($car b) ($cdr b))]
                        [else #f]))])))]))) 
                        
  (define-syntax define-fl-binop0
    (lambda (x)
      (syntax-case x ()
        [(_ name id)
          (with-syntax ((uname 
              (datum->syntax #'name
                (string->symbol
                  (string-append "$"
                    (symbol->string (syntax->datum #'name)))))))      
            #'(define name 
                (case-lambda
                  [() id]
                  [(x1 x2)
                    (unless (flonum? x1)
                      (assertion-violation 'name "not a flonum" x1))
                    (unless (flonum? x2)
                      (assertion-violation 'name "not a flonum" x2))
                    (uname x1 x2)]
                  [args
                    (fold-left name (name) args)])))])))  
                    
  (define-fl-binop0 fl+ 0.0)                    
  (define-fl-binop0 fl* 1.0)
  
  (define-fl (fldenominator fl)
    (if (or (flnan? fl) (flinfinite? fl))
        1.0
        (real->flonum (denominator fl))))
      
  (define-fl (flnumerator fl)
    (if (or (flnan? fl) (flinfinite? fl))
        fl
        (real->flonum (numerator fl))))
  
  (define fl-
    (case-lambda
      [(x1)
        (unless (flonum? x1)
          (assertion-violation 'fl- "not a flonum" x1))
        ($fl- x1)]
      [(x1 x2)
        (unless (flonum? x1)
          (assertion-violation 'fl- "not a flonum" x1))
        (unless (flonum? x2)
          (assertion-violation 'fl- "not a flonum" x2))
        ($fl- x1 x2)]
      [(x1 x2 . rest)
        (unless (flonum? x1)
          (assertion-violation 'fl- "not a flonum" x1))                      
        (fold-left fl- x1 (cons x2 rest))]))
        
  (define fl/
    (case-lambda
      [(x1)
        (unless (flonum? x1)
          (assertion-violation 'fl/ "not a flonum" x1))
        ($fl/ 1.0 x1)]
      [(x1 x2)
        (unless (flonum? x1)
          (assertion-violation 'fl/ "not a flonum" x1))
        (unless (flonum? x2)
          (assertion-violation 'fl/ "not a flonum" x2))
        ($fl/ x1 x2)]
      [(x1 x2 . rest)
        (unless (flonum? x1)
          (assertion-violation 'fl/ "not a flonum" x1))                      
        (fold-left fl/ x1 (cons x2 rest))]))        
                                
  (define-fl-comparer fl=?)
  (define-fl-comparer fl<?)
  (define-fl-comparer fl<=?)
  (define-fl-comparer fl>?)
  (define-fl-comparer fl>=?) 
  
  (define-fl* (fldiv0 x1 x2)
    (let* ((d (fldiv* x1 x2))
           (m ($fl- x1 ($fl* d x2))))
      (cond 
        [($fl<? m (magnitude ($fl/ x2 2.0))) d]
        [($fl<? 0.0 x2) ($fl+ d 1.0)]
        [else ($fl- d 1.0)])))
      
  (define-fl* (flmod x1 x2)
    ($fl- x1 ($fl* (fldiv* x1 x2) x2)))

  (define-fl (flmod0 x1 x2)
    ($fl- x1 ($fl* (fldiv0* x1 x2) x2)))
    
  (define-fl (fldiv-and-mod x1 x2)
    (let ((d (fldiv* x1 x2)))
      (values d ($fl- x1 ($fl* d x2))))) 
      
  (define-fl* (fldiv x1 x2)
    (if ($fl<? 0.0 x2)
      (flfloor* ($fl/ x1 x2))
      ($fl- (flfloor* ($fl/ x1 ($fl- x2))))))

  (define-fl (fldiv0-and-mod0 x1 x2)
    (let ((d (fldiv0* x1 x2)))
      (values d ($fl- x1 ($fl* d x2)))))                                            
    
  (define-fl (flinteger? fl)
    ($fl=? 0.0 (flmod* fl 1.0))) 
    
  (define-fl (flfinite? fl)
    (not (flinfinite?* fl)))
    
  (define-fl* (flinfinite? fl)
    (clr-static-call system.double isinfinity fl))
    
  (define-fl (flnan? fl)
    (clr-static-call system.double isnan fl))    
    
  (define-fl (flsin fl)
    (clr-static-call system.math sin fl))

  (define-fl (flcos fl)
    (clr-static-call system.math cos fl))

  (define-fl (fltan fl)
    (clr-static-call system.math tan fl))

  (define-fl (flasin fl)
    (clr-static-call system.math asin fl))

  (define-fl (flacos fl)
    (clr-static-call system.math acos fl))

  (define flatan 
    (case-lambda 
      [(fl)      
        (unless (flonum? fl)
          (assertion-violation 'flatan "not a flonum" fl))
        (clr-static-call system.math atan fl)]
      [(fl1 fl2) 
        (unless (flonum? fl1)
          (assertion-violation 'flatan "not a flonum" fl1))
        (unless (flonum? fl2)
          (assertion-violation 'flatan "not a flonum" fl2))
        (clr-static-call system.math atan2 fl1 fl2)]))

  (define fllog 
    (case-lambda
      [(fl)       
        (unless (flonum? fl)
          (assertion-violation 'fllog "not a flonum" fl))
        (clr-static-call system.math log fl)]
      [(fl1 fl2)  
        (unless (flonum? fl1)
          (assertion-violation 'fllog "not a flonum" fl1))
        (unless (flonum? fl2)
          (assertion-violation 'fllog "not a flonum" fl2))
        (clr-static-call system.math log fl1 fl2)]))

  (define-fl (flsqrt fl)
    (clr-static-call system.math sqrt fl))
    
  (define-fl (flexp fl)
    (clr-static-call system.math exp fl))    

  (define-fl (flexpt fl n)
    (clr-static-call system.math pow fl n))    
    
  (define-fl (flceiling fl)
    (clr-static-call system.math "ceiling(double)" fl))    

  (define-fl* (flfloor fl)
    (clr-static-call system.math "floor(double)" fl))    

  (define-fl (fltruncate fl)
    (clr-static-call system.math "truncate(double)" fl))    

  (define-fl (flround fl)
    (clr-static-call system.math "round(double)" fl))    
    
  (define-fl (flabs fl)
    (clr-static-call system.math "abs(double)" fl)) 
    
  (define-fl (flpositive? r)
    ($fl<? 0.0 r))
    
  (define-fl (flnegative? r)
    ($fl>? 0.0 r))   
    
  (define-fl (flzero? r)
    ($fl=? 0.0 r))           
    
  (define-fl (fleven? n)
    (unless (integer-valued? n)
      (assertion-violation 'fleven? "not integer valued" n))
    ($fl=? 0.0 (flmod* n 2.0)))           

  (define-fl (flodd? n)
    (unless (integer-valued? n)
      (assertion-violation 'flodd? "not integer valued" n))
    ($fl=? 1.0 (flmod* n 2.0)))      
  
  (define (flmax a . rest)
    (unless (flonum? a)
      (assertion-violation 'flmax "not a flonum" a))
    (fold-left 
      (lambda (a b) 
        (if (fl<? a b) b a))
      a 
      rest))
    
  (define (flmin a . rest)
    (unless (flonum? a)
      (assertion-violation 'flmin "not a flonum" a))
    (fold-left 
      (lambda (a b) 
        (if (fl>? a b) b a))
      a 
      rest))     

    
)