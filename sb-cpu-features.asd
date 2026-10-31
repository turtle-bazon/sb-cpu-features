(asdf:defsystem "sb-cpu-features"
  :version "0.1.0"
  :description "SBCL CPU feature detection and runtime dispatch."
  :author "sb-cpu-features contributors"
  :license "BSD-3-Clause"
  :serial t
  :components ((:module "src"
                :serial t
                :components ((:file "package")
                             (:file "features")
                             (:file "dispatch")))))
