;;; sb-cpu-features -- CPU feature detection, runtime dispatch, and the SIMD
;;; probing intrinsics those dispatchers use on SBCL/x86-64.
;;;
;;; The SIMD files are ordinary components of this system, gated to SBCL on
;;; x86-64. The AVX2 broadcast VOP is gated further: some SBCL builds expose
;;; the assembler mnemonic without advertising an :AVX2 feature, so the
;;; system probes for the mnemonic itself rather than trusting a flag.
;;; Callers select implementations with DEFINE-CPU-DISPATCH, which re-reads
;;; the (re-probed) feature list on every call.

(eval-when (:compile-toplevel :load-toplevel :execute)
  (when (and (find :sbcl *features*)
             (find :x86-64 *features*)
             (find-package :sb-x86-64-asm)
             (find-symbol "VPBROADCASTB" :sb-x86-64-asm))
    (pushnew :sb-cpu-features-avx2 *features*)))

(asdf:defsystem "sb-cpu-features"
  :version "0.0.1.0"
  :description "SBCL CPU feature detection, runtime dispatch, and SIMD VOPs."
  :author "sb-cpu-features contributors"
  :license "GPL-3.0-or-later"
  :serial t
  :components ((:module "src"
                :serial t
                :components ((:file "package")
                             (:file "features")
                             (:file "dispatch")
                             #+(and sbcl x86-64)
                             (:module "simd"
                              :serial t
                              :components ((:file "define-boring-vop")
                                           (:file "avx2-broadcastb"
                                            :if-feature :sb-cpu-features-avx2)
                                           (:file "sse2-vops")
                                           (:file "bsf")
                                           (:file "cas-bytes")))))))
