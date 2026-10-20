# Phân công frontend/backend cho bước kiểm UI với nguồn thật

Theo chỉ thị mới của chủ: **Giao diện WED SNAP xử lý frontend; code tay to xử lý backend; chat kiểm thử hiện tại điều phối và nghiệm thu độc lập.** Không tạo chat mới hoặc giao chéo quyền sửa component.

## Mốc xuất phát và giới hạn chung

- Đọc toàn bộ AGENTS.md + docs/CURRENT.md, rồi đúng component/handoff cần dùng. Mốc chuẩn: docs/evidence/ui-final-fixture-review-20261016/ASSESSMENT.md; UI A→backend fixture đã đạt, không chạy lại chỉ vì hồ sơ cũ còn prompt.
- Mục tiêu tiếp theo là một workflow UI A→backend→một bài ảnh TikTok công khai được chủ chốt, chọn một ảnh, không album/batch/video hay nền tảng khác. Đây chưa phải quyền bật main/gallery/deploy hoặc production acceptance.
- **Giai đoạn đang giao là chuẩn bị offline và chốt hợp đồng ghép nối. Chưa launch stack/browser/source, chưa publicDNS/CDN hoặc tạo source grant/claim.** Reviewer đang hỏi chủ dùng lại bài ảnh đã kiểm hay link mới; lời giao nguồn cũ đã dùng xong, không tái sử dụng.
- Hai chat có thể đọc mã/chuẩn bị tài liệu song song; máy8GB không chạy hai bộ build/test/service cùng lúc. Chỉ backend được sở hữu runner và runtime của lượt tích hợp sau; frontend chỉ điều khiển browser của đúng lượt đó khi reviewer bật đèn xanh. Không tự mở server fixture/stack thứhai.
- Giữ app/UIA/lifecycle/schema/lock/settings hiện hành và evidence/golden cũ. Không install/pull/buildimage/đổi framework/library, không redesign. Nếu phát hiện lỗi cần đổi code ứng dụng, báo finding/repro/phạm vi trước; nhiệm vụ readiness không phải quyền sửa rộng.

## Giao diện WED SNAP — frontend và browser operator

1. Đọc apps/web và API contract đang dùng đúng phạm vi photo. Đối chiếu UI A đã nghiệm thu với luồng thật: capability từ session, analyze/selectable/chọn ảnh02/prepare/ready/ticket/native link, error/cancelled/expired, URL ảnh/previewnull và không quảng cáo vẫn dùng được. Không giả response/backend hoặc gán capabilitytrue cố định.
2. Giữ thiết kế/build A nếu không có finding. Không chạy lại bộ desktop/mobile/capability/DNS/handshake lịch sử. Nếu đụng thiết kế/UX, đọc Taste Skill theo AGENTS trước; không tự redesign vì được giao frontend.
3. Chốt checklist thao tác browser dựa trên **chuỗi13operation đã đạt ở final fixture**, dùng AX hiện hành để định vị (không hardcode index96 của phiên cũ). Mỗi call một UIoperation/BEGIN-END/timing; một native click, không waitForEvent(download)/path/navigationwait hoặc Promise.race coi như hủy provider. Không đổi native link thành fetch/blob tự tải.
4. Chốt cách báo tệp đã lưu: nếu công cụ không chứng minh savedfile thì UNKNOWN, tách browser HTTPresponse/APIexport với saveddevice; chuẩn bị hướng dẫn xác nhận thủ công cho chủ khi đến lượt thật, không tự đọc Downloads hoặc lấy inputfixture làm output.
5. Bàn giao **FRONTEND_READY hoặc finding cụ thể**, current28web/3build pins, selectors/contract cần backend, nguyên tắc ticketredaction/tab ownership và các giới hạn. Chỉ thêm thông tin mới cho lượt nguồn, tham chiếu checklist/bằng chứng có sẵn thay vì chép lại hoặc tạo testharness.

