# DNS answer accounting — offline research only

No application, accepted lab, DNS helper, transport, policy, dependency or image
is changed. model.py is a WED SNAP policy/counting model, not a DNS/HTTP/TLS
implementation or a replacement extractor. probe.py uses stdlib unittest.mock
and delegates real bounded IPC tests to the accepted test_diagnostics.dns_case.
run.ps1 creates one network-none,96MiB container from the cached pinned image.

Python3.11.2/PSF license is retained as an official reference in the research
evidence. aiohappyeyeballs2.7.1 by J. Nick Koston and contributors is mounted
unmodified from the existing hash-locked PSF-2.0 wheel. Commit
4dfc926e30eea8d24c1a71602d73c0e9a895c191; full license remains in vendor/dist-info.
No dependency installation, build, copy of private library helpers or new solver.

Model B's65 raw bound is only the smallest counterexample witness. It is not
a proposed operational bound, not a change to the accepted raw64 cap, and not
a source gate. Model A counts at most64; over64 returns a saturated lower bound
and UNKNOWN endpoint/duplicate/family counts. Recommended next step: diagnostics
only in a new offline successor, retain raw64 and all-answer validation.
