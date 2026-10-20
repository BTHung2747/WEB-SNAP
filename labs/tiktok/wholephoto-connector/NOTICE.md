# Whole-photo connector lab — offline only

Uses unmodified photo worker/parent/Cobalt picker, stock CONNECT parser and opaque
TLS tunnel, existing FFprobe/FFmpeg contract and Requests/urllib3 backend. Glue
integrates the trace-cleanup ownership/connector/DNS helper with two guarded roles.
Only helper hostnameRAM/stdgetaddrinfo and fixture routing are new integration;
no resolver/parser/HTTP/TLS/race/solver/private helper implementation.

aiohappyeyeballs2.7.1 is mounted unmodified from connect-poc/vendor, commit
4dfc926e30eea8d24c1a71602d73c0e9a895c191, wheelSHA
9243213661e29250eb41368e5daa826fc017156c3b8a11440826b2e3ed376472.
PSF-2.0 LICENSE/J. Nick Koston+contributors retained there; AGPL-3.0 LICENSE and
Cobalt imput contributors/NOTICE retained in photo/core. No dependency install.

Runner has no live mode. Both Docker networks are internal, hostname mapping
is explicit /etc/hosts fixture only, std getaddrinfo uses RAM IPC. Routed numeric
loopback TCP after public-IP guard is only offline; fixture CA retained alongside
original trust roots, verifyTrue/cert-error checked. No claim about external DNS,
network source cause, image watermark or human review.
