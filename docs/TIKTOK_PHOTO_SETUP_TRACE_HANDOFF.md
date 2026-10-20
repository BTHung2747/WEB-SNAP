# Bàn giao trace setup ảnh TikTok — 10/10/2026

Đã bổ sung **lab riêng**, kiểm offline trên bản mã cuối; **không gọi nguồn**. Lỗi tải ảnh lịch sử vẫn chưa xác định bước con gây timeout. Chưa có ảnh nguồn hoặc đánh giá watermark mới; TikTok main OFF, gallery chưa tích hợp, video vẫn 2/3 và mẫu3 NEEDS_VISUAL_REVIEW.

## Mã và API

- `labs/tiktok/setup-trace/egress_trace.py`: bản lab từ `apps/egress/src/egress.py`, giữ allowlist, toàn bộ-answer public-IP guard, DNS order, socket timeout10 từng địa chỉ, CONNECT-only/443, header16KiB, tunnel240s/idle30s và chuyển tiếp TLS opaque. Chỉ bọc lời gọi API công khai bằng observer.
- `trace.py`: context riêng theo handler/opaque connectionID; fixed enums, số, ánh xạ **type lỗi chính xác** sang whitelist; không message/repr/stack. Delegation và bare raise giữ exception object.
- `test_trace.py`: đối chứng stock với traced bằng dependency facade riêng của fixture, và Requests/urllib3 thực qua proxy/HTTPS loopback. Không monkeypatch private library, không viết resolver/HTTP/TLS.
- `run.ps1`: image cache đã ghim, inspect guards trước start; snapshot hash trước và kiểm lại sau test, đối chiếu 23 file core runtime với host; cleanup đúng ID/run label. Runner chỉ có đường offline, không có lệnh nguồn.
- Không thêm dependency/build. Thư viện đã đủ xử lý DNS/socket/TLS/HTTP; chỉ tự viết observer bounded, glue fixture và ownership/hash receipt. Giữ LICENSE/NOTICE/lock của core; các import core AGPL-3.0 không bị chép thành extractor khác.

