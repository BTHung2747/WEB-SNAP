# Kế hoạch một trial ảnh nguồn với DNS diagnostics — preparation 11/10/2026

## Phạm vi và trạng thái

Preparation offline theo `docs/evidence/tiktok-photo-receipt-consistency-audit-20261011/NEXT_PROMPT.md`. Hai findings đã CLOSED_OFFLINE_CONFIRMED; không chứng minh nguyên nhân DNS nguồn cũ đã sửa. Source executable hiện **BLOCKED** cả `run.ps1` và `common.stage_policy`. Không gỡ block, sửa lab đóng băng hoặc gọi runner nguồn lịch sử. Không có source allocation/claim trong preparation. Blueprint dưới chưa phải executable/gate mở mạng; chỉ triển khai khi có nhiệm vụ riêng.

Đích duy nhất: https://www.tiktok.com/@adne_la.veil/photo/7678209751167110421 ; expected bodyID `7678209751167110421`, type `photo`, conditional selectedIndex integer1. Không resolve phụ/ảnh2/album/gallery/main/API E2E/deploy. Ảnh technicalPASS vẫn chờ human visual/watermark review toàn ảnh; không xóa logo tác giả.

## Quota và bảo vệ cố định

| Hạng mục | Ngân sách bắt buộc |
| --- | --- |
| Workflow | một analyze đã bắt đầu; invocation không đồng nhất số GET |
| Metadata | ≤2 prepared GET attempts; absolute30s;8MiB/response,16MiB tổng decoded |
| Prepare | metadata hợp lệ mới ≤1 prepared JPEG GET; absolute60s gồm tải/check/decode/hash/childexit |
| Bytes | JPEGinput≤20MiB, output≤16MiB, workflow≤36MiB; chặn khi đang đọc |
| Request | redirect0/retry0/HEAD0/fallback0; cookie ẩn danh chỉ RAM, không cookieaccount/netrc/profile |
| Timeout | connect≤10/read≤20 clamp remaining; setup10, end−1s reserve; không tăng |
| Connector policyC | pair1–2, singleton.60, reap.10, stagger.25, interleave0; ≤2socket/4groups/prefix8 |
| DNS/trace | helper1/answers64;trace256/owner32/map64; all-DNS public-IP check, hostname allowlist |
| Runtime | worker512MiB/.75CPU/pids96/UID1000 +egress96MiB/.25CPU/pids64/UID65534=608MiB; tuần tự RAM8GB |
| File | JPEGmagic/MIME, static1frame/full decode, dimension≤8192/pixels≤16M/native0/SHA đúng |

Giữ image sha256:31742091e95df2cc62669a6c6a9e0892dc09a34341eaeefc16959dcd4dfa417e và Python3.11.2/Requests2.34.2/urllib3-2.8.0/yt-dlp2026.8.19/aiohappyeyeballs2.7.1, LICENSE/NOTICE/locks/trust. RO/privateIPC/RAMswap=caps/capdropALL/NNP/nohostports/user riêng; worker chỉ own-egress, không bypass, proxy giữ SSRF/TLS. Validator96MiB sau stop hai roles, networknone. Không đổi helper/getaddrinfo/Popen/selectors/parser/HTTP/TLS/TCP/race/host/deps/build/pull/install.

## Successor runner và gates trước network nguồn

1. Namespace mới (dự kiến `labs/tiktok/photo-dns-source-trial/` và evidence task riêng); sao phần glue cần thiết từ receipt-consistency giữ nguyên validators/helper/connector/trace. Việc bỏ sourceblock chỉ xảy ra trên successor trong nhiệm vụ wiring, không trên lab đóng băng. Runner defaultOFF; thiếu explicit Stage/source + đúng task/allocation/gate thì fail trước tạo egress. Entry Python và source control/env cũng fail closed.
2. Tính exact source/runtime inventory, cached image ID, trust/version pins sau wiring. Audit hash hiện e5512492bb8c1ac4e3b85f9c8078cc4098b526c581b9cc7a6b8840faebfdf641/source384/runtime91 chỉ là reference; code mới phải có hash/list/count riêng. Ghim gate proofs (code runner, validator, offline native receipts, guards, byte/deadline, claim probes). Thay một file/dependency/proof/mount phải reject. Không áp gate cũ lên code đã đổi hoặc ép fixed runtime90 của runner lịch sử.
3. Cold process networknone kiểm source import **chính successor** không fixture module/CA; kiểm source control schema và forbidden fixture/cookie/proxy/trust env overrides. Trust đúng image SHA; cookies RAM/session-close; observer đầy đủ, correlation/chặng thiếu giữ UNKNOWN. Preparation đã kiểm clean imports hiện tại nhưng chưa kiểm source policy của executable chưa tồn tại.
4. Fresh fixture metadata→JPEG trên chính mã đã nối: positive và negatives wrongbody/type/dimensions/redirect/byte/deadline/missingtrace/nativeexit/registryclosure, DNSdiagnostic outer/nested conflict và invocationcount0 có packet; only-owned cleanup, unrelated/preexistingSHA. Test trước source networknone/internal riêng; fake adapters không thay whole pipeline. Claim/gate tests dùng mock namespace riêng và proof native/hashes; không chạm consumed history. Rerun chỉ phần cần cho wiring, không toàn lịch sử.
5. **Sau review và nhiệm vụ human nguồn riêng** mới tạo allocation mới task-bound. Schema strict typed integers/quota đúng bảng (boolean không integer); target/bodyID/type/index/task+allocationID/image/gateSHA/UTC cụ thể. Path cố định task-root mới, không caller-configurable claim/latch output. Trong **một task** root latch chống quota tăng bằng đổi allocation namespace; không reset/reuse old/new consumed latch. Kiểm mọi gate/ownership/hash trước atomic CreateNew latch rồi claim, flush/dispose; cả hai phải xác nhận CONSUMED_BEFORE_NETWORK_CAPABILITY trước tạo network egress/proxy/worker. Crash giữa hai bước vẫn consumed, không rollback/retry/UUID khác. Lỗi IO/claim existing/hash drift dừng không network. Nếu một task đã consumed cần human task mới, không tự tạo task để thử lại.
6. Kiểm hash lần cuối trước cấp capability và sau run; ghi manifest fullcoverage/code snapshot/mount actuals/guards/UTC-VN/native exits. Network creation chỉ sau claim-before-egress. Đầu vào source không fixture CA/env/import; proxy dùng DNS diagnostics và policyC nguyên byte.

