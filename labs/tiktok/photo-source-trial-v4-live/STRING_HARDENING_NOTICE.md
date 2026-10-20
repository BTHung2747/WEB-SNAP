# AGPL-3.0 authority string hardening

Only strict scalar string admission before equality/regex/path/hash and Python control/claim string guards. Reuses PowerShell -is [string], public JSON/.NET APIs and existing contract. Untrusted parameters are not typed [string] or normalized/cast. DNS/HTTP/TLS/Cobalt/downloaders/guards/quotas/immutable consume remain unchanged. Candidate/history preserved. Offline only/sourceGatefalse.
