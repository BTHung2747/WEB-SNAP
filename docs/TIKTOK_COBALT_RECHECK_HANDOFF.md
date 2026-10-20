# Cobalt TikTok — bàn giao lượt kiểm lại 08/10/2026

Hai điểm audit đã sửa và kiểm offline đúng bản mã. Một lượt nguồn mới **metadata FAIL**, nên dừng trước tải. Không có MP4, fileSHA, ffprobe, giải mã, hình/tiếng hay đánh giá watermark mới. TikTok vẫn **0/3 mẫu được nghiệm thu**, chưa bật main hoặc deploy.

## Mã và thư viện

Giữ nguyên Cobalt commit `a636575b09de1fc55d9b8cd98cac88f5f2f16b42`, resolver và helpers, upstream originals, LICENSE/credit AGPL-3.0, cùng năm dependencies khóa SRI. Không viết lại parser/HTTP/cookie/downloader. NOTICE thêm mô tả sửa trong lượt này. Bàn giao cũ `TIKTOK_COBALT_HANDOFF.md` và toàn bộ evidence cũ được giữ nguyên; tài liệu này là successor.

- `run.ps1`, `hash_gate.ps1`: bỏ gate nhận PASS của offline-3 cũ. Receipt mới chỉ sinh sau test exit0, actual container exit/OOM và cleanup đạt, host hashes trước/sau giống nhau, package/lock trong image khớp host. Live kiểm receipt, hash raw offline và fingerprint **23 file** source/config/runner/package-lock. Không có receipt mới hoặc thay source/lock/image thì từ chối trước nguồn; không tái sử dụng evidence directory.
- `runtime_inventory.py`, `supervise.py`: Python hashlib đọc streaming và kiểm chính **15 file source bind mount + 1.271 file dependencies/binaries** đang chạy. Bao gồm npm trong `/opt/cobalt`, yt-dlp, Node/Python/FFmpeg/ffprobe và package trong `/lab`. Live so với inventory offline trước khi gọi Node; image immutable/rootfs RO và source RO giữ nguyên. Hai inventory thực tế khớp byte/hash, SHA `0f72832d69b943c887207827e7a747f9c5bfccb7215e0d689391f85420d101f1`.
- `transport.mjs`, `redact.ps1` (được run.ps1 gọi), `download.py`: log thay **toàn bộ URL** bằng `[url-redacted]`, không giữ pathname/query/userinfo/fragment. Áp dụng cả argv, inspect/guard và Compose render; kiểm guard dùng dữ liệu thật trong RAM trước sanitize. Header cookie/auth cũng che. Metadata chỉ lưu status, marker, byte và header an toàn; private cookie/URL/HTML không xuất log.
- `test.mjs`, `test_all.py`, `test_gate.ps1`: thêm cap thật 8/16 MiB, mismatch host/runtime source và dependencies, fake token path+query, gọi đúng hàm safe của downloader bằng AST, watchdog OS đúng 30s. Không thêm dependencies hoặc rebuild.

