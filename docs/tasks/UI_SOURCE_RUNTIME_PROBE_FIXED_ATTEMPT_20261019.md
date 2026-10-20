# Backend — một attempt runtime offline với probe đã sửa

19/10/2026. Chủ đã cho reviewer tự giao việc sau đề nghị tạo/chạy/dọn container lab offline riêng, không stack chính/TikTok. [Bản sửa được chấp nhận offline](../evidence/ui-source-runtime-probe-fix-review-20261019/ASSESSMENT.md); giao thực hiện **một attempt runtime mới**, không chỉ chuẩn bị. Giữ toàn bộ [scope runtime gốc](UI_SOURCE_RUNTIME_OFFLINE_PROBE_20261019.md), chỉ thay runner bằng successor đã review. Không quyền nguồn thật/main/gallery/deploy hoặc resource cũ.

## Nguồn và namespace

Đọc AGENTS/CURRENT, assessment fix reviewer, task runtime gốc, đúng6source `labs/tiktok/ui-source-runtime-probe-fix/` và original observer files được nó pin. Source6files giữ nguyên manifest fix `eaf17b5526d098447e2e5bfa6d2bf3745791c91860d9dba68ab833f4a3ae1850`; original12source/48artifact/250pins/17fix artifacts giữ hash. Không app/owner/helper/prelaunch/readiness/glue/UI/lock/policy/dependency/build/pull mới hoặc chạy suite lịch sử để lấy thêmPASS.

Runner hiện cố định evidence parent. Được tạo **một child namespace mới** `runtime-reviewed-1` dưới `docs/evidence/ui-source-runtime-probe-fix-20261019/backend/` bằng reviewed prepare.ps1; không dùng prepared-final/development hoặc runID/CID cũ, không ghi đè artifact đã seal. Đây là execution epoch mới được task này cấp, không sửa record giai đoạn0daemon đã đóng. Overview HANDOFF/NEXT_REVIEW/manifest riêng tại `docs/evidence/ui-source-runtime-probe-fixed-attempt-20261019/backend/`, tham chiếu đúng source và child namespace; không sửa manifest parent lịch sử hoặc sao chép raw toàn cây. Nếu namespace đã tồn tại, dừng báo, không xóa/reuse/đổi tên rồi retry.

## Thực hiện

1. Pin source6/old baseline/helper/DLL/exe, no-overrides, exact endpoint và limits. Chuẩn bị namespace mới bằng `prepare.ps1 -Namespace runtime-reviewed-1`, ghi fresh random runID/planSHA/hash+label scope trước lifecycle. Plan.mode là nhãn **preparation snapshot** không tự cấp quyền; runtime task/switch/actual receipts phải được ghi riêng, không suy từ mode hoặc đổi sealed plan sau query.
2. Dùng reviewed `run.ps1 -Namespace runtime-reviewed-1 -PlanSHA <fresh exact hash> -AuthorizedOfflineRuntime`, request exec_command require_escalated justification trung thực offline create/start/inspect/own cleanup/endpoint/caps; không broad PowerShell prefix hoặc giả readonly. Phê duyệt công cụ có thể từ chối, khi đó báo/dừng không bypass/UAC/ACL/settings/remote/default endpoint. Không chạy backend suite khác hoặc reviewer test song song.
3. Max5roles tuần tự/max1running, đúng4cacheIDs, --pull=never/Linux amd64/networknone/noports/0customnetwork, quotas/UID/RO/capdrop/NNP/private IPC/cgroupns/tmpfs hiện hành. Work240s+cleanupreserve60s theo một monotonic start; native≤15s/attach≤20s/role internal15s/cap64KiB. Không đổi caps/guards/deadline/observer để épPASS. Một roleFAIL/cleanupUNKNOWN/evidence incomplete thì dừng dependencies, giữ4rolesNOT_RUN khi phù hợp, không start/recreate/retry lại role.
4. Native client status/actual exit/tree/EOF riêng với container State.exited/exit0/OOM/error và app schema/kernel packets. Go template thực sẽ được kiểm bởi CLI ở attempt này; nếu template/optional field hỏng thì FAIL và cleanup owner-only, không vá rồi query nhiều template trên daemon. Không dump full inspect/Env/stderr/raw logs; lưu allowlist projection/error codes trong caps. Không private-key/sourcecontrols/live signer/grant/claim hoặc host/Internet/main requests.
5. Bằng chứng Node22Linux/import/schema positive/negative, mapping/hash/UID/guards phải là observation trong role thực; fake17/58case không thay runtime. Postgres/Redis version không là service integration; app eager clients chỉ private-loopback namespace và close API đã định. Clock/skew/port/TLS/browser/source giữUNKNOWN/NOT_RUN, không mở nhánh liên quan trong task này.

## Cleanup và failure

Tái dùng owner-only cleanup đã sửa: intent trướccreate, ledger/fullCID, exact name/run/task/image proof và mountTypes safety riêng; no foreign/adopt/global sweep/prune. Create output lost/receipt-writeFAIL chỉ one-shot recover exact intended name, không create lại. Cleanup success/failure/timeout trong reserve, scoped CID/names/run+task absence; nativejob0 không thay daemon closure. Không xóa volume có sẵn hoặc source/evidence.

Nếu driver không dọn xong, không kéo dài work attempt hoặc retry runtime. Được một cleanup-only transaction riêng≤60s **chỉ khi chứng minh đúng ownIDs**, với request tool approval nói rõ scope và record riêng; không gọi đó là cleanup trong deadline gốc, không đổi original summaryFAIL. Identity/volume provenance chưa chắc thì không destructive action, báo exactID/name và UNKNOWN/recovery đề nghị. Không tự sửa source trong emergency cleanup hoặc mở nguồn/stack chính. Nếu cần code thay đổi, dừng bàn giao finding để reviewer giao sửa.

## Bàn giao rồi dừng

Record exact outer tool actual exit từ tool output, không suy từ source exit20/LASTEXITCODE; nếu tool yield thì resume session và giữ actual completion. HANDOFF/manifest riêng có preparedSHA/new runID, source/helper/exe baseline before/after, native/container/operation receipts, observed/not-run roles, fake vs real distinctions, resource ownership/fullCID/cleanup/absence và cácFAIL/UNKNOWN. Hash cả new child artifacts vào execution manifest, không overwrite parent17artifact manifest. Khác thời điểm/budget cleanup tách rõ nếu có.

Nguồn thật/keys/grant/claim/main/gallery/deploy vẫn0/đóng. Báo reviewer chat `01a14259-19b0-73f0-bd0c-0f5be84f6a88` theo ủy quyền chủ rồi **DỪNG**. CURRENT do reviewer cập nhật sau nghiệm thu; frontend READY/chờ vì chưa có UI/contract delta. Không tự tiếp sang browser/source sau runtimePASS.
