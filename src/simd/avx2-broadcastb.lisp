(in-package :sb-vm)

(unless (sb-c::info :function :info 'sb-cpu-features::%avx2-broadcast)
  (defknown sb-cpu-features::%avx2-broadcast ((unsigned-byte 8))
      (sb-ext:simd-pack (unsigned-byte 8))
      (foldable movable flushable))

  (sb-cpu-features::define-boring-vop sb-cpu-features::%avx2-broadcast
      ((byte unsigned-num :scs (unsigned-reg)))
      (broadcasted simd-pack-ub8 :scs (int-sse-reg))
    (inst movq broadcasted byte)
    (inst vpbroadcastb broadcasted broadcasted)))

(in-package :sb-cpu-features)

;; The runtime symbol spells the name with an underscore; without the
;; explicit C name this binding resolved "avx2-supported", which does not
;; exist. The variable is live, so an image restart needs no re-registration.
(sb-alien:define-alien-variable ("avx2_supported" avx2-supported) sb-alien:int)
