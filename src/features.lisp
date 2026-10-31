(in-package #:sb-cpu-features)

;;; CPU feature detection and caching.
;;;
;;; The cache is re-probed at image startup (SB-EXT:*INIT-HOOKS*), so a saved
;;; image moved to another machine reports the new machine's features rather
;;; than the build machine's.
;;;
;;; On Linux, /proc/cpuinfo is preferred because the kernel only lists features
;;; whose OS state is enabled (notably AVX/AVX2/AVX-512).  On other systems we
;;; fall back to CPUID plus SBCL's XGETBV-backed AVX support flags.

(defvar *detected-cpu-features* nil
  "Raw feature keywords detected on the current machine.")

(defvar *cpu-features-probed-p* nil)

(defvar *disabled-cpu-features* nil
  "Features hidden from CPU-FEATURE-P, for tests or deliberately constrained
runs.  Bind with WITH-CPU-FEATURES-DISABLED.")

(defparameter +feature-aliases+
  '(("sse4_1" . :sse4.1)
    ("sse4_2" . :sse4.2)
    ("sha_ni" . :sha-ni)
    ("avx1.0" . :avx)
    ("avx512_vbmi" . :avx512vbmi)
    ("avx512_bitalg" . :avx512bitalg)
    ("avx512_vpopcntdq" . :avx512vpopcntdq)
    ("avx512_vnni" . :avx512vnni)
    ("avx512_ifma" . :avx512ifma)
    ("avx512_vbmi2" . :avx512vbmi2)
    ("avx512_vp2intersect" . :avx512vp2intersect)
    ("avx512_bf16" . :avx512bf16)
    ("avx512_fp16" . :avx512fp16)
    ("vpclmulqdq" . :vpclmulqdq)))

(defun normalize-feature-name (string)
  "Normalize a CPU flag name to a keyword.  Handles the Linux sse4_1 style
and the macOS AVX1.0 style while preserving other names."
  (let* ((down (string-downcase string))
         (alias (cdr (assoc down +feature-aliases+ :test #'string=))))
    (or alias
        (intern (string-upcase (substitute #\- #\_ down)) :keyword))))

(defun parse-flag-list (string)
  (loop with start = 0
        with length = (length string)
        for i from 0 to length
        when (or (= i length)
                 (member (char string i) '(#\Space #\Tab #\Newline #\Return)))
          append (let ((word (subseq string start i)))
                   (when (plusp (length word))
                     (list (normalize-feature-name word))))
          and do (setf start (1+ i))))

(defun %proc-cpu-flags (path)
  "Read the first FLAGS/FEATURES line of PATH, or NIL if unavailable."
  (handler-case
      (with-open-file (stream path :if-does-not-exist nil)
        (when stream
          (loop for line = (read-line stream nil nil)
                while line
                do (let ((colon (position #\: line)))
                     (when colon
                       (let* ((key (string-downcase
                                    (string-trim '(#\Space #\Tab)
                                                 (subseq line 0 colon)))))
                         (when (or (string= key "flags")
                                   (string= key "features"))
                           (return-from %proc-cpu-flags
                             (parse-flag-list (subseq line (1+ colon)))))))))))
    (error () nil)))

(defun linux-cpu-flags ()
  "Return the feature keywords from /proc/cpuinfo, or NIL if unavailable.
Linux omits flags whose OS state is not enabled, so this is authoritative
for AVX/AVX2/AVX-512 availability.

UIOP's OS detection is used instead of #+LINUX because some implementations
(for example ECL) do not put :LINUX in *FEATURES*."
  (when (uiop:os-unix-p)
    (%proc-cpu-flags "/proc/cpuinfo")))

(defun run-lines (program arguments)
  #+sbcl
  (handler-case
      (with-open-stream (stream (sb-ext:run-program program arguments
                                                    :output :stream
                                                    :error nil
                                                    :search t
                                                    :wait nil))
        (when stream
          (unwind-protect
               (loop for line = (read-line stream nil nil)
                     while line collect line)
            (ignore-errors (close stream)))))
    (error () nil))
  #-sbcl
  (handler-case
      (uiop:run-program (cons program arguments)
                        :output :lines
                        :ignore-error-status t)
    (error () nil)))

(defun macos-cpu-flags ()
  "Return CPU features reported by sysctl on macOS.
On x86-64 the machdep.cpu.* keys provide SSE/AVX/etc.  On Apple Silicon
the hw.optional.* keys provide the ARM SIMD/crypto extensions."
  (when (uiop:os-macosx-p)
    (let ((lines (append
                  (run-lines "/usr/sbin/sysctl" '("-n" "machdep.cpu.features"))
                  (run-lines "/usr/sbin/sysctl"
                             '("-n" "machdep.cpu.leaf7_features")))))
      (if lines
          (remove-duplicates
           (mapcan #'parse-flag-list lines) :test #'eq :from-end t)
          (loop for (key feature) in '(("hw.optional.neon" . :neon)
                                       ("hw.optional.armv8_crc32" . :crc32)
                                       ("hw.optional.armv8_1_atomics" . :atomics)
                                       ("hw.optional.armv8_1_crc32" . :crc32)
                                       ("hw.optional.armv8_1_sha2" . :sha2)
                                       ("hw.optional.armv8_2_sha3" . :sha3)
                                       ("hw.optional.armv8_2_sha512" . :sha512)
                                       ("hw.optional.aes" . :aes)
                                       ("hw.optional.pmull" . :pmull))
                when (equal (run-lines "/usr/sbin/sysctl" (list "-n" key))
                            '("1"))
                  collect feature)))))

;;; CPUID fallback ----------------------------------------------------

#+(and sbcl x86-64)
(defun cpuid-values (leaf subleaf)
  (handler-case
      (multiple-value-list (sb-vm::%cpu-identification leaf subleaf))
    (error () nil)))

#+(and sbcl x86-64)
(defun cpuid-register-bit-p (values register index)
  "VALUES is (EAX EBX ECX EDX); REGISTER is 0..3."
  (and values (logbitp index (nth register values))))

#+(and sbcl x86-64)
(defun cpuid-bit-p (values index)
  (cpuid-register-bit-p values 2 index))

(defun sbcl-avx-os-p (name)
  "Ask SBCL's runtime whether the OS enabled AVX state.  The runtime sets
these after CPUID plus XGETBV.  NAME is one of the strings \"avx_supported\",
\"avx2_supported\" or \"avx512_supported\"."
  #+sbcl
  (handler-case
      (plusp (ecase name
               ("avx_supported"
                (sb-alien:extern-alien "avx_supported" sb-alien:int))
               ("avx2_supported"
                (sb-alien:extern-alien "avx2_supported" sb-alien:int))
               ("avx512_supported"
                (sb-alien:extern-alien "avx512_supported" sb-alien:int))))
    (error () nil))
  #-sbcl (progn name nil))

(defun cpuid-cpu-flags ()
  #+(and sbcl x86-64)
  (let ((leaf0 (cpuid-values 0 0)))
    (when (and leaf0 (>= (first leaf0) 1))
      (let* ((leaf1 (cpuid-values 1 0))
             (leaf7 (and (>= (first leaf0) 7) (cpuid-values 7 0)))
             (features '()))
        (labels ((add (keyword present)
                   (when present (pushnew keyword features :test #'eq)))
                 (ecx (index) (cpuid-bit-p leaf1 index))
                 (edx (index) (and leaf1 (logbitp index (nth 3 leaf1))))
                 (ebx7 (index) (cpuid-register-bit-p leaf7 1 index))
                 (ecx7 (index) (and leaf7 (logbitp index (nth 2 leaf7)))))
          (add :sse (edx 25))
          (add :sse2 (edx 26))
          (add :sse3 (ecx 0))
          (add :pclmulqdq (ecx 1))
          (add :ssse3 (ecx 9))
          (add :fma (ecx 12))
          (add :cx16 (ecx 13))
          (add :sse4.1 (ecx 19))
          (add :sse4.2 (ecx 20))
          (add :movbe (ecx 22))
          (add :popcnt (ecx 23))
          (add :aes (ecx 25))
          (add :xsave (ecx 26))
          (add :osxsave (ecx 27))
          (add :f16c (ecx 29))
          (add :rdrand (ecx 30))
          (when (and (ecx 28) (sbcl-avx-os-p "avx_supported"))
            (add :avx t))
          (add :bmi1 (ebx7 3))
          (when (and (ebx7 5) (sbcl-avx-os-p "avx2_supported"))
            (add :avx2 t))
          (add :bmi2 (ebx7 8))
          (add :erms (ebx7 9))
          (add :avx512f (and (ebx7 16) (sbcl-avx-os-p "avx512_supported")))
          (add :avx512dq (and (ebx7 17) (sbcl-avx-os-p "avx512_supported")))
          (add :rdseed (ebx7 18))
          (add :adx (ebx7 19))
          (add :avx512ifma (and (ebx7 21) (sbcl-avx-os-p "avx512_supported")))
          (add :avx512cd (and (ebx7 28) (sbcl-avx-os-p "avx512_supported")))
          (add :sha-ni (ebx7 29))
          (add :avx512bw (and (ebx7 30) (sbcl-avx-os-p "avx512_supported")))
          (add :avx512vl (and (ebx7 31) (sbcl-avx-os-p "avx512_supported")))
          (add :avx512vbmi (and (ecx7 1) (sbcl-avx-os-p "avx512_supported")))
          (add :gfni (ecx7 8))
          (add :vaes (ecx7 9))
          (add :vpclmulqdq (ecx7 10))
          (add :avx512vnni (and (ecx7 11) (sbcl-avx-os-p "avx512_supported")))
          (add :avx512bitalg (and (ecx7 12) (sbcl-avx-os-p "avx512_supported")))
          (add :avx512vpopcntdq (and (ecx7 14) (sbcl-avx-os-p "avx512_supported")))
          (nreverse features)))))
  #-(and sbcl x86-64) nil)

(defun detect-cpu-features ()
  "Detect the current machine's CPU features and return a list of keywords.
On SBCL/x86-64 this is CPUID plus SBCL's XGETBV-backed AVX/AVX-512 flags,
which is the same information C runtimes use; /proc or sysctl is only a
fallback for platforms where CPUID is unavailable (for example ARM Linux)."
  (or (cpuid-cpu-flags)
      (linux-cpu-flags)
      (macos-cpu-flags)))

(defun refresh-cpu-features ()
  "Re-probe the CPU and replace the cache.  Registered in
SB-EXT:*INIT-HOOKS* so a saved image moved to another machine re-probes."
  (setf *detected-cpu-features* (remove-duplicates (detect-cpu-features)
                                                    :test #'eq)
        *cpu-features-probed-p* t)
  *detected-cpu-features*)

(defun detected-cpu-features ()
  (unless *cpu-features-probed-p*
    (refresh-cpu-features))
  *detected-cpu-features*)

(defun cpu-features ()
  "Return the effective feature list, excluding features disabled with
WITH-CPU-FEATURES-DISABLED."
  (if *disabled-cpu-features*
      (set-difference (detected-cpu-features) *disabled-cpu-features*
                      :test #'eq)
      (detected-cpu-features)))

(defun cpu-feature-p (feature)
  "True when FEATURE is present and not disabled."
  (and (member feature (cpu-features) :test #'eq) t))

(defmacro with-cpu-features-disabled (features &body body)
  "Evaluate BODY with FEATURES hidden from CPU-FEATURE-P."
  `(let ((*disabled-cpu-features*
           (union ,features *disabled-cpu-features* :test #'eq)))
     ,@body))

(defmacro with-cpu-features-only (features &body body)
  "Evaluate BODY with only FEATURES visible."
  `(let ((*disabled-cpu-features*
           (set-difference (detected-cpu-features) ,features :test #'eq)))
     ,@body))

;; Probe at load and on every image restart.
(refresh-cpu-features)
#+sbcl (pushnew 'refresh-cpu-features sb-ext:*init-hooks*)
