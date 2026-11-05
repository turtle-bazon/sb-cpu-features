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
   #:define-cpu-dispatch
   ;; SIMD intrinsics (SBCL/x86-64; defined only when the host supports them)
   #:%sse2-load
   #:%sse2-broadcast-byte
   #:%sse2-movemask
   #:%sse2=
   #:%avx2-broadcast
   #:bsf
   #:bsf/16
   #:bsf/32
   #:%cas-byte
   #:cas-byte
   #:define-boring-vop
   #:avx2-supported))
