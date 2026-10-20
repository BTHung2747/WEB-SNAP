# Runtime TikTok core (AGPL-3.0)

Copied minimal tested core from labs/tiktok/cobalt, Cobalt commit a636575b09de1fc55d9b8cd98cac88f5f2f16b42.
LICENSE/NOTICE/UPSTREAM and npm lock/SRI are retained. vendor/ files are unchanged copies.
No lab runner, fixture, benchmark, driver, image gate or test is included in this runtime directory.

WED SNAP modifications: separate analyze/prepare CLI children; prepare re-extracts and independently
validates Cobalt bodyID plus public format fingerprint. IDs bind native format/codec/dimensions/duration,
never source URL/cookie. These secrets remain only in RAM and are discarded on child exit.
URL input currently supports canonical long video URLs only; shortlinks fail closed.

Limits use application bounds: analyze metadata<=2GET, prepare metadata<=2GET plus conditional MP4<=1GET.
Metadata budget30 is included in prepare180; both respect lower configured deadlines.
Input includes decompressed metadata + MP4 within each phase. Output media.mp4 keeps existing JSON schema.
Full decode uses remaining phase deadline minus10 reserve; codec/container/duration/dimensions are verified.
Own job UUID path, symlink/preexisting checks and owned failure cleanup accompany unchanged worker ProcessGroup.

TIKTOK_ADAPTER_ENABLED must explicitly be1; default is off. No account/cookie file/profile/server is introduced.
This code is not a source/API E2E acceptance or permission to enable TikTok on the main stack.
