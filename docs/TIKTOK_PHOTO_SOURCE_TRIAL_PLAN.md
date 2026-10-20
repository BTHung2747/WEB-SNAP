# Kế hoạch kiểm một ảnh TikTok nguồn — 11/10/2026

Trạng thái **PREPARED_OFFLINE_NOT_AUTHORIZED_TO_RUN_SOURCE**. Nhiệm vụ hiện tại
chỉ chuẩn bị kế hoạch/preflight; chưa gọi TikTok hoặc Internet DNS nguồn, chưa có
source allocation/claim mới. Lab `wholephoto-registry-closure` giữ sourceOFF.
Runner nguồn riêng **chưa triển khai**; lệnh dưới là hợp đồng cho bước sau, chưa
phải executable đã kiểm. Cần nhiệm vụ nguồn mới từ chủ, wiring/gate đúng bản mã
và allocation mới trước lần chạy thật. Không bật gallery/main/API E2E/deploy.

## Đầu vào và kết quả lịch sử

Public input duy nhất: `https://www.tiktok.com/@adne_la.veil/photo/7678209751167110421`.
Expected bodyID `7678209751167110421`, type `photo`; ảnh có index1 theo metadata
**tươi**. Không ảnh2/album/audio/video/nguồn khác, không resolve shortlink phụ.
yt-dlp hiện có chuẩn hóa public input `/photo/` sang
`https://www.tiktok.com/@adne_la.veil/video/7678209751167110421` cho extractor
TikTok. Đây là prepared metadata target của code hiện tại, ghi riêng với public
input; không tự đổi sang route khác theo phỏng đoán. Cobalt picker dùng body mới
đã giới hạn để xác minh ID/type và thứ tự ảnh; URL ảnh/cookie chỉ trong RAM.

Trial10/10: metadata packet PASS,5 ảnh;2 metadata prepared GET và2 REQUEST_SEND
BEGIN. Image prepare đã dùng1 prepared attempt nhưng sendBEGIN0/statusUNKNOWN/
decoded0; parent/runner/finalizer20, worker process−9/signal9. Client
CONNECTION_SETUP ERROR/OS_ERROR9.16s, Adapter PROXY_ERROR9.17s; proxy nhận45IPv4,
chỉfirst2TCP BEGIN trước setup deadline,43 còn lại UNKNOWN. Những CID là suy luận
pairing client↔proxy, không sharedCID. Đây không chứng minh nguồn đã nhận imageGET,
route/server là nguyên nhân hay policyC đã sửa mạng. Giữ nguyên raw/cause/claim;
không dùng signed URLs/cookie/HTML/response cũ làm input trial mới.

Registry closure/batch receipt–trace đã CLOSED_OFFLINE_CONFIRMED qua audit7.
Matrices và JPEG fixture đã nghiệm thu offline, chưa có ảnh TikTok thực/decode/
SHA/visual. Video2/3, mẫu3 NEEDS_VISUAL_REVIEW giữ.

## Quota và guards cố định

| Phạm vi | Giới hạn |
|---|---|
| Workflow | đúng1 analyze, một tác vụ, metadata tươi→conditional ảnh1 |
| Metadata |≤2 prepared GET,30s absolute;8MiB mỗi response/16MiB tổng decoded |
| JPEG | chỉ sau metadata/trace-health gate hợp lệ;≤1 prepared GET,60s absolute |
| Byte/JPEG | input20MiB/output16MiB/workflow36MiB;8192dimension/16Mpixel/static1frame/full decode |
| Transport | connect≤10/read≤20, clamp phase remaining;redirect/retry/HEAD0 |
| Setup |10s, TCP end−1reserve;helper1/answers≤64/all-DNS-public before socket |
| Policy C | pair1..2s/singleton.60/reap.10/delay.25/interleave0;≤2sockets/≤4groups/prefix≤8 |
| Trace |256total/32owner/64maps; typed receipt v2/operation/accounting/order/closure gates |
| Runtime | proxy96+worker512=608MiB/CPU.25+.75;validator96 sau roles stop |
| Isolation | UID65534/1000,source/rootfsRO,swap=RAM,capALL/NNP/privateIPC,pids64–96,nohostport |
| Network | worker chỉ internal own-egress; proxy own private+egress network, TLS verify true |

