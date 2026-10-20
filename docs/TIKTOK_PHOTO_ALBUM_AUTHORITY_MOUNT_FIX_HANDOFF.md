# Bàn giao sửa mount authority — chỉ offline, 15/10/2026

**SOURCE_MOUNT_FIX_PREPARED_OFFLINE_PENDING_REVIEW**, chưa tự đóng F-ALBUM-SOURCE-READONLY-AUTHORITY-NESTED-MOUNT và chưa SOURCE_READY. Source all5 trước vẫn FAIL, ảnh2–5 chưa tải thật. Không gọi TikTok/CDN/DNS/HTTP, không cold/release/latch/claim thật mới, main/gallery/API/UI/DB/deploy giữ OFF.

## Thay đổi

Successor `labs/tiktok/photo-album-authority-mount-fix/`, original `photo-album-execution-namespace` giữ nguyên. Ba file đổi: run.ps1 thêm helper và staging parent mount; lab_contract.ps1/execution_namespace.ps1 chỉ trỏ source/evidence/storage namespace mới. Hai file thêm: authority_mount.ps1 và MOUNT_FIX_NOTICE.md. Readers Python, Cobalt, photo runtime/vendor, libraries, guards/transport/downloader/cleanup/licensing và quota giữ byte; code-diff liệt kê từng file.

`NewAuthorityMountTree` tạo `authority-mount` riêng trong task output, copy release files đã kiểm SHA/reparse, xác minh trước/sau, tạo hai target rỗng. Bind directory này→/authority RO, sau đó bind **file claim/latch canonical**→hai target RO như trước. Không ghi placeholder vào release/golden cũ, không sao chép claim làm nguồn thẩm quyền, không đổi đường reader. Runtime sourceGuard/resource/HTTP/caps vẫn giữ. File staging không cấp quyền nguồn.

SourceHash successor `6dd72e4f1f958f269e803a03d4855f924a0e3a43726dd26ec22ba577eeefc4dd`; runtimeHash giữ `c000b715baf471373fab65bbd83b30ab9b9b76542d24ef2bfcfa9e000604458b`. Preparation/freeze/proposal DRAFT riêng ở evidence, IDs mới không quyền. Reviewer capture route vẫn thuộc chat reviewer như đã nghiệm thu. Wrapper/proposal cũ ghim candidate cũ; muốn workflow nguồn sau này phải review/wire đúng candidate/sourceSHA mới, không đổi pointer lặng hoặc dùng packet/cold/human/task cũ.

## Kiểm thực chạy

Dùng cached image317420…417e. Mỗi lượt đúng một container networknone/UID65534/rootfsRO/privateIPC/dropALL/NNP/noports/default seccomp, RAM96MiB/swap96/CPU.25/PIDs64/tmpfs16MiB; Docker native và process deadline30s, tuần tự. Probe evidence (không runtime) ủy quyền `live_admission.validate(harness=True)` và SHA reader hiện có, không tự viết contract hoặc transport.

| Ca fixture | Docker start | Process | Kết quả |
|---|---:|---:|---|
| old-layout | 1 | NOT_STARTED | Tái hiện OCI mountpoint trên parentRO |
| fixed-valid | 0 | 0 | Typed release/admission/claim/latch/hash đọc đúng |
| wrong-sha | 20 | 20 | LIVE_CLAIM_HASH |
| invalid-claim | 20 | 20 | LIVE_CLAIM_FIELDS (version bool) |
| missing-claim | 20 | 20 | Không có canonical bind, target rỗng bị loader từ chối |

Fixed-valid thử ghi vào claim/latch/release/authority new-file/rootfs đều bị từ chối; bytes input trước/sau bằng nhau. Claims đọc là canonical child files (SHA đúng control), không empty placeholders. Guard inspect tất cả bind RW=false; none/user/resources/image/security đúng. Child state exited/noOOM, start returncode bằng state exit; old created/Pid0 không gọi ExitCode0 là PASS. Probe/harness sourceGate=false/scopes fixture; không thực thi metadata hoặc tải. Kiểm host staging reuse bị chặn và entry default-disabled native20 trước authority/Docker.

Lệnh thực: inventory trước/sau; `run-delta.ps1`; `finalize.ps1`; native Docker version; host reuse/default-disabled; `update-docs.ps1`; verifier seal/read-only. Hai lỗi harness trước delta giữ bản/raw receipt: cú pháp array SourceImage (chưa container), alias Mount→New-PSDrive (chưa container, có mock root). Chỉ sửa harness thành expression `(SourceImage)` và `BindArg`; giữ mock root cũ, không rerun code/runtime tới khi PASS. Cả năm ca cuối cùng cùng freeze/sourceHash, không sửa candidate sau gate.

## Evidence, cleanup, lịch sử

`docs/evidence/tiktok-photo-album-authority-mount-fix-20261015/`: original snapshot/inventory/diff/protected hashes, API notes/version, probe/harness/native/raw FAIL→PASS, fixture-builder provenance, freeze/prep/proposal DRAFT, cases/guards/states/input hashes, cleanup/inventory, docs successor, explicit two own offline roots, manifest/seal/read-only. 13.328 file lịch sử bảo vệ nguyênhash. New future IDs DRAFT; source task00af…abf9/allocation7a74…fa09/approval/cold7caf…execution/claims/history giữ nguyên.

Năm own container đều đã dọn bằng ID+label nonce; after inventory không còn IDs, không tạo network/volume/image. Images13/oldcontainers25/volumes35/main giữ, renderer absent; network comparison ghi số đo riêng, không prune. Không chỉnh host hoặc reset/renew approval/TTL.

Verifier mới lần đầu exit1 tại EXACT_READ_RO do đếm PS member collection bằng `.Count` trả các giá trị1 theo từng member. Giữ bản verifier/receipt FAIL trước sửa; sửa chỉ phép đếm thành array count, không đổi proof/expectations/candidate và không chạy lại container. Manifest chưa tạo tại lần lỗi này; seal/read-only sau sửa kiểm cùng raw năm ca.

Source manifest84 chứa AUDIT/PROGRESS tại thời điểm trước acceptance. Successor chứng minh shared-doc hash bằng gỡ insertion fix, dispatch sửa và acceptance trong bộ nhớ, so lại đúng SHA source manifest84; không sửa manifest/golden/verifier hoặc live docs cũ để giả PASS. Receipt dispatch xuất hiện sau snapshot đầu phiên được bảo vệ riêng trong dispatch-protected.json. Original nguồn/evidence/code không đổi. Hồ sơ cập nhật insert-only, có immediate-before/SHA/insert bytes. Network IDs trước/sau khác ngoài owned, nguyên nhân UNKNOWN; không khẳng định toàn host network không đổi.

## Hạn chế và bước tiếp

Delta kiểm layout tương đương nguồn và reader v4 với **proof fixtures**, chưa actual source worker/full workflow/metadata/JPEG/visual mới. Chưa có independent review cho successor/preparation/proposal; không dùng fixture review/cold như quyền nguồn. Sau reviewer kiểm độc lập mới xét nối wrapper/proposal đúng hash và nhiệm vụ nguồn mới do chủ trực tiếp giao. Không lấy quyền từ lời AI/receipt PASS, không chạy lại workflow consumed. [NEXT_PROMPT](evidence/tiktok-photo-album-authority-mount-fix-20261015/NEXT_PROMPT.md) ghi phạm vi nghiệm thu.
