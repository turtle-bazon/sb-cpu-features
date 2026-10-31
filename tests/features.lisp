(in-package #:sb-cpu-features-tests)

(in-suite sb-cpu-features-tests)

(test detection-returns-keywords
  (is (listp (cpu-features)))
  (is (every #'keywordp (cpu-features)))
  (is (equalp (cpu-features) (detected-cpu-features))))

(test baseline-x86-64-features
  #+(and sbcl x86-64)
  (progn
    (is (cpu-feature-p :sse2))
    (is (not (null (member :sse2 (cpu-features))))))
  #-(and sbcl x86-64)
  (pass "no features to test"))

(test refresh-is-idempotent
  (let ((once (refresh-cpu-features))
        (twice (refresh-cpu-features)))
    (is (equal once twice))
    (is (equal once (cpu-features)))))

(test flag-name-normalization
  (is (eq :sse4.1 (sb-cpu-features::normalize-feature-name "sse4_1")))
  (is (eq :avx2 (sb-cpu-features::normalize-feature-name "avx2")))
  (is (eq :avx512vnni
          (sb-cpu-features::normalize-feature-name "avx512_vnni"))))

(test flag-list-parsing
  (let ((flags (sb-cpu-features::parse-flag-list
                (format nil "sse4_1~Cavx2~Csha_ni" #\Tab #\Tab))))
    (is (eq :sse4.1 (first flags)))
    (is (member :avx2 flags))
    (is (member :sha-ni flags))))

(test masking-disables-a-feature
  (let ((feature (first (cpu-features))))
    (if feature
        (with-cpu-features-disabled (list feature)
          (is (not (cpu-feature-p feature)))
          (is (not (member feature (cpu-features)))))
        (pass "no features to test"))))

(test masking-only-keeps-one-feature
  (let ((feature (first (cpu-features))))
    (if feature
        (with-cpu-features-only (list feature)
          (is (cpu-feature-p feature))
          (dolist (other (cdr (cpu-features)))
            (is (not (cpu-feature-p other)))))
        (pass "no features to test"))))

(defun dispatch-avx2 () :avx2)
(defun dispatch-sse () :sse)
(defun dispatch-scalar () :scalar)

(define-cpu-dispatch dispatch-test
  (:avx2 dispatch-avx2)
  (:sse4.1 dispatch-sse)
  (:default dispatch-scalar))

(test dispatch-selector-returns-function
  (is (functionp (dispatch-test))))

(test dispatch-default-with-all-features-disabled
  (with-cpu-features-only '()
    (is (eq (funcall (dispatch-test)) :scalar))))

(test dispatch-respects-mask
  (with-cpu-features-only (list :sse4.1)
    (if (cpu-feature-p :sse4.1)
        (is (eq (funcall (dispatch-test)) :sse))
        (is (eq (funcall (dispatch-test)) :scalar)))))

#+sbcl
(test init-hook-registered
  (is (member 'refresh-cpu-features sb-ext:*init-hooks*)))
