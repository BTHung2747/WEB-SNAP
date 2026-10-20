# Backend — sửa probe inspect/cleanup, chỉ kiểm offline

19/10/2026. Chủ giao reviewer tự giao việc. Lượt runtime vừa rồi không đạt; resource ephemeral đã cleanup-only CLOSED, không còn việc dọn resource đã xác minh này. Thực hiện sửa **probe**, không sửa app/backend sản phẩm/UI hoặc tạo attempt runtime mới trong task này.

Đọc AGENTS/CURRENT, [assessment reviewer](../evidence/ui-source-runtime-offline-probe-review-20261019/ASSESSMENT.md), đúng common/run/prepare/recovery/test-guards của `labs/tiktok/ui-source-runtime-offline-probe/` và contracts nguồn chính thức được assessment dẫn. Không đọc tràn lịch sử/evidence, không rerun suite cũ.

## Namespace và baseline

Chỉ code successor tại `labs/tiktok/ui-source-runtime-probe-fix/`, evidence `docs/evidence/ui-source-runtime-probe-fix-20261019/backend/`. Giữ nguyên original12source/48artifact (manifest `ab3dc3380a9604e9b2cc6f008a094e78e1a8c203645897bcc099b14e15a03949`), plan/runID/CID/receipts/failure gốc, owner/helper/app/UI/readiness/prelaunch/glue/locks/policy/trust và mọi lịch sử khác. Không sửa manifest/golden để hợp thức hóa đổi source. Tái dùng helper/CLI/JSON hiện có, chỉ viết integration glue cần thiết; không dependency, compiler/SDK/package/image/build mới. CURRENT do reviewer cập nhật.

## Hai finding và yêu cầu sửa

1. **F-PROBE-INSPECT-TEMPLATE:** verify **toàn bộ** field paths/types/casing được projection dùng theo exact CLI29.8.1 vendored API1.56, phân biệt Go field/embedding vs JSON tag. `.HostConfig.NanoCPUs` typed, không NanoCpus; ID typed khác Id raw. Không trộn contracts hoặc dựa fallback raw để chữa một trường. Owner projection, runtime state projection và guard projection có contract tách rõ; không dump full inspect/Env/secrets để dò field.
2. **F-PROBE-CLEANUP-COUPLING:** owner-only cleanup không phụ thuộc quota/optional HostConfig/network/guard fields hoặc parser guard thành công. Tái dùng đường tối thiểu đã hoạt động, nhưng generalize binding theo **fresh plan/ledger** chứ không hardcode CID/runID cũ. Kiểm fullCID/exactname/run/task/image provenance, reject foreign/missing/ambiguous identity trước stop/kill/rm; không global sweep/fallback hoặc nới guard để start. Ownership chưa chứng minh thì chỉ báoUNKNOWN, không destructive action. Unexpected volume không suy provenance; không xóa volume/shared/old resource.

Successor phải có runner/entrypoint nối thật các hàm đã sửa và namespace/budget/receipts mới, sẵn cho reviewer xét attempt sau; **không chỉ viết fixture helper không được runner dùng**. Không import original run.ps1 hoặc execute body có lifecycle. Không viết lại Win32 executor/transport/private owner authority. Giữ original networknone/noports/5roles tuần tự/max1running/cacheIDs/quotas/UID/RO/capdrop/NNP/timeout/output caps; không thay semantics app observer chưa chạy để che lỗi. Nếu không cần copy observer, tham chiếu pin originals và ghi dependency map.

## Chứng minh offline trước runtime

- Có regression cho casing sai bị từ chối và inventory đầy đủ field/type/path cho mọi template; typed vs raw khác casing, optional/null/nil/map/mount fields không silently accepted. Ưu tiên chạy template thực bằng **toolchain/thư viện chính thức đã có** nếu khả dụng. Reviewer không thấy Go qua Get-Command; không tự cài/download hoặc tạo container để chạy Go. Nếu chưa có Go text/template execution thì ghi NOT_RUN rõ; static/fixture không được mang tên live templatePASS. Không tự viết emulator Go template rồi gọi tương đương CLI. Không cần xin thêm dependency chỉ để hoàn thành task này.
- Fixture fault injection vào runner/lifecycle boundary, fake executor/receipts có nhãn offline: full-guard inspect lỗi nhưng owner tối thiểu hợp lệ vẫn đi đúng ownCID cleanup; guardFAIL tuyệt đối không start. Foreign CID/name/run/task/image, missing identity, malformed output, cap/timeout/native nonzero => không xóa nhầm. Create accepted nhưng stdout mất/cắt và receipt/ledger write lỗi: chỉ one-shot recover đúng planned name+labels+image, không recreate/adopt resource cũ.
- Kiểm success/failure paths, native root0≠container success, expected timeout/EOF/cleanup budget handling, no subsequent role admission khi cleanupUNKNOWN, absence native0+nonempty không thành CLOSED. Cleanup dùng reserve riêng đã định nghĩa, không reset work deadline hoặc timeout để cheFAIL. Fake removal phải nhận fullCID, không wildcard/name/global-label sweep. Kiểm State.created/ExitCode0 không thành role runtimePASS; attach/container/state/schema outcome tách riêng.
- Chỉ lưu errors dưới dạng code allowlist/safe field classification khi có thể; stderr raw không persist hoặc phát tán. Historical94B đã mất: không phục dựng message/khẳng định exact failingfield. Schema/flags sửa phải giữ bảo mật và label synthetic; source authority luôn false.
- Parse/pin source successor và fixture output; kiểm baseline trước/sau. Không chạy lại original test-guards trong evidence sealed hoặc đổi original summary false sang true. Có thể reference original16case và reviewer19case nhưng không cộng chúng thành số ca mới.

## Phạm vi thực thi và bàn giao

Task này **0Docker/daemon query,0resource create/start/remove,0browser/source/Internet business traffic**. Được đọc tài liệu/mã nguồn chính thức để verify API. Không exec escalation lifecycle ở vòng sửa; quyền runtime lab của chủ không là yêu cầu phải tự retry. Không main/gallery/deploy, signer/key/grant/claim, settings/token/ACL/WSL/service changes hoặc frontend workflow.

HANDOFF/NEXT_REVIEW/manifest mới: finding closure scope offline vs NOT_RUN, exact source/API references, tests thực và case count, fake-executor transcripts/argv assertions, source pins/delta/dependency map, runnable successor entrypoint, các giới hạn còn lại. Bổ sung đúng outer original tool exit **1** theo product history mà reviewer đã tìm lại; source exit20/native exits là các lớp khác, không sửa sealed lịch sử.

Báo reviewer chat `01a14259-19b0-73f0-bd0c-0f5be84f6a88` theo ủy quyền chủ rồi **DỪNG**. Reviewer nghiệm thu offline sau bàn giao rồi mới giao một attempt runtime mới nếu phù hợp; không có test song song. Frontend READY/chờ vì chưa có UI/contract delta.
