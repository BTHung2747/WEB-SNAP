# Third-party and WED SNAP integration notices

aiohappyeyeballs 2.7.1 by J. Nick Koston and contributors, PSF-2.0. Unmodified source snapshot from the already-held `labs/tiktok/connect-poc/vendor`, upstream https://github.com/aio-libs/aiohappyeyeballs/tree/v2.7.1. License: vendor/aiohappyeyeballs-2.7.1.dist-info/licenses/LICENSE. Original METADATA/WHEEL/RECORD preserved. PINNED_HASHES.json and PROVENANCE.json describe exact source-file SHA256 pins; this is not a pip wheel/hash lock or a new installation.

WED SNAP policy glue in src/tiktok_policy is adapted from the previously tested photo-album-authority-mount-fix/runtime admission/batch/observer modules; WED SNAP adaptations are AGPL-3.0 (full text in LICENSE). Source mappings and exact from/to hashes are recorded in PROVENANCE.json. No Cobalt parser, cookie/account state, lab authority, claim, fixed media ID or source runner is included here.

Changes: package-relative imports, explicit request-owned trace instead of Trace.current, bounded RAM trace instead of lab file/lifetime quota, hostname-only helper with direct Popen ownership/reap, resource caps, production server lifecycle hooks and fail-closed receipt validation. aiohappyeyeballs vendor source remains byte-identical. Library owns DNS/TCP mechanics; glue owns admission/budgets/ownership/diagnostic contracts only.
