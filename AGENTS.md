# Hướng dẫn làm việc trong WED SNAP

Trước khi làm việc, chỉ đọc toàn bộ `AGENTS.md` và `docs/CURRENT.md`. Sau đó đọc đúng tài liệu/component mà nhiệm vụ cần theo bảng định tuyến trong `docs/CURRENT.md`; không mặc định đọc toàn bộ PLAN, AUDIT, PROGRESS, README, TEST_REPORT hoặc `docs/evidence/`. Tôn trọng phạm vi người dùng giao; các chỉ thị được ghi là lịch sử không phải nhiệm vụ cần chạy lại.

## Ngân sách ngữ cảnh và cách đọc

- `docs/CURRENT.md` là bản tóm tắt trạng thái hiện hành cho agent. Nếu tài liệu lịch sử mâu thuẫn với mã nguồn hoặc CURRENT, kiểm tra đúng bằng chứng liên quan rồi cập nhật CURRENT; không nạp thêm lịch sử không liên quan để “cho chắc”.
- Chỉ đọc `PLAN_WORKFLOW_VIDEO_DOWNLOADER_V1.md` khi nhiệm vụ thay đổi phạm vi sản phẩm, kiến trúc, cổng nghiệm thu hoặc chính sách vận hành. Chỉ đọc `docs/STRUCTURE.md` khi cần định vị component hoặc đối chiếu đường dẫn cũ–mới.
- `docs/AUDIT_TIEN_DO.md` và `docs/PROGRESS.md` là lịch sử dài. Chỉ đọc mục mới nhất liên quan hoặc heading/ngày/keyword được nhiệm vụ dẫn chiếu; không dùng `Get-Content -Raw` cho hai file này. Không coi prompt lịch sử là lệnh hiện hành.
- Với `docs/evidence/`, mở trước `ASSESSMENT.md`, `HANDOFF.md`, manifest hoặc file được CURRENT/nhiệm vụ dẫn trực tiếp. Không liệt kê hay tìm kiếm toàn bộ evidence, không đọc raw log/JSONL/video/certificate nếu không cần để kết luận cụ thể.
- Tìm file/text phải giới hạn vào component, ưu tiên `rg --ignore-file .ignore`. Không chạy tìm kiếm toàn workspace với chế độ bỏ ignore; khi cần hồ sơ lịch sử, chỉ định chính xác thư mục evidence. Giới hạn output bằng tên file, dòng khớp hoặc một đoạn nhỏ thay vì đổ nguyên log.
- Sau một thay đổi, cập nhật CURRENT ngắn gọn. Chỉ thêm AUDIT/PROGRESS khi người dùng hoặc cổng nghiệm thu yêu cầu mốc lịch sử; dùng liên kết tới nguồn chuẩn, không sao chép cùng một kết luận/prompt vào nhiều file.

## Vị trí mã nguồn

Đọc `docs/STRUCTURE.md` để xác định đúng phần cần sửa. Code ứng dụng nằm trong `apps/`; bộ tải yt-dlp/FFmpeg ở `apps/media/`, proxy nguồn ở `apps/egress/`. Lab renderer TikTok đang phát triển ở `labs/tiktok/renderer/`; đây chưa phải tính năng đã tích hợp vào ứng dụng. `tests/` chứa kiểm thử, công cụ nghiệm thu lịch sử và điểm chuyển tiếp cho lệnh lab cũ; `docs/evidence/` chứa bằng chứng đóng băng.

Sau khi đổi cấu trúc ngày07/10/2026, không tìm code chính tại `infra/media_adapter.py` hoặc `infra/egress.py`. Đối chiếu bảng di chuyển trong `docs/STRUCTURE.md` và `docs/evidence/structure-20261007/` khi đọc hồ sơ cũ. Không sửa manifest/verifier lịch sử để che thay đổi đường dẫn được giao; không chạy lại nhiệm vụ lịch sử chỉ vì thấy đường dẫn cũ.

## Ưu tiên thư viện và giải pháp có sẵn

Trước khi viết hoặc thay đổi chức năng, agent phải kiểm tra mã nguồn, dependencies/lockfile hiện tại và tìm thư viện hoặc giải pháp mã nguồn mở phù hợp. Nếu có thư viện đáp ứng yêu cầu, phải ưu tiên dùng API chính thức của thư viện đó và chỉ viết phần tích hợp cần thiết; không tự viết lại chức năng đã có hoặc suy đoán cách thư viện hoạt động.

- Ưu tiên thư viện đã có trong dự án. Nếu cần thư viện mới, kiểm tra tài liệu và repository chính thức, khả năng còn được duy trì, giấy phép, tương thích phiên bản/stack, bảo mật và chi phí tài nguyên trên máy RAM 8 GB. Không chọn chỉ vì nhiều sao hoặc README quảng cáo có hỗ trợ.
- Xác minh API, tùy chọn và hành vi bằng tài liệu/mã nguồn chính thức đúng phiên bản; ghi nguồn tham khảo và lý do chọn trong bàn giao. Khi chưa xác minh được, nêu rõ phần chưa biết, không bịa API hoặc kết quả.
- Chỉ tự triển khai phần mà thư viện không đáp ứng, hoặc khi có lý do cụ thể về bảo mật, giấy phép, tương thích, tài nguyên hay yêu cầu nghiệp vụ. Trước khi làm, nêu thư viện đã xem xét, hạn chế và phạm vi cần tự viết; không cần xin lại phép cho lựa chọn đã nằm trong nhiệm vụ được giao.
- Việc có thư viện phù hợp không tự mở rộng quyền cài dependency, build image, đổi framework, dùng dịch vụ ngoài hoặc deploy. Khi được phép thêm dependency, chốt phiên bản/lockfile và kiểm chứng chức năng tích hợp bằng kiểm tra phù hợp; không coi cài thành công là chức năng đã hoạt động.

