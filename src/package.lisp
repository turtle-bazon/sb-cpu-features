(defpackage #:sb-cpu-features
  (:use #:cl)
  (:export
   ;; Detection
   #:cpu-features
   #:detected-cpu-features
   #:cpu-feature-p
   #:refresh-cpu-features
   #:detect-cpu-features
   ;; Testing / masking
   #:*disabled-cpu-features*
   #:with-cpu-features-disabled
   #:with-cpu-features-only
   ;; Dispatch
   #:define-cpu-dispatch))
