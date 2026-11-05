(in-package :sb-vm)

(defknown sb-cpu-features::%sse2-load
    ((simple-array (unsigned-byte 8) (*)) (unsigned-byte 64))
    (simd-pack (unsigned-byte 8))
    (foldable flushable)
  :overwrite-fndb-silently t)

(sb-cpu-features::define-boring-vop sb-cpu-features::%sse2-load
    ((vector simple-array-unsigned-byte-8 :scs (descriptor-reg))
     (index  unsigned-num :scs (unsigned-reg)))
    (bytes simd-pack-ub8 :scs (int-sse-reg))
  ;; SBCL vectors are aligned to 16 bytes.
  (inst movdqa bytes
        (ea (- (* vector-data-offset n-word-bytes)
               other-pointer-lowtag)
            vector index 1)))
(defknown sb-cpu-features::%sse2-broadcast-byte
    ((unsigned-byte 8))
    (simd-pack (unsigned-byte 8))
    (foldable movable flushable)
  :overwrite-fndb-silently t)

(sb-cpu-features::define-boring-vop sb-cpu-features::%sse2-broadcast-byte
    ((byte unsigned-num :scs (unsigned-reg)))
    (bytes simd-pack-ub8 :scs (int-sse-reg))
  (inst movd bytes byte)                ; xxxxxxxxxxxxxxxB
  (inst punpcklbw bytes bytes)          ; xxxxxxxxxxxxxxBB
  (inst punpcklbw bytes bytes)          ; xxxxxxxxxxxxBBBB
  (inst pshufd bytes bytes #4r0000))    ; BBBBBBBBBBBBBBBB

(defknown sb-cpu-features::%sse2-movemask
    ((simd-pack (unsigned-byte 8)))
    (unsigned-byte 16)
    (foldable movable flushable)
  :overwrite-fndb-silently t)

(sb-cpu-features::define-boring-vop sb-cpu-features::%sse2-movemask
    ((bytes simd-pack-ub8 :scs (int-sse-reg)))
    (mask unsigned-num :scs (unsigned-reg))
  (inst pmovmskb mask bytes))

(defknown sb-cpu-features::%sse2=
    ((simd-pack (unsigned-byte 8)) (simd-pack (unsigned-byte 8)))
    (simd-pack (unsigned-byte 8))
    (foldable movable flushable)
  :overwrite-fndb-silently t)

(sb-cpu-features::define-boring-vop sb-cpu-features::%sse2=
    ((a simd-pack-ub8 :scs (int-sse-reg) :target result)
     (b simd-pack-ub8 :scs (int-sse-reg)))
    (result simd-pack-ub8 :scs (int-sse-reg))
  (unless (location= a result)
    (inst movdqa result a))
  (inst pcmpeqb result b))
