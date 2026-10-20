# Vòng đời tải và lưu trữ

Ba đối tượng độc lập: trang sở hữu tác vụ, tài sản tạm và request truyền. Không dùng đóng tab làm tín hiệu dọn duy nhất.

| Đối tượng | Trạng thái |
|---|---|
| Tác vụ | analyzing → selectable → queued → preparing → ready; failed/cancelled/expired |
| Tài sản | staging → available → deleting → deleted |
| Request truyền | started → server_finished/disconnected/timed_out |
| Phiên tác vụ | ownerUntil; releaseAt là thời điểm kết thúc grace, heartbeat hợp lệ có thể xóa releaseAt trước khi hết hạn |

| Tham số | Mặc định local |
|---|---|
| Heartbeat trang | 15 giây |
| Metadata lựa chọn analyze chưa dùng | Tối đa120 giây từ metadataAcceptedAt, cố định; now≥metadataExpiresAt hết hạn, heartbeat không renew |
| Không heartbeat | 120 giây |
| Release grace | 30 giây |
| Ready chưa tải | 600 giây tuyệt đối, heartbeat không kéo dài |
| Sweeper | 30 giây |
| Server renew lease | 15 giây |
| Lease TTL | 90 giây |
| Range/retry grace | 120 giây sau request cuối |
| Deadline truyền | 1800 giây từ request đầu, không kéo dài bằng retry |
| Cookie phiên | 24 giờ; tác vụ vẫn có hạn riêng |

Các TTL cấu hình và hạn mức nằm trong `.env.example` và cấu hình admin.
Riêng metadataTTL có trần cố định120000ms trong shared core, không có setting
admin để gia hạn. Thay đổi được audit; các trần MVP không âm thầm mở rộng.
Thay đổi chu kỳ sweeper cần restart worker để áp dụng interval mới.

R9 ghi acceptedAt/expiresAt khi processor chấp nhận analyze dưới job lock.
Deadline adapter đáng tin sớm hơn có thể giảm hạn; Python hiện không trả
signed URL expiry. Selectable thiếu timestamp/deadline fail closed; không dùng
updatedAt đang thay đổi theo heartbeat. Status/preview/heartbeat/prepare kiểm
tra ngay và commit expired/JOB_EXPIRED410, dọn formats/source; sweeper dọn
preview/cache. Title/retention24h giữ chính sách lịch sử. Queued/preparing/ready
đã prepare trước hạn cùng ticket/transfer lease không phụ thuộc metadataTTL.
Migration additive R9 **mới áp dụng DB lab03/10/2026**, chưa main apply; xem
[API](API.md) và README6.12. Cleanup≤8s là phép thử gọi production sweep thủ
công trong lab sweep1s, không bảo đảm latency mọi tải/backlog production.

## Chưa tải

`pagehide` gửi release bằng beacon best effort. Ẩn tab không được coi là đã rời trang. `pageshow` và visibility change kiểm tra/gia hạn lại; không hồi sinh job đã hủy/hết hạn. API và worker kiểm tra owner deadline độc lập.

Worker theo dõi DB mỗi giây, gửi SIGTERM đến process group khi hủy/hết hạn, đợi child kết thúc; SIGKILL sau 2 giây nếu cần. Sau đó dọn thư mục UUID, cả `.part`. Sweeper không dọn staging khi worker có lease quá trình còn hiệu lực. Deadline phân tích 30 giây, chuẩn bị 180 giây; worker heartbeat DB chỉ duy trì quyền xử lý, không kéo dài deadline tuyệt đối.

## Đang truyền

Download giữ khóa PostgreSQL job rồi asset, kiểm tra available, chưa hết hạn và quyền phiên, dự phòng số byte Range trong budget tháng, tạo TransferLease cùng transaction. Chỉ sau commit mới mở tệp. Cleanup giữ cùng khóa asset để đánh dấu deleting, ngăn lease mới và chỉ dọn khi không còn lease sống.

TransferDeadline đặt ở lần truyền đầu. Sau thời điểm này, file lifetime không phụ thuộc heartbeat trang hoặc ready TTL. Request hiện tại tự renew lease bằng API; mất heartbeat hoặc release không hủy stream. Chủ động cancel chặn request mới nhưng vẫn đợi lease hiện tại kết thúc để dọn.

