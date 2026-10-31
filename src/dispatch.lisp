(in-package #:sb-cpu-features)

(defmacro define-cpu-dispatch (name &body clauses)
  "Define a zero-argument function NAME that returns the first implementation
whose feature is available.  Clauses are (:FEATURE FUNCTION) and :DEFAULT is
required.

Example:

  (define-cpu-dispatch select-copy
    (:avx2 copy-avx2)
    (:sse4.1 copy-sse)
    (:default copy-scalar))

The function is a selector, not a wrapper: bind/call its result once per
operation.  Selection is evaluated on every call, so image restart and
WITH-CPU-FEATURES-DISABLED are respected."
  (let ((default nil)
        (forms nil))
    (labels ((designator-form (implementation)
               (if (and (consp implementation)
                        (eq (car implementation) 'function))
                   implementation
                   `(function ,implementation))))
      (dolist (clause clauses)
        (destructuring-bind (feature implementation) clause
          (if (eq feature :default)
              (setf default (designator-form implementation))
              (push `((cpu-feature-p ,feature) ,(designator-form implementation))
                    forms))))
      (unless default
        (error "DEFINE-CPU-DISPATCH ~S has no :DEFAULT clause" name))
      `(defun ,name ()
         (cond ,@(nreverse forms)
               (t ,default))))))
