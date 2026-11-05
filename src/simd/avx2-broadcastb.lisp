(in-package :sb-vm)

(defknown sb-cpu-features::%avx2-broadcast ((unsigned-byte 8))
    (sb-ext:simd-pack (unsigned-byte 8))
    (foldable movable flushable))

(sb-cpu-features::define-boring-vop sb-cpu-features::%avx2-broadcast
    ((byte unsigned-num :scs (unsigned-reg)))
    (broadcasted simd-pack-ub8 :scs (int-sse-reg))
  (inst movq broadcasted byte)
  (inst vpbroadcastb broadcasted broadcasted))

(in-package :sb-cpu-features)

(sb-alien:define-alien-variable avx2-supported sb-alien:int)