Mỗi Range request có lease riêng trên cùng asset/ticket. Request cuối kết thúc mới đặt retryUntil; request mới trong grace xóa retryUntil nhưng không thay transferDeadline. 206 hỗ trợ một range, suffix và range mở; 416 có Content-Range phù hợp. Multi-range chưa hỗ trợ và trả 416. HEAD không tạo lease hoặc tính byte.

`server_finished` chỉ là máy chủ kết thúc stream; counter đếm byte đưa vào pipeline, không chứng minh trình duyệt đã lưu. Khi client ngắt, pipeline dừng, finally kết thúc lease. Tệp không bị xóa vì một request trong nhiều request kết thúc.

## Crash và khôi phục

- API crash: socket kết thúc, lease hết hạn 90 giây nếu finally không chạy. Sweeper đặt timed_out, cho grace retry, rồi dọn.
- Budget dự phòng toàn Range trước khi đọc. Cuối request bình thường hoàn lại phần chưa đưa vào pipeline. Crash giữ nguyên dự phòng; an toàn nhưng có thể tính dư. Không đánh giá nó là hóa đơn nhà cung cấp.
- Worker crash: processUntil hết hạn sau tối đa 15 giây; sweeper đánh dấu WORKER_INTERRUPTED, không tái dùng partial. Docker tini và lifecycle xử lý signal; không chạy ffmpeg bên ngoài container.
- DB state là outbox: tác vụ đã commit nhưng chưa enqueue được Redis được sweeper đưa lại vào hàng đợi. BullMQ job ID xác định theo phase/job; workerToken + khóa DB ngăn chạy trùng.
- Thư mục mồ côi UUID cũ hơn 1 giờ, không có job DB, được dọn. Không theo symlink hoặc dọn ngoài `/media`. `deleting` được tiếp tục sau restart.
- Disk >=80% ngừng chuẩn bị mới. Không xóa lease còn sống. Không tăng giới hạn WSL tự động.
- Metadata đã kết thúc được purge sau 24 giờ; ticket hết hạn và raw AdEvent >30 ngày được dọn. Audit log giữ để điều tra quản trị.

Direct và proxy streaming chưa bật; chỉ tệp tạm có kiểm tra codec. Chưa có giả định thu hồi URL nguồn hoặc xác nhận tải direct hoàn tất.

## Nghiệm thu R3 local ngày 01/10/2026

`scripts/test-p3.ps1` và fixture `tests/p3_fixture_adapter.py` dùng riêng project
`wed-snap-p3-test`, DB `wed_snap_p3_test`, Redis DB 14 và media/control test có guard.
Analyze bình thường đạt selectable; barrier chỉ nằm trong prepare. Release queued
được kiểm tra khi worker còn bận; sau grace không có prepare invocation hoặc
publish ready, kể cả khi hàng đợi được drain. Release preparing kiểm tra child
thật qua PID/start time/namespace: partial còn tồn tại ở SIGTERM và trước child
exit; filesystem watcher xác nhận child đã chết khi partial bị xóa. WorkerToken,
processUntil và staging được kiểm tra sau cleanup.

SIGKILL worker test được thực hiện sau assertion preparing/child/partial; sau
restart partial không bị dọn trước process lease, rồi job WORKER_INTERRUPTED và
asset deleted. Quan sát 70 giây qua các chu kỳ BullMQ stalled để kiểm tra không
prepare trùng/publish, marker process không chạy tiếp và không còn thư mục job.
Timeout test: release queued tối đa 8 giây; preparing tối đa 8 giây tới SIGTERM
và 8 giây từ cho phép child thoát đến cleanup; crash recovery tối đa 25 giây sau
restart và không quá 8 giây sau deadline process lease. Đây là timeout fixture
với release grace 2 giây/sweep 1 giây, không phải SLA runtime chính.

Các ca cũ dùng `delay000001` khi analyzing chỉ chứng minh hủy/crash **analyzing**,
không thay thế hai ca queued/preparing. R3 được đóng ở môi trường local riêng;
P3 vẫn cần test mất heartbeat độc lập, upstream mất mạng/redirect/rebinding và
budget đổi khi transfer đang chạy. Kết quả/lệnh cụ thể trong PROGRESS/TEST_REPORT.
