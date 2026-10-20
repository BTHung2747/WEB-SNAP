# TikTok photo lab — AGPL-3.0

Cobalt author imputnet, commit a636575b09de1fc55d9b8cd98cac88f5f2f16b42.
Vendor helpers/LICENSE and locked npm package files come from the attributed existing minimal Cobalt core; package-lock SRI and dependency versions unchanged.
Only vendor/tiktok.js picker return receives lab ID/type/private/dimensions annotations from detail already parsed by upstream. Existing earlier lab relocation/play metadata annotation and disabled whole-app createStream remain, alwaysProxy=false.
WED SNAP adds RAM-only Cobalt picker bridge, existing high-level yt-dlp webpage/challenge transport, bounded selected JPEG download through the unchanged GuardedYDL/Requests/Budget and FFprobe/FFmpeg validation.
No library parser/solver/private helper/HTTP/TLS is copied or rewritten. Parent supervision is a lab-only adaptation of the tested candidate parent, with image names/output ownership and60s prepare bound. Fixtures/runners never enter application runtime.
imghdr.what is a Python3.11 stdlib API (deprecated, removed3.13); this cached Python3.11 runtime is pinned. It only sniffs magic; FFprobe and full FFmpeg decode decide actual format, dimensions and validity. JPEG only in this task; other formats fail before acceptance. No watermark removal/transcoding/output edits.
