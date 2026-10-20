# Cobalt TikTok lab

Isolated AGPL-3.0 lab, pinned upstream source and five npm dependencies; production is unchanged. Read NOTICE.md and LICENSE. This is an integration experiment, not enabled TikTok support.

The first source attempt on 2026-10-08 did not complete metadata. A bounded-read readiness bug starved the JavaScript deadline; the owned resolver was killed (nativeexit137). It exceeded30s and is **not accepted as proof of deadline enforcement**. No file or watermark acceptance exists. Final code fixes short reads and uses an external Python process watchdog;7offline cases passed. Source was **not retried**, and samples2/3 were not run.

Entrypoints (PowerShell from project root): build.ps1 builds the dedicated image; run.ps1 -Stageoffline -FixtureAttempt3 was the final offline check. -Stagelive -Sample1 is already consumed and refuses existing evidence. Do not rerun/delete its directory to bypass the one-attempt rule. More source execution needs a new explicitly assigned run after review.

Source HTTP is Undici6.24.1 through cached own-egress with TLS validation, manual bounded redirects,8MiB decoded response/16MiB aggregate. No account-cookie input, persistence, browser, seccomp or host changes. Metadata/private signed URLs/cookie only flow through an in-memory pipe to yt-dlp2026.08.19. Downloader normalizes using its pinned TikTok helper and accepts only Cobalt-selected playAddr, H.264/audio/MP4/non-watermarked candidates, then checks actual ffprobe/decode. This path has not run on a real file in this session.

See docs/TIKTOK_COBALT_HANDOFF.md for actual commands, source/provenance, limitations, cleanup and narrow acceptance results. Current live lab capacity is512MiB resolver/downloader+96MiB egress; each task is sequential. Do not change production, source allowlists or protection to force a result.
