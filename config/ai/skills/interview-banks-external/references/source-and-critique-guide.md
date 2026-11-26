# Public Source Policy & Hostile Technical Critic Guide

## Part 1: Public Internet Source & Licensing Policy

### 1. Permitted Discovery Sources (Topic Signal Only)

Use public search tools and APIs strictly to identify **industry competency
areas, protocol failure modes, and operational trade-offs**:

-   **License-Filtered GitHub Repositories**: Restrict GitHub repository search
    to permissive open licenses (`license:mit`, `license:apache-2.0`,
    `license:cc-by-4.0`, or `license:0bsd`), e.g.:
    `https://api.github.com/search/repositories?q=security+engineer+interview+license:mit+license:apache-2.0+license:cc-by-4.0&sort=stars`
-   **Standards & Frameworks**: IETF RFCs (`rfc-editor.org`), NIST
    (`FIPS 203/204/205`, `SP 800-53`, `SP 800-63B`, `SP 800-207`), OWASP
    (`ASVS`, `API Security Top 10`, `Top 10 for LLM Applications`), W3C
    (`WebAuthn`, `CSP3`, `Trusted Types`), MITRE (`ATT&CK`, `ATLAS`, `CWE`),
    SLSA (`slsa.dev`), CNCF, IEEE 802.1/802.3, and Ultra Ethernet Consortium
    (`UEC`).
-   **Public Engineering Postmortems & Research**: USENIX Security / NSDI / OSDI
    papers, NANOG / RIPE / KubeCon / Black Hat / DEF CON proceedings, Project
    Zero / PortSwigger / Trail of Bits / Cloud vendor technical advisories.

### 2. Prohibited Sources & Copy Boundaries

-   **Anti-Bot & Login-Gated Sites**: Never scrape login-walled, paywalled, or
    CAPTCHA-gated resources.
-   **Unlicensed Repositories & Prose**: Never copy or paraphrase prose or code
    from repositories lacking an explicit permissive open license (`MIT`,
    `Apache-2.0`, `CC-BY-4.0`, `0BSD`).
-   **Leaked Interview Prompts**: Never reproduce company-attributed leaked
    interview questions; synthesize original scenarios grounded in primary
    public specifications.

--------------------------------------------------------------------------------

## Part 2: Hostile Technical Critic Checklist

Supply this checklist to the Stage 5 critic subagent to catch recurring subtle
bugs in LLM-generated security, networking, and coding content:

### A. Secure Code Review (`CR-*`) & Low-Level Systems Traps

1.  **Unreachable Vulnerability Branches on 64-Bit (`LP64`)**:
    -   Check whether an earlier guard makes a planted bug dead code. For
        example, in C, `if ((size_t)copy_len > wire_cap) return -1;`
        sign-extends negative `int16_t copy_len` to `>= 0xFFFFFFFFFFFF8000ULL`,
        returning `-1` before a later `if (copy_len < 0) { free(tbl); }` `UAF`
        can ever run.
    -   Check `int * sizeof(T)`: because `sizeof(T)` has type `size_t`, C's
        usual arithmetic conversions promote `int` to 64-bit `size_t` *before*
        multiplication on `LP64` (wrapping at 32 bits only on `ILP32`).
2.  **Modern C++, Go, Node.js & Python Language Semantics**:
    -   *C++20*: Dangling `std::string_view` / `std::span` over temporary
        `std::string` return values, and reference/iterator invalidation across
        `std::vector::push_back`.
    -   *Go*: `net/http` recovers panics only on the request goroutine—a `nil`
        response dereference inside a child `go func()` crashes the entire
        server binary, and concurrent `map` writes trigger an unrecoverable
        fatal runtime abort. Prefer Go 1.24+ `os.OpenRoot` (`*os.Root`) or
        `filepath.IsLocal` over naive `strings.HasPrefix` (which suffers from
        `/srv/app` vs. `/srv/app-evil` sibling-prefix bypasses).
    -   *JavaScript / Node.js*: `JSON.parse('{"__proto__":{"x":1}}')` defines
        `"__proto__"` as an **own enumerable property**, so
        `Object.hasOwn(src, key)` returns `true` and still pollutes
        `Object.prototype` during recursive merge unless `__proto__`,
        `constructor`, and `prototype` are rejected or `Zod` strict schemas are
        used.
    -   *Python*: `(65536).to_bytes(2, "big")` raises `OverflowError` rather
        than wrapping modulo $2^{16}$; `Path.resolve().is_relative_to(BASE)`
        returns `False` on every valid file when `BASE` itself traverses a
        symlink unless `BASE.resolve()` is also called; `tarfile` PEP 706
        `filter="data"` enforces zero decompression-bomb byte/member quotas;
        strict `.decode("utf-8")` rejects `0x80` SHA-256 Merkle-Damgard
        length-extension padding.
    -   *Regex CLI Option Injection*: `^[a-z0-9-]{1,32}$` permits leading `-`
        (`--help` / `--flag` injection into CLI tools) and trailing `\n` (`$`
        matches before `\n` in Python); use `^[a-z0-9][a-z0-9-]{0,31}\Z`.

