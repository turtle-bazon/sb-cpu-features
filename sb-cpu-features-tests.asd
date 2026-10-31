(asdf:defsystem "sb-cpu-features-tests"
  :version "0.0.1.0"
  :description "Tests for SBCL CPU feature detection and dispatch."
  :author "sb-cpu-features contributors"
  :license "GPL-3.0-or-later"
  :depends-on ("sb-cpu-features" "fiveam")
  :serial t
  :components ((:module "tests"
                :serial t
                :components ((:file "package")
                             (:file "features"))))
  :perform (test-op (op c)
             (uiop:symbol-call :fiveam :run! :sb-cpu-features-tests)))
