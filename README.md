# sb-cpu-features

SBCL CPU feature detection, caching, runtime dispatch, and image-restart
re-probing.

## Detection

On SBCL/x86-64, detection uses CPUID plus SBCL's runtime AVX flags, which
are set after CPUID and the OS XGETBV check.  This is the same information
C runtimes use and does not require `/proc/cpuinfo`.

`/proc/cpuinfo` / `sysctl` are used only as a fallback on platforms where
CPUID is unavailable, such as ARM Linux or ARM macOS.

The feature list is re-probed at image startup via `SB-EXT:*INIT-HOOKS*`,
so an image moved to another machine reports the new machine's features.

## API

```lisp
(cpu-features)                 ; effective feature keywords
(detected-cpu-features)        ; raw detected list
(cpu-feature-p :avx2)          ; predicate
(refresh-cpu-features)         ; re-probe now
```

Masking is useful for tests or deliberately constrained runs:

```lisp
(with-cpu-features-disabled (:avx2 :avx512f)
  ...)

(with-cpu-features-only (:sse4.1)
  ...)
```

Dispatch selection:

```lisp
(define-cpu-dispatch select-copy
  (:avx2 copy-avx2)
  (:sse4.1 copy-sse)
  (:default copy-scalar))

(funcall (select-copy) source destination) ; call once per operation
```

`define-cpu-dispatch` defines a zero-argument selector.  Bind or call its
result once per operation rather than wrapping every inner-loop call.

## Tests

The test system is in a separate file:

```sh
sbcl --non-interactive \
  --eval '(load "~/quicklisp/setup.lisp")' \
  --eval '(push #p"~/sb-cpu-features/" asdf:*central-registry*)' \
  --eval '(asdf:load-system "sb-cpu-features-tests" :force t)' \
  --eval '(sb-cpu-features-tests:run-tests)'
```