API xác minh: [Python3.11 socket](https://docs.python.org/3.11/library/socket.html), [socketserver handler](https://docs.python.org/3.11/library/socketserver.html), [socket nguồn v3.11.2](https://raw.githubusercontent.com/python/cpython/v3.11.2/Lib/socket.py), [socketserver v3.11.2](https://github.com/python/cpython/blob/v3.11.2/Lib/socketserver.py); [Requests2.34.2 HTTPAdapter.send](https://github.com/psf/requests/blob/v2.34.2/src/requests/adapters.py), [urllib3-2.8.0 connection](https://urllib3.readthedocs.io/en/2.8.0/reference/urllib3.connection.html)/[ConnectionCls nguồn](https://github.com/urllib3/urllib3/blob/2.8.0/src/urllib3/connectionpool.py). Docs Python3.11 hiện hiển thị patch3.11.17; đối chiếu thêm source tag3.11.2 và SHA installed trong api-runtime.json, không coi trang docs latest là pin mới. Requests docs developer interface hiện ghi đúng2.34.2. Extension client sẵn có được import nguyên trạng, không sửa.

Runtime kiểm thực: Python3.11.2, Requests2.34.2, urllib3-2.8.0, yt-dlp2026.8.19, Brotli1.2.0. Image **sha256:31742091e95df2cc62669a6c6a9e0892dc09a34341eaeefc16959dcd4dfa417e**.

## Ý nghĩa và giới hạn trace

| Boundary | Quan sát trực tiếp | Chưa quan sát |
| --- | --- | --- |
| DNS_LOOKUP | BEGIN, getaddrinfo + public-IP guard END/ERROR; IPv4/IPv6 counts chỉ sau guard PASS | Deadline DNS UNKNOWN: getaddrinfo không nhận timeout; không thêm DNS resolver/deadline |
| UPSTREAM_TCP_CONNECT | từng attempt index/family theo thứ tự stock, socket.gettimeout()10, BEGIN/END/ERROR/elapsed | Không tách syscall/network nội bộ |
| CONNECT_200_SENT | END chỉ sau sendall thành công; ERROR khi send lỗi | Không chứng minh client đã nhận 200 hoặc TLS đạt |
| TUNNEL_CLOSE | END sau close upstream, code fixed; elapsed từ handler bắt đầu tới close | Không phân tích nội dung TLS hay response origin |
| Client CONNECTION_SETUP | observer hiện có đo nhóm setup; REQUEST_SEND/RESPONSE_HEADERS riêng | TLS handshake chi tiết và correlation client↔proxy trên nguồn UNKNOWN |

`deadlineMonotonicSeconds` là mốc tính từ monotonic ngay trước gọi connect cộng **timeout thực trên socket**, không phải deadline OS báo về, không reset/chèn tổng budget mới. BEGIN→END elapsed gồm overhead trace I/O. Trace không được dùng để suy syscall duration chính xác hoặc overhead bằng0.

Trace cap mặc định **256 rows/run và32/connection**; cap hoặc I/O fail đặt incomplete trong RAM và không đổi socket outcome. Khi cap thiếu END, không được suy tunnel đang treo. Fixture ghi nhận saturation/I/O failure; trial tương lai phải thu sink counters/incomplete riêng cuối lượt, fail chẩn đoán nếu thiếu coverage. File trace chỉ fixed fields, mode0600/O_NOFOLLOW. Không ghi host/IP/target/path/query/header/cookie/token/exception text/tunnel payload.

Proxy CID theo từng CONNECT; request thứ hai trên TLS reuse giữ cùng CID. Client observer có requestID riêng; không truyền thêm header chung. Chỉ fixture một tunnel có correlation nhờ topology đã biết; nguồn nhiều tunnel chưa có ID chung và không được ghép chắc chắn bằng timestamp hoặc thứ tự.

## Lệnh thực chạy và kết quả

Từ `D:\WED SNAP` dùng pwsh bundled, tuần tự:

`pwsh -NoProfile -File labs/tiktok/setup-trace/run.ps1`

`pwsh -NoProfile -File labs/tiktok/setup-trace/run.ps1 -Attempt 2`

Hai lượt offline đều native container/test/runner **exit0**, không OOM. offline-1 giữ nguyên; offline-2 kiểm bản cuối có elapsed đóng handler và hash sau lượt, không sửa kết quả cũ. Mỗi lượt **20 nhóm kiểm**, không gọi thành20 mẫu nguồn:

- Stock/traced phản hồi CONNECT và thứ tự/timeouts bằng nhau: success-close; DNSdelay/failure/empty/mixed public+private rejection; TCPdelay/failure; IPv6 attempt1 lỗi rồi IPv4 attempt2 thành công theo fixture; send200 BrokenPipe trước END.
- DNS/TCP/client exception sentinel giữ identity; trace cap và lỗi ghi file không đổi kết quả.
- HTTPS loopback thực qua stock/traced: thành công/reuse hai GET cùng tunnel; TLS certificate failure; TLS stall sau upstream TCP/CONNECT200. Không giảm connect10/read20 cho loopback.
- Token giả trong path/query/cookie/exception chỉ RAM; scan JSONL không có token/host/IP/URL.
- Runtime core23 file khớp host, giữ hai finding F-APP-DURATION-CAP/F-APP-BODY-TIMEOUT-CODE.

TLS stall fixture do origin cố tình không trả TLS: proxy đã gửi200, client CONNECTION_SETUP timeout khoảng10s; Requests phân loại READ_TIMEOUT, boundary TIMEOUT_UNKNOWN. Đây là **minh họa có kiểm soát** rằng tên READ_TIMEOUT không chứng minh chờ HTTP header/read20; không chứng minh nguồn ảnh bị TLS stall. Certificate failure cũng xảy ra sau proxy200 mà TLS không đạt.

Guard kiểm thực: một container **network-none**, TLS loopback nội bộ; user1000:1000, rootfsRO, capdropALL/NNP, privateIPC, RAM/swap512MiB, CPU0,75, pids96, tmp32MiB, source mountsRO/own evidenceRW. Không service egress riêng nên tổng cap512MiB≤608MiB; loopback servers ở cùng container. Không mở cổng host, không nới seccomp/SSRF/TLS. Ca TLS thành công verify cert fixture, ca cert failure dùng trust store và phải FAIL; không verifyFalse.

Watchdog95s chỉ bao toàn suite offline nhiều ca; không thay metadata30s/prepare hay timeout nguồn. Không kiểm lại tải/decode/body caps trong nhiệm vụ trace; mã/core/pins và caps lịch sử được giữ SHA. Fixture facade ánh xạ public stand-in vào loopback chỉ trong test; default proxy vẫn dùng socket/getaddrinfo thật và từ chối non-global answer.

Evidence `docs/evidence/tiktok-photo-setup-trace-20261010/`: baseline3479, before copies, provenance, offline-1/2 native/guard/state/runtime/hash/receipt/trace, inspection, successor/manifest/verifier. Thời gian UTC và VN trong completion/native; cleanup exact own container, không tạo Docker network. Một inspection đọc tag nhầm `wed-snap-media:latest` trả exit1/no such image, đã lưu riêng; kiểm đúng `wed-snap-app:local` sau đó. Không build/install để sửa tên tag.

## Hướng xử lý

Nguồn cũ: metadata5ảnh PASS; image1 body0, CONNECTION_SETUP10,010758s trước REQUEST_SEND/HEADERS. Chưa có proxy trace thời điểm đó. **Root cause UNKNOWN**: DNS, upstream TCP/fallback, CONNECT hoặc TLS đều chưa phân biệt. Stock per-address10 và clientconnect10 có thể làm client hết thời gian trước fallback; fixture chứng minh observer nhìn thấy từng attempt, chưa chứng minh khả năng này đã xảy ra ở nguồn.

Một nhiệm vụ nguồn riêng có thể wire bản proxy lab vào own-egress96MiB (Python cache), workerphoto512MiB, mounted trace owned/nonprivileged; kiểm offline mới đúng **toàn bộ wiring/hash** trước mở nguồn. Không dùng receipt standalone này thay offline integration gate.

Proposal tối thiểu chưa thực hiện: đúng bài7678209751167110421, analyze1/≤2GETmetadata/30s/decoded8MiB mỗi response16MiB tổng; chỉ bodyID/typephoto/entry1 hợp lệ mới conditional1GETảnh1/60s/input20MiB/output16MiB; redirect/retry/HEAD0, không album/ảnh2/audio. Cookie/signedURL chỉRAM, metadata/file exit0 riêng; GET chỉ qua own-egress SSRF/TLS; total608MiB và proxy/client timeouts giữ. Thu proxy counts/incomplete cùng client boundaries, native exits/cleanup/fullcoverage, không correlation chắc chắn khi thiếu ID chung.

Nếu proxy DNS/TCP lỗi trước200: chỉ báo chặng và attempt quan sát được. Nếu proxy200 rồi clientsetup lỗi: báo sau proxy200, TLS chi tiết UNKNOWN. Nếu thiếu trace/cap/hash: dừng chẩn đoán. Không tăng timeout/ưu tiênIPv4/đổiDNS/host/TLS theo đoán. Tệp đạt mới kiểm JPEG thật/magic/dimensions/full decode/SHA và review trước nghiệm thu ảnh. Nhiệm vụ này **source0/deploy0**, chưa mở trial trên.

