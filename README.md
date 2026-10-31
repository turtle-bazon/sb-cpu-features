# sb-cpu-features

SBCL CPU feature detection, caching, runtime dispatch, and image-restart
re-probing.

## Detection

On SBCL/x86-64, detection uses CPUID plus SBCL's runtime AVX flags, which
are set after CPUID and the OS XGETBV check.  This is the same information
C runtimes use and does not require `/proc/cpuinfo`.

On other implementations, `/proc/cpuinfo` (Linux) or `sysctl` (macOS) is
used.  Availability is decided with UIOP's OS detection rather than reader
conditionals, because some implementations (for example ECL) do not put
`:LINUX` in `*FEATURES*`.

## Platform support

| platform | detection |
|----------|-----------|
| SBCL x86-64, any OS (Linux, macOS, Windows, BSD) | CPUID + SBCL XGETBV flags; no `/proc` needed |
| CCL/ECL and other non-SBCL on Linux | `/proc/cpuinfo` `flags`/`features` line |
| non-SBCL on macOS x86-64 | `sysctl machdep.cpu.*` |
| macOS ARM64 | `sysctl hw.optional.*` |
| Linux ARM | `/proc/cpuinfo` `Features:` line |
| other architectures / no fallback available | empty feature list, so dispatchers take `:default` |

The image-restart hook uses `SB-EXT:*INIT-HOOKS*`, so automatic re-probing
at image startup is SBCL-specific.  Other implementations keep the cache
until `REFRESH-CPU-FEATURES` is called.

### Detection vs. execution

Detection only answers whether the CPU supports a feature.  Being able to
**execute** SSE/AES/AVX2 code from Lisp still depends on the implementation:

- SBCL exposes SIMD through compiler VOPs such as `SB-SIMD`/`SB-VM`; the
  libraries using this one (`cl-newzlib`, `ironclad-unsafe`) target those.
- CCL has its own intrinsics/compiler support for a subset of these.
- ECL/CLISP/ABCL have no general portable SIMD intrinsic layer; on them the
  feature list is useful for selecting scalar fallbacks, not for executing
  vector code.

So on non-SBCL the safe pattern is: detect with this library, then dispatch
to an implementation-specific vector path when one exists, otherwise use the
`:default` scalar implementation.

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
