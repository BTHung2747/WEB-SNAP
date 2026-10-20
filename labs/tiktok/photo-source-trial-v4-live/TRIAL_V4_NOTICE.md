# Trial v4 preparation — AGPL-3.0

Source policy/contract/runner admission glue only. DNS v4/Cobalt/HTTP/TLS/downloader/FFmpeg/lifecycle remain pinned. New gate version2/dnsProtocol4 uses separate PREPARATION versus OFFLINE_FIXTURE versus LIVE scopes. Gate builder emits sourceGate=false; no real authority/allocation/claim is created. Existing LICENSE/NOTICE/credits remain. Only explicit offline fixtures may consume mock latches. Live execution requires a later independently reviewed gate and explicit human task with new IDs/expiry, not toggling the preparation gate.
