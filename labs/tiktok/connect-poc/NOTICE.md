# Offline connect scheduling PoC

Only labs/tiktok/connect-poc is new. No application or predecessor lab is changed.
aiohappyeyeballs 2.7.1 by J. Nick Koston and contributors is vendored unmodified
from the official hash-verified wheel; PSF-2.0 LICENSE is retained in dist-info/licenses.
Tag v2.7.1 resolves to commit 4dfc926e30eea8d24c1a71602d73c0e9a895c191.
requirements.lock and PROVENANCE.json pin wheel, commit, and every vendored file.

Glue owns all-answer IP guard, a single absolute setup budget, <=2-address batches,
DNS fixture child supervision and numeric evidence. Happy Eyeballs is delegated to
the public start_connection/socket_factory API, interleave=0, delay=.25. No private
helper, monkeypatch, custom race, HTTP/TLS implementation or source parser.
Fixture event-loop subclass overrides only documented sock_connect and delegates
real numeric loopback TCP after injected delays. This is not a production observer.
No per-attempt production terminal or client/proxy correlation is asserted.

Official reviewed sources are retained in the new evidence namespace. Python3.11.2
is checked in the cached image; Requests2.34.2/urllib3-2.8.0 stay unchanged. Python
>=3.10 and no runtime dependency declared by this wheel; changelog July2026 release
shows maintenance. This is a narrow source/API review, not a complete vulnerability
audit. Exception messages may contain IPs: never serialize them, repr or stacks.