### B. Practical Coding (`SC-*` / `PC-*`) Adversarial Inputs

1.  **Two-Stage Archive Symlink Escapes**: Lexical `os.path.abspath` fails when
    Entry 1 creates `x -> .` and Entry 2 creates
    `escape -> x/x/../../etc/passwd` (or in reverse order, or `sub/file.txt`
    followed by `sub -> .`). Virtual VFS component-by-component symlink
    resolution across all entries is required.
2.  **Non-ASCII & Unicode Differentials**:
    -   `hmac.compare_digest(str_a, str_b)` raises `TypeError` (HTTP `500`) if
        either `str` contains non-ASCII characters—encode to ASCII/UTF-8 `bytes`
        or validate `.isascii()` first.
    -   Python `str.isdecimal()` / `str.isdigit()` accept Arabic-Indic (`١٢٣`)
        and fullwidth (`８０`) digits, and `re.IGNORECASE` without `re.ASCII`
        matches `ſ` (`U+017F`) and `K` (`U+212A`) against `[a-z]`.
    -   `json.dumps(..., sort_keys=True)` defaults to `ensure_ascii=True`
        (escaping `"café"` as `\u00e9`, breaking cross-language HMAC digests
        against Go/TypeScript UTF-8 JSON) and coerces `{True: 1}` / `{1: 1}` to
        `{"true": 1}` / `{"1": 1}`.
3.  **Sliding-Window & Stream State Bugs**:
    -   Out-of-order / clock-skewed event timestamps break FIFO `deque` pruning
        unless maintained in sorted order (`bisect.insort`) with watermark
        retention and `OrderedDict` LRU key caps.
    -   IEEE-754 `float("nan")` bypasses `<` and `>` range comparisons unless
        guarded with `math.isfinite()`.
    -   Base64 secret scanners that exclude `/` miss ~47% of standard RFC 4648
        Base64 secrets, and `line[:8192]` truncation misses secrets on minified
        lines (use overlapping windows).

### C. Cryptography, Web, Cloud, OS & Networking Spec Precision

1.  **Applied Cryptography**:
    -   `AES-GCM` is **not** key-committing; valid KMS `KEK` unwrap checks do
        not stop multi-recipient "Invisible Salamanders" ciphertexts without an
        `HKDF`-derived key commitment.
    -   Modern browsers implement `WebAuthn` **Origin & RP ID Binding**, *not*
        TLS Channel Binding (`RFC 8471` Token Binding was removed by browsers).
    -   `HMAC` has no `AAD` parameter; context binding requires length-prefixed
        canonical encoding (`TupleHash` / `len(ctx) || ctx`).
2.  **Web, Cloud & OS**:
    -   Under `RFC 6265bis`, `SameSite` is **schemeful** (`(scheme, eTLD+1)`),
        and Firefox/Safari do not universally default unset `SameSite` cookies
        to `Lax` on top-level cross-site `POST`s.
    -   Strict nonce CSP requires `base-uri 'none'` (`base-uri` does not fall
        back to `default-src`).
    -   In AWS IAM, **same-account** access evaluates `(Identity ∪ Resource)`
        whereas **cross-account** requires `(Identity ∩ Resource)`, and `SCPs`
        never apply to the Management Account or Service-Linked Roles.
    -   In `CVE-2024-3094` (`XZ Utils`), `-Wl,-z,relro,-z,now` (`BIND_NOW` +
        Full `RELRO`) was a **trigger precondition** that forced `ld.so` to run
        `liblzma`'s `IFUNC` resolver before freezing `.got`, not a mitigation.
    -   Classic `seccomp-bpf` cannot safely dereference user-space memory
        pointers (`openat` paths) due to multi-threaded shared-memory `TOCTOU`,
        and user-space `bpftool` cannot be trusted against active eBPF
        `bpf_probe_write_user` rootkits (requires hypervisor memory
        introspection).
    -   In `libyara`, `YR_MAX_ATOM_LENGTH == 4` bytes truncates `"http" wide` to
        2-char UTF-16LE `"ht"`, so `"http" nocase wide ascii` expands to $2^4 +
        2^2 = 20$ AC atoms (not $32$).
    -   In SQLite's binary format (`fileformat2.html` §1.6), 9-byte `varint`s
        carry 7 bits in bytes `1..8` and **all 8 bits** in byte `9`.
    -   IPv6 `RA-Guard` (`RFC 6105`) only blocks rogue Router Advertisements
        (`Type 134`); stopping Neighbor Advertisement (`Type 136`) spoofing
        requires `SAVI` (`RFC 7039`) / ND Inspection.
