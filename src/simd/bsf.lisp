(in-package :sb-vm)

(defknown sb-cpu-features::bsf ((unsigned-byte 64))
    (unsigned-byte 64)
    (foldable movable flushable)
  :overwrite-fndb-silently t)

(sb-cpu-features::define-boring-vop sb-cpu-features::bsf
    ((value unsigned-num :scs (unsigned-reg)))
    (scan unsigned-num :scs (unsigned-reg))
  (inst bsf scan value))

(in-package :sb-cpu-features)

(declaim (inline bsf/16))
(defun bsf/16 (x)
  (declare ((unsigned-byte 16) x))
  (sb-ext:truly-the (mod 16) (bsf x)))

(declaim (inline bsf/32))
(defun bsf/32 (x)
  (declare ((unsigned-byte 32) x))
  (sb-ext:truly-the (mod 32) (bsf x)))
