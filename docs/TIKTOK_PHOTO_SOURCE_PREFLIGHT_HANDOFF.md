# Bàn giao chuẩn bị source trial một ảnh — 11/10/2026

[Kế hoạch chốt](TIKTOK_PHOTO_SOURCE_TRIAL_PLAN.md) và
[prompt nguồn riêng](evidence/tiktok-photo-source-preflight-20261011/NEXT_PROMPT.md).
Trạng thái PREPARED_OFFLINE_NOT_AUTHORIZED_TO_RUN_SOURCE. Runner nguồn mới và
allocation/claim mới chưa tạo; command là blueprint cho task sau, không executable
đã kiểm. Preflight hiện tại không cấp quyền nguồn hoặc dùng thay gate cho code đã đổi.

Registry closure/batch receipt–trace đã CLOSED_OFFLINE_CONFIRMED qua audit7;
chỉ đọc assessment/probe/verifier/trace/receipts, không rerun task closure/whole67.
Lượt nguồn10/10 metadata5ảnh PASS nhưng preparedJPEG1/sendBEGIN0/body0/fail20,
45IPv4/first2TCPBEGIN/43UNKNOWN; network rootcauseUNKNOWN giữ. Không tái sử dụng
response/HTML/signedURLs/cookies cũ.

Code mới chỉ `labs/tiktok/photo-source-preflight/preflight.py`, `run.ps1`, NOTICE;
không đổi closure/apps/vendor/locks/cache/image/deps. Public Requests HTTPAdapter
fake phản hồi/Requests Response/urllib3 HTTPResponse chỉ ở probe RAM networknone.
GuardedYDL/Budget/source_policy_probe/allowlist/allDNSguard/session/cookie/JSON APIs
có sẵn tái dùng; phần riêng là orchestration/typed receipts/evidence và synthetic
adapter để kiểm khôngnetwork, không transport/downloader/parser/solver mới.

API chính thức đúng pin đã đọc:

- [Requests2.34.2 adapters](https://github.com/psf/requests/blob/v2.34.2/src/requests/adapters.py),
  [sessions](https://github.com/psf/requests/blob/v2.34.2/src/requests/sessions.py),
  [models](https://github.com/psf/requests/blob/v2.34.2/src/requests/models.py):
  public Adapter.send/Session.mount/prepare_request, Response, cookie RAM.
- [urllib3-2.8.0 response](https://github.com/urllib3/urllib3/blob/2.8.0/src/urllib3/response.py):
  HTTPResponse public byte stream dùng làm response giả.
- [aio2.7.1 impl](https://github.com/aio-libs/aiohappyeyeballs/blob/v2.7.1/src/aiohappyeyeballs/impl.py):
  scheduling/TCP vẫn qua public API đã audit; không thay.

Reviewed source283 SHA621509c15c3b9a6c842f12212c865d3c029c11afd3e2b392dfca55c761c693dc,
runtime88/cached image31742091…dfa417e; Python3.11.2/Requests2.34.2/urllib3-2.8.0/
yt-dlp2026.8.19/aio2.7.1/NOTICE/LICENSE/AGPL/PSF/locks giữ.

**Lệnh thực chạy:** bundled pwsh -NoProfile -File
`docs/evidence/tiktok-photo-source-preflight-20261011/prepare.ps1`;
`labs/tiktok/photo-source-preflight/run.ps1 -Attempt 1`;
evidence record/verify commands trong native logs. PowerShell executable:
`C:\Users\LENOVO\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe`.
Không gọi frozen runner với -Stage source, kể cả để thử rejection.

Preflight mới native0/networknone512MiB/CPU.75/UID65534/RO/swapRAM/capALL/NNP/
privateIPC/pids96. Source cold imports/config/env/trust bằng9 checks sẵn có;
13 checks mới gồm core extractor SHA/pins, cookie browser/netrc/env/retries OFF,
2metadata+1prepare budget vàthêmattemptreject, HEAD/auth/cookie/URL saireject trước
send, fake token pathname/query/cookie redaction, cookie RAMclear, stockallowlist/
allDNSprivate reject khôngsocket, frozen sourceOFF **static** check. FakeAdapter3
responses là synthetic, không realHTTP/TLS/source. FD/thread baseline giữ, ownID
đã remove, source0/InternetDNS0/claimCreatedFalse/claimConsumedFalse.

Đã chốt quota/meta30/prepare60/8–16MiB/image20–16MiB/workflow36MiB và guards trong
kế hoạch; source task kế tiếp phải pin newrunner/offlinewiring/allocation/claim
atomic/defaultOFF/no-drift-gate trướcnetwork. Current tests không kiểm live
TLS/egress/reachability hoặc claim concurrency/crash trên runner chưa triển khai.
Không coi fake source status200 là metadata/file từ TikTok.

AUDIT/PROGRESS chỉ insert kết luận mới, beforecopies/offset/base64/SHA successor;
manifest/verifier lịch sử không sửa. Claim cũ consumedSHA
cfb1d25d0f9eac42063d44686751a18d6069bcdd6ccfcd6dfdedf10e632748a7 giữ. SourceCall0,
ảnhnguồn/decode/SHA/visual chưađạt/video2/3/mẫu3NEEDS_VISUAL_REVIEW/main-gallery-
API E2E/deploy chưađạt. Preflight là preparation, bước kế là chủ giao prompt nguồn
riêng rồi triển khai/check exact runner trước đúngmột trial; không thực thi prompt
nguồn trong phiên này.