## Chạy nguồn dự kiến — blueprint, chưa chạy/không runnable hiện tại

```powershell
# Không thực thi trong preparation. File runner và gate dưới chưa được tạo.
# Sau nhiệm vụ wiring+review: preflight chính bản mã → offline wiring gate → review.
& $BundledPwsh -NoProfile -File labs/tiktok/photo-dns-source-trial/run.ps1 `
  -Stage source -AllocationPath <TASK_OWNED_ALLOCATION_NEW> -GatePath <EXACT_WIRING_GATE_NEW>
# Chỉ một lần; bất kỳ lỗi nào kết thúc allocation. Không lệnh retry/reset/resolve phụ.
```

`$BundledPwsh` là shell đã có `C:\Users\LENOVO\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe`. Placeholder buộc nhiệm vụ sau xác định task ID/namespace/paths; preparation không tạo file allocation và không phát hành source gate.

## Kết quả, diagnostics và tiêu chí dừng

Metadata PASS cần fresh bodyID/typephoto/imagescount/dimensions hợp lệ, packets đúng phase +worker native0/parent gate; packet PASS chưa đủ. DNS helper exit0 không resolutionPASS: whitelist status/code/answerCount/type/elapsed và cùng-helper outer exit/reaped/pipes/group phải COMPLETE, typed đúng; thiếu/UNKNOWN/malformed/trace lỗi giữ PARTIAL/FAIL. Không ép elapsed bằng nhau. Invocation phải int1 khi packet/file evidence; stage source có sourceAnalyzeAttempts1; số sourceCalls để UNKNOWN_USE_REQUEST_ACCOUNTING, **requestAccounting** mới là số preparedGET/sendBEGIN/observedheaders/bodyBytes thật. Không lấy fixture/no-send thành nguồnPASS.

Bất kỳ metadata/helper/DNS/setup/HTTP/bodyID/byte/deadline/native/evidence/cleanup FAIL: dừng trước ảnh, không retry. Metadata hợp lệ mới duy nhất GET ảnh1; lỗi ảnh dừng, không ảnh2/nguồn phụ/fallback/HEAD. Technical JPEG PASS phải native worker0/parent0/validator0/full decode/containerdimensions/frame/SHA/bytecaps; thực hiện human review ảnh thật mới xét hình/watermark. Nếu không file: stage/causecode/phase timing thực, missing TCP/CONNECT/header/status/body ghi UNKNOWN; không đoán DNS_ERROR/ANSWER_CAP từ87bytes lịch sử.

Receipt DNS mới không ghi hostname/IP/URL/answers/cookie/token/raw response/HTML/message/repr/stack. Log opaque owner/request/connection IDs và enum/fixedcode/timing/timeout/status đã quan sát. URL chứa path/query token luôn redacted; public target cố định được ghi trong kế hoạch. Native returns vs actual containerexit vs expected-negative runner0 phải tách rõ.

## Evidence và cleanup

Thu exact code/runtime/image/trust/locks/mounts/guard snapshots, typed quota+task gate/claim receipts **ở nhiệm vụ sau**, worker/private observer/parent native/egress trace/helper receipt/operation-accounting-batch-registry coverage, completion UTC/VN, fileSHA/contract/humanreview hoặc cause. Không log secrets. Cleanup exact created IDs/labels/networks/processgroups, chờ helper/socket/handler/pipe/thread closure; ảnh/part chỉ xóa khi own và không preexisting/symlink, unrelated giữSHA. Sau stop kiểm zero owned resources; giữ toàn rawFAIL và manifests lịch sử. Mọi partial evidence vẫn FAIL, không clear source claim.

Preparation hiện chạy một preflight networknone với adapter giả và ba DNS case numeric/IPC; không fresh wholepipeline/source sau wiring. Bàn giao để kiểm độc lập preparation trước nhiệm vụ wiring; preflightPASS không source authorization.