API đã đối chiếu: [Undici ProxyAgent 6.24.1](https://github.com/nodejs/undici/blob/v6.24.1/docs/docs/api/ProxyAgent.md), [Python 3.11 subprocess](https://docs.python.org/3.11/library/subprocess.html), [PowerShell Get-FileHash](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/get-filehash?view=powershell-7.5). Dùng API có sẵn cho SHA, process timeout và HTTP; phần tự nối chỉ là receipt/so sánh hash, budget/redaction và contract lab. Deadline cũ của supervisor giữ 30s metadata/180s prepare, ngoài event loop Node; Node AbortSignal28s là phụ. Lượt mới không thay API yt-dlp2026.08.19/private formatter SHA hoặc FFmpeg5.1.9.

## Lệnh và kết quả thực

Runtime duy nhất vẫn image `sha256:5fcc01bb22ca5a264327f4bce4140b07c70d22b0a861ef41ff982d7d0fb3f3a6`. Không build/install/browser. Offline network-none 256MiB; nguồn resolver512 + egress96 = **608MiB**, tuần tự. Actual guard: UID1000/65534, rootfs/source RO, private IPC/PID, capdropALL/no-new-privileges/default seccomp, không ports, proxy SSRF own internal/outbound networks và TLS verify. Egress vẫn image `8bc0a567…7f10`; không sửa production hoặc host.

```powershell
cd 'D:\WED SNAP'
$pwshCobalt = 'C:\Users\LENOVO\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe'
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/test_gate.ps1
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/run.ps1 -Stage offline -FixtureAttempt 1
# Docker pipe bị sandbox từ chối trước create; evidence giữ, chạy với quyền Docker:
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/run.ps1 -Stage offline -FixtureAttempt 2
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/run.ps1 -Stage live -Sample 1 -FixtureAttempt 2
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/verify_recheck.ps1 -Capture
& $pwshCobalt -NoProfile -File labs/tiktok/cobalt/verify_recheck.ps1
```

Đây là lệnh đã chạy, không yêu cầu chạy lại. Runner từ chối directory đã có. Preflight đầu lỗi parser do `Clean` trùng keyword PowerShell7 khi gọi ở đầu statement; sửa bằng call operator, trước container/source. Test host riêng exit0. Offline-1 mới bị Docker npipe permission denied/outer shell1 trước create, chưa chạy fixture; không phải metadata FAIL hoặc test cap FAIL. Không sửa raw đó. Quyền thực thi Docker được cấp để offline-2 chạy; không hạ bảo vệ container.

| Lượt mới | Quan sát và actual exit |
|---|---|
| Offline-2 | 7 Node cases + Python runtime hash/redaction/watchdog đạt; host gate suite đạt; runner/container exit0. Busy-loop Node bị SIGKILL9/child exit−9 sau **30,027393s**, timeout cấu hình30s; chênh27ms là thời gian quan sát sau kill, không ghi thành chính xác30,000s. Native attach UTC07/10 18:40:19.442–18:40:52.236, VN08/10 01:40:19.442–01:40:52.236. |
| Live sample1 | Một analyze; metadata worker exit20, không timeout, **0,694809s**; body/parser0,387952s. Docker native attach exit20, UTC07/10 18:41:34.375–18:41:36.232, VN08/10 01:41:34.375–01:41:36.232. Shell công cụ bọc lệnh trả1 do native nonzero; không nhầm shell1 với worker/container20. |
| File/visual | NOT_RUN: metadata thất bại nên download0, không CDN request/file/ffprobe/decode/visual/audio/watermark. |
| Samples2/3 | NOT_RUN theo điều kiện mẫu đầu chưa đạt; không ảnh được tính video. |

Target được giao: videoID **7692808825228807442**, username input đã xác nhận `nxheitd.vln`. Resolver Cobalt giữ canonical **@i/video/{postId}**; @i không phải tác giả thực đã xác minh. Trace có đúng một GET, không redirect. URL thật đã che; target liên kết với input/command và hash resolver, không lưu signed URL. Không claim đã lấy/khớp metadata video vì parser chưa trả metadata.

Nguồn trả **HTTP200, Content-Type text/html, Content-Encoding br, Content-Length686 nén; thực đọc 1.462 byte giải nén**. Rehydration=false, maintenance=false, captcha-marker=false. Cobalt parser trả `fetch.fail`, wrapper `Error: COBALT_fetch.fail`. Byte dưới8MiB/response và16MiB tổng. Không còn lỗi treo ở lượt này; không có đủ bằng chứng kết luận IP bị chặn, captcha không tồn tại, lỗi mạng/TLS hay response chứa loại nội dung gì. Marker false không phải xác nhận toàn bộ trang không challenge. Không giữ full HTML để suy luận thêm, không retry hoặc chuyển browser/chroot.

## Bằng chứng, cleanup và bước tiếp

Evidence mới: `docs/evidence/tiktok-cobalt-recheck-20261008/`; receipt, runtime inventory, native JSONL UTC/VN, guards, result/metadata sanitize, baseline và successor đều riêng. Offline dọn1container/0network; live dọn2containers/2networks qua exact IDs + run labels; final0left. Preflight/Docker-denied không tạo tài nguyên; lần truy cập Docker thành công xác nhận không có lab cũ sót. Không prune/down-v hoặc xóa cache image.

Giữ manifest cũ SHA `17472fcf1a8534c7abe1506d255a0026aa03a11ce3999a4891e40b0b8a6623d3`, raw sample-1/offline-3 và verifier golden nguyên bản. Trong87artifact cũ, baseline trước sửa chỉ AUDIT khác golden do đợt audit vừa được giao; successor ghi **old golden → audit-before → audit-after** chính xác, cộng đúng7file glue và4statusdocs thay trong lượt này. Trước phiên1.996file; verifier bảo toàn toàn bộ phần ngoài phạm vi, original Cobalt/license/locks/image và history19–37.4-R/archive giữ SHA. Không chạy lại test lịch sử không liên quan; không sửa golden để ép PASS.

Hai finding hash gate/redaction đã đóng ở phạm vi offline + live hash match; nguồn thật **chưa đạt P0**. Bước tiếp chỉ là nghiên cứu/đối chiếu hẹp response và yêu cầu đầu vào của resolver ở commit đã ghim, nếu được giao; bằng chứng hiện tại chưa cho phép chọn nguyên nhân mạng/challenge. Không tự chạy thêm request hay tích hợp apps/media/API. Metadata hoặc một file đạt sau này cũng chưa nghiệm thu ba mẫu/no-button E2E/mọi link.
