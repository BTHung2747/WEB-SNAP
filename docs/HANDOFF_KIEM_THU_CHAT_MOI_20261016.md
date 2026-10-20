# Bàn giao chat kiểm thử WED SNAP — 16/10/2026

Chủ dự án yêu cầu tạo chat kiểm thử/nghiệm thu mới vì lịch sử chat cũ quá dài. Chat mới tiếp quản vai trò reviewer độc lập: kiểm bản bàn giao mới nhất, nêu lỗi thật và bước tiếp theo, cập nhật tiến độ rồi giao đúng việc cho chat triển khai. Không cần đọc lại toàn bộ lịch sử cũ.

## Bắt đầu từ hồ sơ hiện hành

Làm việc tại `D:\WED SNAP`, PowerShell/Windows, RAM8GB. Đọc toàn bộ `AGENTS.md` và `docs/CURRENT.md`; hai file này là điểm vào bắt buộc. Sau đó chỉ mở source, TASK/HANDOFF/ASSESSMENT và phần STRUCTURE đúng nhiệm vụ đang review.

Không đọc toàn bộ PLAN, AUDIT, PROGRESS, TEST_REPORT hoặc `docs/evidence/` khi bắt đầu lượt. AUDIT/PROGRESS chỉ được đọc theo heading/ngày/keyword cụ thể; evidence đọc theo đường dẫn được CURRENT hoặc nhiệm vụ chỉ tới, ưu tiên ASSESSMENT/HANDOFF rồi mới raw tối thiểu. Tìm kiếm dùng `rg --ignore-file .ignore` và giới hạn component; không dùng `rg -uu`, không liệt kê recursive toàn root, không đổ raw log/JSONL vào chat.

Mục lịch sử không phải lệnh chạy lại. Nếu tài liệu cũ mâu thuẫn với CURRENT hoặc source, xác minh đúng một hồ sơ gần nhất rồi cập nhật CURRENT ngắn; không mở rộng sang toàn bộ lịch sử để “cho chắc”.

## Những phần đã nghiệm thu

- **Giao diện A sáng đã tích hợp vào apps/web**: nền kem, chữ than, cam đất; giữ React/Vite/Tailwind và phụ thuộc hiện có. Trình bày desktop/mobile, bàn phím/focus, video/photo chọn–chuẩn bị–hủy đạt kiểm offline. Báo cáo: `docs/evidence/ui-a-app-integration-review-20261016/ASSESSMENT.md`.
- **Hai nhánh UI ảnh còn thiếu đã nghiệm thu độc lập**: quyền ảnh false/thiếu chặn prepare/ticket/native link; khi bật quyền, native JPG và ticket lỗi→tạo lại đúng, không analyze/prepare lại. Báo cáo mới nhất: `docs/evidence/ui-photo-branches-review-20261016/ASSESSMENT.md`; proof/browser/request cùng thư mục. Không có lỗi app phải vá trong hai nhóm này. Đây là UI React thật với API fixture, không phải backend thật.
- Build frontend và69ca fixture đạt là kết quả tác giả đã chạy trong bàn giao tích hợp; reviewer kiểm chéo artifact và thử browser riêng, không nhận là tự chạy lại toàn bộ matrix. Không chạy lại chỉ để tăng số test.
- **Ảnh nguồn TikTok qua backend** từng đạt một lượt được chủ giao: `docs/evidence/tiktok-photo-source-fixed-live-review-20261015/ASSESSMENT.md`. Một JPEG ảnh2 thực tải, reviewer mở và đối chiếu đúng byte với ảnh đã chủ xác nhận. Hai video và bộ5ảnh đã có xác nhận hình/tiếng/watermark trước đó. Không hỏi lại các xác nhận cũ, không lấy chúng làm bằng chứng cho lượt mới.
- Contract backend→UI được nghiệm thu: `docs/TIKTOK_PHOTO_UI_BACKEND_HANDOFF.md` và `docs/evidence/tiktok-photo-ui-backend-handoff-review-20261015/ASSESSMENT.md`.

Chưa chứng nhận UI+backend thật, reduced-motion browser runtime, native media download trong lượt UI mới, mọi link/toàn album, main activation hoặc deploy. Yêu cầu watermark là loại phần nền tảng thêm lúc tải, giữ chữ/logo có sẵn của tác giả/nội dung.

## Việc cần tiếp tục trước tiên tại thời điểm bàn giao — đã hoàn tất 16/10/2026

DNS child/layout recipe `/app` đã được nghiệm thu độc lập ĐẠT tại `docs/evidence/tiktok-dns-app-port-review-20261016/ASSESSMENT.md`. Không chạy lại hoặc giao tiếp vòng DNS này nếu không có delta/finding mới. Nội dung dưới đây được giữ để truy nguyên trạng thái tại thời điểm chat mới được tạo, không còn là lệnh hiện hành.

**Bàn giao DNS child/layout recipe ứng dụng của code tay to đang dở.** Đọc nhiệm vụ `docs/evidence/ui-photo-branches-review-20261016/NEXT_TASK_DNS_HANDOFF.md` và nhiệm vụ gốc `docs/evidence/tiktok-dns-app-port-dispatch-20261015/TASK.md`.

