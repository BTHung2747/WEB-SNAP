# Successor HTTP success policy — 14/10/2026

AGPL-3.0, Cobalt/imputnet/commit/pins/locks/NOTICE/LICENSE remain unchanged.
Only finalizer content acceptance adds FULL_GET_200_ONLY after the existing typed
accounting revalidation. Original accounting, observer projection/0600, Operations,
extractor, downloader, DNS/SSRF/TLS and resource/deadline profiles are unchanged.

This lab sends ordinary full GET, no Range and no partial/multipart assembly.
RFC9110 §15.3.1 describes 200 content for GET as target representation. Core
GuardedYDL already rejects redirects300–399 and errors≥400. Its transport error
policy is not the entire finalizer content policy: informative1xx and other2xx
(e.g.202notcompleted,204nobody,206partial) are not admitted for full-JPEG workflow.
200 alone is insufficient: valid metadata, JPEG/decode/SHA, native exits, selected
indices, byte/GET caps, RID/order and scoped native proof remain mandatory.

A diagnostic receipt may be exact/complete and report503 while HTTP content gate
fails and owned outputs are discarded. No flags are overwritten to claim success.
HTTP evidence is packet/diagnostic/report consistency, not authentication against
rewriting all producer files; origin UNKNOWN stays. Unsupported2xx fail closed;
supporting Range or other response semantics requires a separate verified task.