Image cache `sha256:31742091e95df2cc62669a6c6a9e0892dc09a34341eaeefc16959dcd4dfa417e`;
Python3.11.2/Requests2.34.2/urllib3-2.8.0/yt-dlp2026.8.19/aio2.7.1 và locks giữ.
Không build/pull/install, host/WSL/Docker/seccomp/capadd/privileged/hostIPC changes.
Máy RAM8GB chạy tuần tự. Không hứa thử đủ45IP hoặc tăng timeout/caps sau lỗi.
No browser/profile/account cookie/netrc/stealth/solver/VPN/proxy mua ngoài.
Chỉ anonymous cookies do nguồn cấp, giữ RAM, clear khi child exit.

Đếm quota bằng Budget prepared attempts, kể cả thất bại trước TCP/header/body;
`REQUEST_SEND BEGIN/END`, Adapter attempts, status và decoded bytes là evidence
khác. TCP/helper/CONNECT200 counts không thay HTTP quota và không chứng minh origin
receipt/TLS/client receipt. UNKNOWN khi chưa đo. Quota không được reset qua lỗi,
process/container recreation hoặc đổi đường dẫn/ảnh.

## Điều kiện mở lượt nguồn sau

1. Chủ giao nhiệm vụ nguồn mới, xác nhận đúng quota/target từ prompt bàn giao.
   Kế hoạch/preflight này không là authorization hoặc allocation.
2. Tạo successor source runner riêng từ modules đã audit; giữ lab cũ byte/sourceOFF.
   Chỉ nối gating/stage/evidence/claim, không extractor/HTTP/TLS/race/parser mới.
3. Offline gate mới phải pin **runner đang chạy + toàn source/dependencies/runtime**
   sau wiring. Hash reviewed283 hiện tại là
   `621509c15c3b9a6c842f12212c865d3c029c11afd3e2b392dfca55c761c693dc`, runtime88.
   Không dùng receipt hiện tại để mở runner đã đổi; chỉ kiểm wiring/guards cần thiết,
   không rerun task closure/whole67 nếu chưa có regression liên quan.
4. Fresh offline fixture metadata→JPEG trên source-wiring mới, cold source-only
   imports, env/CA/allowlist/all-DNS guard/private UID/no-bypass/caps/deadlines và
   defaultOFF/hash/allocation/claim/malformed/mismatch/second-invocation rejection
   phải đạt. Fixture/source import separation rõ; không áp CA fixture vào source.
5. Tạo allocation độc lập gắn human task, target/quota/image/code gate SHA và UTC;
   namespace mới có run UUID, không tái sử dụng folder/claim cũ. Claim atomically
   CreateNew **trước capability có egress/DNS**, không clear khi fail/cancel/crash.
   Trùng claim/receipt drift/không có allocation thì reject trước network.
6. Kiểm image cache/guards/log redaction/resource availability đúng pins. Nếu
   không đủ thì dừng trước source; không thay cấu hình hay dùng nguồn để thử may.

Claim cũ consumed tại `docs/evidence/tiktok-wholephoto-source-20261010/source-claim.json`,
SHA `cfb1d25d0f9eac42063d44686751a18d6069bcdd6ccfcd6dfdedf10e632748a7`.
Không reset/clear/reuse. Lượt mới chỉ có1 atomic claim với allocation riêng.
Mỗi lần source fail đều kết thúc allocation này; sửa/xin task mới không tự retry.

## Lệnh nguồn dự kiến, chỉ cho nhiệm vụ sau

Executable PowerShell đã có:
`C:\Users\LENOVO\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe`.
Sau khi **triển khai và kiểm runner mới**, giao diện cần cố định:

```powershell
pwsh -NoProfile -File labs/tiktok/photo-source-trial/run.ps1 -Stage source `
  -AllocationPath "docs/evidence/tiktok-photo-source-trial-<UTC-run-id>/allocation.json" `
  -GatePath "docs/evidence/tiktok-photo-source-trial-<UTC-run-id>/offline-gate.json"
```

`photo-source-trial/run.ps1`/allocation/gate **chưa tồn tại và chưa được thực chạy**.
Next task phải thay placeholders bằng actual paths/hash/UTC, kiểm gate rồi thực
chạy đúng một lần; ghi lệnh thực trong source evidence. Không chép lệnh này sang
lab closure hoặc bỏ throw sourceOFF của code đã đóng băng.

## Thứ tự và tiêu chí dừng