## Skill thiết kế UI/UX

Khi nhiệm vụ bao gồm thiết kế hoặc cải thiện giao diện, bố cục, kiểu chữ, màu sắc, responsive hoặc trải nghiệm người dùng, đọc `.agents/skills/design-taste-frontend/SKILL.md` trước khi đề xuất và sửa giao diện. Đây là Taste Skill từ `Leonxlnx/taste-skill`, tên skill `design-taste-frontend`.

- Dùng quy tắc phù hợp với mục tiêu và người dùng của WED SNAP. Với giao diện đã có, đánh giá trước khi thiết kế lại; giữ những gì đang hoạt động và chỉ thay đổi trong phạm vi được giao.
- Skill hướng tới landing page, portfolio và redesign. Khi làm admin, bảng dữ liệu hoặc luồng sản phẩm, chỉ áp dụng nguyên tắc phù hợp; ưu tiên yêu cầu của kế hoạch và khả năng sử dụng.
- Giữ React/Vite/Tailwind và các phụ thuộc hiện tại trừ khi nhiệm vụ đã cho phép thay đổi. Việc đọc skill không tự mở rộng nhiệm vụ thành cài thư viện, chuyển framework, nâng Tailwind, build lại stack chính hoặc deploy.
- Giữ đầy đủ trạng thái idle/analyzing/selectable/queued/preparing/ready/failed/cancelled/expired, tính độc lập giữa phiên–job–transfer lease, CSRF và liên kết tải native. Không đổi logic vòng đời đã nghiệm thu chỉ để phục vụ hình thức.
- Quảng cáo/tài trợ có nhãn rõ, đóng được khi phù hợp và không chặn chuẩn bị hay tải. Không bịa nền tảng hỗ trợ, kết quả tải, số liệu hoặc nội dung đánh giá.
- Kiểm tra bàn phím, focus, tương phản, màn hình hẹp và reduced motion; lưu bằng chứng đúng phạm vi. Không coi browser fixture là backend live hoặc tải nền tảng thật.

Cài skill chỉ chuẩn bị cho các phiên thiết kế sau; không tự khởi động một đợt redesign trong phiên kiểm toán hoặc sửa lỗi chức năng. Chỉ thị trực tiếp của người dùng được ưu tiên khi có xung đột với skill.

## Tài nguyên và bằng chứng

### Chỉ kiểm thử những gì cần thiết — chỉ thị chủ ngày 24/10/2026

- Mỗi lượt kiểm phải trả lời một câu hỏi cụ thể về phần mã vừa đổi, lỗi đã quan sát hoặc cổng nghiệm thu của luồng người dùng đang làm. Chọn lệnh/nhóm kiểm nhỏ nhất đủ trả lời; không tăng số test để tạo tiến độ.
- Tái dùng kết quả đã đạt khi component không đổi và không có bằng chứng lỗi mới. Không chạy lại startup profile, UI fixture, bộ tải hay kiểm môi trường đã khép chỉ để xác nhận thêm.
- Ưu tiên test sẵn có sát thay đổi. Chỉ chạy toàn suite khi thay đổi ảnh hưởng rộng, kiểm tra bắt buộc yêu cầu, hoặc có bằng chứng hồi quy. Sửa tài liệu và thay đổi nhỏ có thể kiểm trực tiếp thì không thêm test tự động.
- Khi các kiểm tra cần thiết đã đạt, chuyển sang tích hợp/nghiệm thu luồng thực. Reviewer đọc diff và kết quả trước; chỉ chạy thêm nếu có khoảng trống cụ thể hoặc cần tái hiện finding mới, không lặp bộ kiểm của bên code mặc định.
- Không dựng thêm framework, observer, lab hoặc vòng PLAN/review/test nếu bằng chứng hiện có đã đủ chọn bản sửa. Dùng log/công cụ có sẵn; chỉ bổ sung phép đo tối thiểu khi thật sự thiếu thông tin để sửa lỗi đang chặn.
- Bàn giao gọn: phần đã đổi, lệnh thực chạy và kết quả, giới hạn chưa kiểm, bước tiếp theo. Không sao chép/hash lại toàn bộ lịch sử hoặc tạo nhiều báo cáo cùng kết luận. Giữ nguyên bằng chứng cũ và các kiểm tra bắt buộc về quyền nguồn, an toàn dữ liệu, vòng đời, pins và cleanup trong đúng phạm vi thực thi.

Máy có RAM 8 GB: chạy các kiểm tra cần thiết tuần tự, tránh build/test nặng hoặc nhiều dịch vụ cùng lúc. Dùng lab riêng khi nhiệm vụ yêu cầu kiểm thử; không tự thao tác dữ liệu, settings hoặc stack chính ngoài phạm vi được giao.

Phân biệt lệnh thực sự chạy trong phiên với đọc mã nguồn và đọc log lịch sử. Ghi rõ giả lập, môi trường, giới hạn và phần chưa kiểm chứng; cập nhật tiến độ sau triển khai theo yêu cầu của nhiệm vụ.

Một số evidence đã lưu nén theo yêu cầu dọn dung lượng của chủ. Tra `docs/EVIDENCE_ARCHIVES.md` và `docs/evidence/archive-index.json`; dùng `scripts/restore-evidence.ps1 -VerifyOnly` để kiểm lossless hoặc khôi phục khi cần chạy verifier lịch sử đọc đường dẫn nguyên bản. Không sửa manifest/golden hashes để bỏ qua file đã lưu nén; không đọc script gzip như JSON hoặc dùng metadata cleanup làm kết quả test chức năng.
