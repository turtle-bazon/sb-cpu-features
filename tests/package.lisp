(defpackage #:sb-cpu-features-tests
  (:use #:cl #:fiveam #:sb-cpu-features)
  (:export #:run-tests))

(in-package #:sb-cpu-features-tests)

(def-suite sb-cpu-features-tests
  :description "CPU feature detection, masking and dispatch.")

(in-suite sb-cpu-features-tests)

(defun run-tests ()
  (let ((result (run 'sb-cpu-features-tests)))
    (explain! result)
    result))