Metadata phải PASS với bodyID đúng, typephoto/imagePost/public, có ảnh1 HTTPS,
không URL credentials, allowed host/port, dims/pixel phù hợp guard. Library challenge
anonymous có sẵn chỉ dùng trong2 preparedGET; login/captcha/access denied/parser
failure hoặc vượtquota/caps/deadline thì STOP. Không solver hoặc request dò phụ.
Signed URL được chọn từ body mới giữ RAM, không DB/file/log; parent chỉ nhận
public summary không URL. Trace-health/private UID gate phải đạt trước prepare.

Chỉ khi metadata hợp lệ mới dùng1 JPEG preparedGET qua same anonymous RAM session,
own-egress/SSRF/TLS. HTTP error/redirect/timeout/CDN/unsupported MIME/byte cap,
contract/decode/SHA/native worker/process/ownership/closure/accounting/cleanup
failure đều STOP. Không retry/HEAD/fallback/ảnh tiếp theo. Ghi **stage/cause quan
sát được**, không suy network root cause hoặc các IP chưa thử là unreachable.

JPEG chỉ technical PASS khi magic+MIME JPEG,ffprobe mjpeg/singleframe/dimensions/
pixels/bytes,full decode,SHA,packet và native child0,trace/operation/batch closure/
accounting/physical cleanup đều đạt. Nếu còn diagnostic UNKNOWN/PARTIAL, giữ FAIL
và dọn own image.jpg/part; preexisting/unrelated SHA giữ. MetadataPASS/CONNECT200
không là filePASS. File đạt thì trình **ảnh thật gốc** để review visual/watermark;
chưa review giữ NEEDS_VISUAL_REVIEW. Không crop/blur/remove logo/chữ của tác giả.
Một ảnh PASS không là album/gallery/no-watermark mọi link/main/API E2E acceptance.

## Evidence và cleanup của lượt nguồn sau

Lưu nhỏ, đã sanitize: allocation+atomic claim; source/runtime hash trước-sau,
image/version/license pins; budget/guard/control(source-only không fixture keys),
native command/exit/signal/UTC-VN/state/OOM; packet summary/ID/index/MIME/dim/bytes/
SHA; prepared attempts/adapter/send/header/status/decoded counters và flags
UNKNOWN; helper/public-IP **counts**, TCP/group/operation/epoch/cancel/closure,
FD/thread/socket/helper/process closure và exact own Docker IDs/main image.

Không URL ảnh signed/path tokens/query/cookies/headers/rawHTML/source payload/
exception message-repr-stack; log fixed codes/classes whitelist và numeric/opaque
IDs. Public input/prepared canonical target được phép ghi riêng; actual source
URLs chỉ redacted trong rows. Owner mapping không suy TLS/origin.
Receipt budget phải exact hoặc PARTIAL/reason; không discard extra/missing rows.

Cleanup verify UUID label/exact own IDs trước rm/network-rm, chỉ tài nguyên lượt;
stop worker/proxy trước validator. Thu fail evidence ngay cả khi cleanup bị lỗi,
giữ primary/secondary code đúng và báo resourcesLeft/UNKNOWN; không sweeping main.
Freeze manifest fullcoverage/exclusions rõ, successor insert-only docs; old raw/
manifests/goldens/verifiers/humanreview/claim giữ. Source failure không rollback claim.

## Preflight thực chạy trong nhiệm vụ chuẩn bị

`labs/tiktok/photo-source-preflight/run.ps1 -Attempt 1`, Docker network-none512MiB,
UID65534/CPU.75/RO/swapRAM/capALL/NNP/privateIPC/pids96, cached image.
13 checks mới và9 checks cold policy có sẵn: extractor hash/pins, source cold
import/isolation/original trust, source-only config/env rejection, two+one quota,
before-send HEAD/auth/cookie/URL rejection, all-DNS-private rejection/stock allowlist,
fake pathname/query/cookie redaction, RAM cookie clear, frozen sourceOFF static.
Fake public HTTPAdapter returns3 synthetic responses, **không DNS/HTTP nguồn**.
FD/thread baseline giữ; native0/source0/claim0, runtime reviewed88 và source283 giữ.

Đây không là live TLS/egress availability, source metadata/file, wiring của runner
nguồn mới, claim concurrency/crash trial hoặc nguồn network fix. Future runner chưa
implement/allocation chưa cấp; các gate bước sau còn bắt buộc. Chi tiết:
[bàn giao](TIKTOK_PHOTO_SOURCE_PREFLIGHT_HANDOFF.md) và
[prompt nguồn riêng](evidence/tiktok-photo-source-preflight-20261011/NEXT_PROMPT.md).