Snapshot vừa kiểm: lượt backend `01a14252-9885-7bd3-a101-32c9070e2bcb` có trạng thái interrupted; chưa thấy HANDOFF trong `docs/evidence/tiktok-dns-app-port-20261015/` tại thời điểm bàn giao. Chat báo đã tìm được kết quả probe tối15/10: import child/invalid input/reap đạt, recipe `/app` không cần vá, thêm path chỉ cho mount lab `/repo`. **Đây là báo cáo của chat, chưa được reviewer độc lập nghiệm thu**; xác minh bằng raw evidence và thời điểm/lệnh thực chạy. Trong namespace đã có app_layout_probe.py, run-probe.ps1 và fingerprint trước; tìm runtime đã có, không suy script tồn tại là test đã chạy.

Hành động đầu tiên: kiểm trạng thái backend và bàn giao mới nhất. Nếu vẫn thiếu HANDOFF/interrupted thì giao code tay to hoàn tất hồ sơ từ kết quả có sẵn; nếu đã bàn giao thì nghiệm thu độc lập, chỉ thực hiện kiểm thêm cần thiết. Không lặp container/build/nguồn hoặc viết harness mới để thay việc đọc bằng chứng. Sau kết luận, chốt một bước tiếp cụ thể hướng tới ứng dụng dùng được; không sa vào vòng test tài liệu vô hạn.

## Phối hợp đã được chủ cho phép

Chủ yêu cầu sau nghiệm thu phải ghi prompt bước tiếp và giao luôn cho chat triển khai khi có việc cụ thể, không chỉ đưa prompt rồi dừng.

- Chat **code tay to**, thread `01a11517-a7fc-7e02-ae6c-80cfe5436ba0`, host local: backend/code tải/egress. Trạng thái/cursor có thể đổi; dùng wait_threads để lấy mới.
- Chat **Giao diện WED SNAP**, thread `01a13fb6-b8a9-7e50-92c9-81498edea16d`, host local: frontend. Hai nhóm UI ảnh đã hoàn tất, đang idle tại bàn giao. Không giao thêm test UI khi không có finding/delta.

Chat mới được chủ cho phép gửi nhiệm vụ cụ thể cho hai chat trên trong phạm vi dự án và kiểm thử này. Tránh giao chồng file hoặc lặp nhiệm vụ đang chạy. Tạo thêm chat chỉ khi chủ yêu cầu/ủy quyền rõ và có nhu cầu; không tự tạo chuỗi chat kiểm thử vô hạn. Không cần xin lại quyền cho đọc hồ sơ, kiểm offline phù hợp và giao việc đã thuộc phạm vi này.

## Nguyên tắc giữ lại

- Mỗi lần kiểm phải phân biệt đọc code/log cũ, test mới thực chạy, API giả lập, backend và nguồn thật. Chat completed không có nghĩa chức năng PASS. Nếu bị interrupted thì tiếp từ bằng chứng có sẵn, không khởi động lại toàn bộ.
- Sau nghiệm thu cập nhật `docs/CURRENT.md` ngắn gọn và liên kết tới nguồn chuẩn. Chỉ thêm AUDIT/PROGRESS khi chủ hoặc cổng nghiệm thu yêu cầu lưu mốc lịch sử; không sao chép cùng một kết luận/prompt vào cả hai. Lưu evidence mới vừa đủ, không nhân bản log/ảnh/tài liệu nặng vô ích.
- Không sửa manifest/golden/pins lịch sử cho khớp source mới. UI A thay apps/web hợp lệ nên hash source mới có thể khác snapshot cũ; ghi delta riêng, không revert UI.
- Ưu tiên thư viện hiện có; vấn đề khó cần tra cứu repository/tài liệu chính thức và giải pháp mã nguồn mở phù hợp trước khi tự viết lại. Làm UI đọc `.agents/skills/design-taste-frontend/SKILL.md`; không tự redesign khi chỉ kiểm toán.
- Giữ capability, CSRF, session/job/transfer lease, lifecycle đầy đủ và native download; không đổi logic để đẹp hơn. Không chồng apps/egress với frontend.
- Không tự tải thêm TikTok/YouTube/CDN/public DNS, retry nguồn hoặc tái dùng grant một lần đã sử dụng. Giữ phạm vi hiện tại offline; không bật flags/main, đổi settings/DB/env/compose hoặc deploy trong nhiệm vụ bàn giao này.
- RAM8GB: kiểm tuần tự, không nhiều dịch vụ/build nặng; không cài dependency/image mới chỉ để kiểm. Evidence nén tra docs/EVIDENCE_ARCHIVES.md; không sửa verifier bỏ qua archive.

Preview có thể còn chạy:5198 là build React + fixture,5199 là hai nhánh ảnh + fixture,4318 là prototype. `/capture-gallery`5198 là gallery cũ, không chứng nhận UI hiện hành. Browser chỉ thao tác bằng công cụ browser được hỗ trợ, kiểm DOM/viewport trước khi kết luận ảnh chụp; ảnh capture race từng được loại khỏi kết luận.

Đọc tài liệu hiện hành trước khi hành động vì tiến độ có thể đã thay đổi sau thời điểm ghi file. Giao tiếp tiếng Việt ngắn, nói rõ đạt/chưa đạt và bước tiếp, không đưa hàng loạt mã/hash vào câu hỏi người dùng.
