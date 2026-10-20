# Backend: hoàn tất metadata môi trường/cache chỉ đọc

19/10/2026, Asia/Saigon. Chủ cho reviewer tự giao bước phù hợp sau nghiệm thu và vừa yêu cầu “tiếp đi” sau khi reviewer tự thấy Docker UI Engine running. [Một query local mới qua exec được phê duyệt](../evidence/ui-source-local-access-probe-20261019/reviewer/ASSESSMENT.md) actual0/nativePASS cho server29.8.1/API1.56/linux/amd64. Đây là cơ sở tiếp tục phạm vi **readonly** từng bị chặn, không quyền tạo/chạy tài nguyên hay nguồn.

## Nguồn và phạm vi

- Đọc AGENTS/CURRENT, assessment probe ở trên và [readonly review trước](../evidence/ui-source-environment-readonly-review-20261019/ASSESSMENT.md). Giữ correction Python:6root0 khác5nativePASS/3FAIL; không làm lại query cũ để che FAIL.
- Evidence mới `docs/evidence/ui-source-cache-metadata-readonly-20261019/backend/`; script nếu cần `labs/tiktok/ui-source-cache-metadata-readonly/`.
- Owner24source/helper, diagnostic4+36artifact, triage3+17artifact, app/UI/glue/prelaunch/lock/policy và manifests lịch sử giữ nguyên. Chỉ code diagnostic glue tối thiểu, ưu tiên helper/APIs đã có, không package/compiler/SDK mới.

## Đường thực thi và quyền

Không chạy query trong context đã bị từ chối rồi lặp lại cho PASS. Sử dụng cơ chế `exec_command` yêu cầu `sandbox_permissions=require_escalated` với justification mô tả rõ **các query chỉ đọc** sẽ chạy, endpoint/scope/caps và cấm mutation; không dùng prefix phê duyệt PowerShell rộng. Công cụ phê duyệt từng request theo policy; probe reviewer không là blanket approval cho mọi lệnh. Nếu phê duyệt bị từ chối, dừng phần đó và báo, không bypass bằng UI terminal/pipe/transport hay thay token.

Đây không yêu cầu RunAs Administrator, UAC, group membership, ACL/settings/sandbox changes hoặc start/restart Docker. Chỉ exact local `npipe:////./pipe/dockerDesktopLinuxEngine`, absolute executable có SHA đã pin trong probe/readonly evidence. Kiểm lại override env và pins trước query, không clear/đổi context/env để vượt kiểm. Không query version/context/time/port/token inventory lại; reference proof mới và nêu freshness/giới hạn.

## Tối đa7daemon CLI queries, tuần tự, không retry

1. `info`: projection tối thiểu server OS/version/architecture, CPU/memory, engine advertised cgroup/security capabilities nếu field/API đúng. Không full info/proxy URLs/credentials hoặc Config.Env. Engine quảng cáo cgroup/seccomp không là proof áp dụng lên role.
2. Bốn `image inspect`, mỗi đúng immutable ID trong plan hiện hành (`ui-source-prelaunch/wiring.ps1`/Get-PrelaunchPlan;5roles chia4image IDs). Chỉ ID/OS/architecture/size và role association cần thiết; không pull/build, tag lookup thay ID, Env/metadata secrets dump hoặc filesystem scan trong image.
3. Một scoped container list: đúng label `com.wed-snap.run` và name `wed-source-` như plan/hồ sơ, projection ID/name/state/owner run label. Không global list/inspect main stack/logs/env/container filesystem; resources cũ nếu có chỉ báo, không sửa/xóa/stop.
4. Một scoped network list: cùng lab label/name constraint, projection ID/name/driver/scope cần; không network mutation hoặc khẳng định absence ngoài scope query.

Xác minh exact CLI29.8.1/API1.56 source/type/field trước các template còn chưa được kiểm: không lấy source URL404 hoặc README chung thay API response contract. Dùng tài liệu/repository chính thức, không tải binary/package. Nếu chưa xác minh field, bỏ query liên quan/đánh dấu NOT_RUN thay vì thử nhiều template trên daemon. Không dùng full raw response để dò field.

Mỗi child watchdog≤15s/capture combined≤64KiB, từng lệnh một, không nhiều service/suite trên RAM8GB. Dùng đúng helper Win32 đã review để own job/stdio/EOF/proof, pin source/binary/exe, raw bounded RAM; chỉ lưu allowlist projection/sanitised code. Native root0, tree closure và operation success là các điều kiện riêng. API/parser/permission/timeout/cap/pin lỗi thì dừng dependencies, giữ FAIL/UNKNOWN, không retry hoặc tăng caps. Script exit0 không làm mọi observation thành PASS.

## Không được làm

Không Docker run/create/start/restart/stop/kill/rm/prune/build/pull/load/exec/cp/commit, compose, network create/connect/disconnect/rm; không VM/service/WSL/settings/ACL/group/token/security changes hoặc diagnose upload. Không pipe/daemon HTTP bypass, remote endpoint, default-context fallback, source HTTP/DNS/TikTok/CDN/app health/browser, live signer/approval/grant/claim, main/gallery/deploy. Không frontend workflow hoặc sửa giao diện.

Không tái chứng nhận Node22Linux imports/schema/mapping/UID ACL/cgroup role isolation/egress bằng cache/info metadata. Những mục đó giữ NOT_RUN/UNKNOWN, đề xuất bounded offline probe riêng nếu sau này cần quyền tạo/chạy tài nguyên. Current owner source/admission không được mở gate vì các query readonly đạt.

## Bàn giao và dừng

HANDOFF/manifest mới có exact commands/native exits/durations/caps/job/EOF, field provenance/version, observed metadata vs expectations vs NOT_RUN; mapping4IDs/5roles; source before/after và frozen reference hashes tối thiểu; giữ mọi FAIL, không viết lại manifest/golden. Ghi scope quyền exec thực được phê duyệt, không suy quyền nguồn hoặc causal token/ACL proof từ query thành công.

Báo reviewer chat `01a14259-19b0-73f0-bd0c-0f5be84f6a88` theo chỉ thị chủ rồi dừng. Reviewer kiểm sau bàn giao, không test song song; CURRENT do reviewer cập nhật. Frontend READY/chờ cho đến khi có nhiệm vụ phù hợp thật sự.