Output: docs/evidence/ui-source-readiness-20261016/frontend/HANDOFF.md (namespace mới, không ghi đè evidence đã đóng). Kết thúc lượt bằng bản tóm tắt và dừng; reviewer sẽ đọc trạng thái/handoff, chưa tự điều khiển browser hay nhắn chat khác nếu chưa có phép trực tiếp của chủ.

## code tay to — backend và chủ runtime

1. Đối chiếu recipe nguồn ảnh đã đạt15/10 với runner UI fixture đã đạt16/10. Chuẩn bị **successor wiring/source-mode fail-closed**, giữ API/BullMQ/productionprocessor/haiCLI child/gateway/helper đã nghiệm thu. Không viết lại parser/HTTP/DNS/library hoặc thay APIcontract cho frontend.
2. Source-mode phải thực dùng ownedegress/TLS/DNSpolicy của recipe nguồn đã đạt, không để sitecustomize/fixture server/body/JPEG giả che nguồn thật. Giữ tách fixture vs source; thiếu URL/grant/budget được chốt thì từ chối trước network. Không tạo grant/claim mới hay tái dùng grant đã consumed trong giai đoạn này.
3. Chuẩn bị preflight/argv/mount/import/pin tối thiểu của delta, map đúng runtime cần dùng. Giữ media leafRO/cachedeps, controller/gateway observation mới, logserialize/finalguards/nooverwrite, fixedupstream/APP_ORIGIN/CSRF/session/native/Range/HEAD. Không sửa snapshot/golden hoặc chạy containerprobe/fullfixture thêm để chuẩn bị.
4. Ghi đề xuất lượt nguồn **một lần**, chưa thực hiện: một canonical bài ảnh/chọn một ảnh (mặc định02 nếu chủ chọn lại mẫu cũ), analyze2metadata+prepare2freshmetadata+1JPEG, không retry/redirect ngoài policy hiện hành; giữ byte/timecaps đã nghiệm thu, tổng≤480s/cleanup20s/runtime≤1GiB. Đây là trần để reviewer chốt cùng URL, không tự cấp quyền gọi nguồn.
5. Hợp đồng phối hợp: backend launch đúng một runner sau lệnh mới của reviewer/chủ, thông báo runID/origin/readiness/deadline và handoff browser cho frontend; không tự click hoặc chạy workflow API song song. Browser native response phải phân biệt với local APItransfer; final file/hash/decode, negatives403/404, HEADlease/GET/Range, closure/cleanup/handshake giữ gates đã đạt. Không hardcode output64×64/248B/fixtureSHA làm kết quả nguồn thật.
6. Bàn giao **BACKEND_READY hoặc finding cụ thể**, delta/mount plan/gate trước network, sourcebudget đề xuất, pins và phần nào còn chờ URL/quyền. Không tạo thêm harness hoặc chạy test lịch sử không liên quan. Không bật main/gallery, sửa mainDB/settings, build/pull/install/deploy.

Output: docs/evidence/ui-source-readiness-20261016/backend/HANDOFF.md và successor nhỏ nếu thật sự cần wiring; chưa runtime/network. Kết thúc báo reviewer theo chỉ thị báo cáo trực tiếp của chủ còn hiệu lực rồi dừng; không chat Thông báo hoặc tự bước tiếp.

## Reviewer điều phối

- Đọc hai handoff, đối chiếu contract/pins/ownership và xác nhận không còn finding chặn. Chốt URL được chủ cho phép cùng một grant/budget mới trước nguồn thật; không suy quyền chỉ từ việc chuẩn bị code thành công.
- Sau đó mới giao lượt tích hợp cụ thể: backend giữ runtime, frontend giữ browser, reviewer chờ hai bên hoàn tất rồi kiểm raw/file/gates độc lập. Không chạy reviewer lab song song với backend, không hai owner browser/runtime, không lặp nguồn khi thất bại nếu chưa có lời giao mới.
- Chỉ reviewer cập nhật mốc điều phối CURRENT để tránh hai chat ghi đè cùng file. Hai chat viết handoff riêng, không đổi AUDIT/PROGRESS/evidence lịch sử hoặc tự đánh dấu toàn sản phẩmPASS.
