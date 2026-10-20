# Quy tắc giao việc sau nghiệm thu

## Bổ sung15/10/2026 — Giao UI thiết kế lại hai phương án

Chủ nhận xét giao diện quá đơn điệu và yêu cầu đề xuất cách sửa rồi giao **Giao diện WED SNAP** vẽ lại. Đã gửi [TASK hai prototype](evidence/ui-redesign-brief-20261015/TASK.md), tool nhận và chat bắt đầu turn `01a13fd9-17d9-78a2-8c8b-a4203ac46595`. Hướng A sáng là đề xuất ưu tiên, B tối là phương án so sánh; khác bố cục, có desktop/mobile và trạng thái mẫu. Đây là nhiệm vụ UI hiện hành, thay yêu cầu chỉ đọc/chờ bên dưới.

Phạm vi giai đoạn này: `design/ui-redesign-v1/` và `docs/evidence/ui-redesign-v1-20261015/`, chưa sửa apps/web hoặc backend. Dùng Taste Skill dự án và đọc redesign-existing-projects chính chủ làm tham khảo, không tự cài thêm skill/dependency. Bàn giao bản xem được để chủ chọn hướng trước khi tích hợp. Code tay to tiếp tục lab DNS riêng; không sửa chồng tệp hoặc chạy kiểm nặng đồng thời. Không nguồn/Docker/main/deploy.

## Bổ sung15/10/2026 — Chat riêng cho giao diện

Chỉ thị mới của chủ:

> “thôi đoạn chat kia thì dùng để sửa giao diện đi đầu tiên bạn chụp cho tôi toàn bộ giao diện web hiện tại để tôi sửa”

Đã tạo chat **Giao diện WED SNAP**, threadID `01a13fb6-b8a9-7e50-92c9-81498edea16d`, hostlocal/projectWED SNAP, dành riêng cho UI. Ảnh before hiện tại ở docs/evidence/ui-current-capture-20261015/index.html. Chat đã được giao đọc AGENTS/TasteSkill và bản đồ màn→file, chờ yêu cầu chỉnh cụ thể, chưa tự redesign hoặc sửa code.

Các nhiệm vụ UI được giao chat này; “code tay to” giữ phần luồngtải/backend và việc đã được giao. Chia phạm vi file rõ, tránh chỉnh chồng và không chạy build/test nặng đồng thời trên RAM8GB. Chỉ thị tạo chat UI không là quyền thay backend/contracts/main settings/schema hoặc mở nguồn/deploy. Các quy tắc13/10 bên dưới vẫn áp dụng trong phần không xung đột.


Chỉ thị hiện hành của chủ dự án, ngày13/10/2026:

> “lúc bạn nghiệm thu xong thì giao luôn cho code tay to làm nếu không thì cũng có tự lập chat mới rồi giao việc”
>
> “nếu liên quan tới code thì giao cho code tay to còn không thì có thể lập chat mới”

Sau mỗi lần kiểm chứng/nghiệm thu, cập nhật AUDIT_TIEN_DO.md và PROGRESS.md, xác định nhiệm vụ tiếp theo và giao luôn trong phạm vi dự án đã được phép. Có lỗi thì giao sửa lỗi trước; đạt thì chuyển sang bước tiếp theo của kế hoạch. Việc giao phải có nội dung cụ thể, giới hạn và tiêu chí bàn giao; ghi rõ kết quả nghiệm thu khác với trạng thái nhiệm vụ mới đang chạy.

Việc liên quan đến code — gồm sửa lỗi, triển khai, kiểm thử kỹ thuật, thiết kế kiến trúc hoặc kế hoạch thay đổi code — ưu tiên gửi chat **“code tay to”**, threadID `01a11517-a7fc-7e02-ae6c-80cfe5436ba0`, host `local`, dự án WED SNAP. Kiểm trạng thái để không gửi trùng nhiệm vụ đã giao hoặc chạy cùng kiểm nặng trên máy RAM8GB.

Việc không liên quan đến code có thể tạo chat riêng với đề bài đầy đủ, tài liệu tham chiếu và kết quả cần bàn giao. Dùng đúng dự án WED SNAP nếu cần truy cập hồ sơ dự án. Không tạo thêm chat khi không có nhiệm vụ cụ thể.

Không xin lại phép chỉ để gửi nhiệm vụ thuộc phạm vi đã được chủ giao. Chỉ thị này là quyền điều phối/giao việc, không thay các quota nguồn, quyền triển khai hay giới hạn riêng của từng nhiệm vụ. Task/claim nguồn đã consumed vẫn giữ nguyên; việc lập kế hoạch hoặc kiểm offline không tự trở thành lượt tải nguồn mới. Giữ AGENTS.md, RAM8GB, ưu tiên thư viện và yêu cầu đọc Taste Skill khi thực sự làm UI/UX.

Sau giao việc, xác nhận công cụ đã nhận lệnh hoặc chat đã bắt đầu; cập nhật threadID/trạng thái trong tiến độ. Không báo hoàn thành code khi mới gửi prompt. Quy tắc này áp dụng trong các phiên làm tiếp, không phải lịch tự động hay lệnh gọi nguồn/deploy nền.
