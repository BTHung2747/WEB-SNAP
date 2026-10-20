# Bàn giao37.3 — 07/10/2026, chờ kiểm toán

Đã thực hiện5bước37.3 trong phạm vi image lab + metadata. **A FAIL, B FAIL; dừng sau đúng2analyze.** Có đối chứng capability/handler thực khác nhau, chưa có metadata/formats, tệp tải, visual hay E2E. TikTok vẫn chưa nghiệm thu và không bật trên main. Phép đo này không cô lập riêng TLS, không chứng minh chặn IP hoặc rằng curl_cffi không có tác dụng.

## 1. Bảo toàn và phạm vi sửa

Đã đọc AGENTS, PLAN, kết luận audit07/10/chỉ thị37.3 và các cập nhật PROGRESS/ADAPTERS/TEST_REPORT. `docs/evidence/p37-3-20261007/before-all-sha.json` chốt1.485file trước sửa; copies10file liên quan ở `before/`. Toàn bộ24artifacts review37.2 khớp SHA/bytes trước chạy. Kiểm cuối bằng `tests/p37/verify-373.ps1`: chỉ4docs được giao có thể đổi trong tập before; các raw/manifest cũ và source/config production phải khớp từng SHA, không nới historical verifier. Không sao chép nội dung secret `.env`; không thao tác main settings/data/stack. Không có Git repository ở thư mục này, không tạo commit/PR.

Chỉ thêm runner/Compose/probe/cap/fixture/build/lock lab373, gói evidence mới và tài liệu này; cập nhật4docs. Giữ nguyên `run-372.ps1`, `probe_ab.py`, `lab372.py`, Compose372 và proposal/lock372. Không sửa production adapter, lifecycle/API/UI/schema/dependency production hoặc kế hoạch gốc. Source thực chạy A/B được copy/hash vào `executed-source/` trước sửa diagnostic; source final khác ở instrumentation hậu đọc và tùy chọn chỉ chạy fixture.

## 2. Thư viện, API và image đã kiểm thật

Ưu tiên yt-dlp đang có. Extra `pin-curl-cffi` của [yt-dlp2026.08.19](https://github.com/yt-dlp/yt-dlp/blob/2026.08.19/pyproject.toml) ghim curl-cffi0.16.0/cffi2.1.1/pycparser3.0/certifi2026.7.22; base đã có certifi đúng pin. [_curlcffi.py đúng tag](https://github.com/yt-dlp/yt-dlp/blob/2026.08.19/yt_dlp/networking/_curlcffi.py) nhận0.16.x và ghi target vào response.extensions. [RequestDirector](https://github.com/yt-dlp/yt-dlp/blob/2026.08.19/yt_dlp/networking/common.py) dispatch qua handler.send(request); [TikTok extractor](https://github.com/yt-dlp/yt-dlp/blob/2026.08.19/yt_dlp/extractor/tiktok.py) tự truyền impersonate=True. Lab chỉ bọc dispatch/read để thu bằng chứng, vẫn gọi API extractor/transport gốc; không viết transport, parser TikTok hay resolver thay thế.

Metadata PyPI chính thức và source tag được lưu ở `upstream/`. curl-cffi yêu cầuPython≥3.10/cffi≥2/certifi≥2024.2.2, cffi cầnpycparser; Linux x86_64 CPython3.11.2/glibc2.36 đáp ứng wheel cp310-abi3/cp311/manylinux2.17. Wheel curl-cffi phát hành01/08/2026, cffi03/08/2026, pycparser21/01/2026: có release gần đây và phù hợp pin đang dùng, không chọn theo số sao. License trong metadata: curl-cffi MIT, cffi MIT-0, pycparser BSD-3-Clause. [curl-cffi0.16.0](https://pypi.org/project/curl-cffi/0.16.0/), [cffi2.1.1](https://pypi.org/project/cffi/2.1.1/), [pycparser3.0](https://pypi.org/project/pycparser/3.0/). Không coi metadata license/hash hay pip check là kiểm toán toàn bộ mã native/CVE; đây là image lab cô lập, vẫn kiểm chứng import và request thật. Không tích hợp Cobalt/DouK hoặc dịch vụ ngoài.

| Wheel | SHA256 xác minh trước và sau tải |
|---|---|
| curl_cffi-0.16.0-cp310-abi3-manylinux2014_x86_64.manylinux_2_17_x86_64.whl | `182416f07d71a342240554fa62c22e591999b78c225b21d3fe27d9f807420dd6` |
| cffi-2.1.1-cp311-cp311-manylinux2014_x86_64.manylinux_2_17_x86_64.whl | `34e261f78cb6ceaaa36f42f2613f4380d94d9c759a9c73c769ee6e0247364632` |
| pycparser-3.0-py3-none-any.whl | `b727414169a36b7d524c1c3e31839a521725078d7b2ff038656844266160a992` |

Build đúng1image từ cached base, context nhỏ chứa3wheel đã hash; pip `--no-index --only-binary=:all: --require-hashes`, build `--network=none --pull=false`. Không sdist/compiler/apt hoặc upgrade yt-dlp. `pip check` exit0; base layer prefix giữ nguyên. Runtime inventory A/B chứng minh chỉ thêm3distribution, mọi version cũ giữ nguyên;3source yt-dlp đã cài khớp exactSHA source chính thức ở cảA/B. Không nâng suy luận local imageID thành registry digest.

- A/base: `sha256:ecb3e7477d301d766046b92c586604a5650e22a0bac8e675b45699784f65737b`, tag `wed-snap-media:2026.08.19`.
- B/lab: `sha256:c66f52eace47d01e59a54c4b37f2d4d3db8b65326abff670b3673cb7d8900d8f`, tag `wed-snap-media-curlcffi-lab:373-20261007`.
- Egress: `sha256:8bc0a567955111ea3cfbab2dd3b14f40a602f2d10ac987e78eb465f9d48d7f10`.
- Capability offline: A targets0, B targets37/import curl_cffi0.16.0/CurlCFFI handler; chọn B `chrome-136:macos-15` có trong list thực.

## 3. Guard và request thực

Lab373 đúng2services, tuần tự A→gỡ A→B. Probe384MiB/0.75CPU/PIDs64, egress96MiB/0.25CPU/PIDs64; memory-swap bằng memory, tổng giới hạn480MiB. Actual inspect trước start có imageID/user/command/entrypoint/env/mount/network/run-label/resource; lưu đầy đủ `guard-*.json` cạnh resolvedCompose, ngoài phần output rút gọn trong runner log. Probe private network internal; egress có thêm outbound. Giữ egress allowlist/DNS/public-IP/connect-validated-IP hiện hành; redirect bên trong handler phải qua CONNECT proxy. Khôngports/DB/main.env/mainmount; sourceRO/rootfsRO/privatePID/capdropALL/no-new-privileges/nonprivileged. Cookie jar mới độc lập mỗi container; không nhận cookie tài khoản. Giới hạn8MiB/response,16MiBaggregate và alarm tổng30s; khôngprefetch/outerretry/canonical giả. Những request HEAD/GET dưới là extractor tự gọi trong một analyze.

Source upstream có solverJS khi thiếu rehydration. Lab chặn method solver trong process riêng và trả lỗi có nhãn, áp dụng cảA/B; không sửa installed/production source. `solver_blocked=true` chỉ chứng minh method bị chặn, **không chứng minh trang có challenge**. Header default của yt-dlp có UA ngẫu nhiên: effective_options A ghiChrome145, B ghiChrome150; cùng bộ options đầu vào trừ B.impersonate, nhưng effective header này không hoàn toàn được kiểm soát. Header trên wire do impersonation còn có thể khác. Không suy đây là đối chứng TLS đơn biến.

| Nhánh | Thời gian thực UTC / VN(+7) | Request/target/response quan sát được | Metadata / exits |
|---|---|---|---|
| A | 06:50:23.416634–06:50:33.810732 / 13:50:23.416634–13:50:33.810732;10.394s | HEAD link gốc, handler `requests`; read timeout10s. Không response/status/finalURL/contentID/target quan sát được;0byte đọc | FAIL; harness COMPLETED; docker start/container exit20 |
| B | 06:50:45.339839–06:50:46.684013 / 13:50:45.339839–13:50:46.684013;1.344s | HEAD handler `curl_cffi`, target extension `chrome-136:macos-15`, finalHTTP200/gzip/content-length0; redirect final `https://www.tiktok.com/@nxheitd.vln/video/7692808825228807442` (query che). GET cùng handler, target extension **`chrome-146:macos-26`**, HTTP200/text-html/br/content-length688; aggregate1.462decoded byte | FAIL; không parsed rehydration metadata; solver không chạy; harness COMPLETED; docker start/container exit20 |

GET B target khác target yêu cầu: extractor truyền impersonate=True và library chọn target thực. Ghi theo response.extensions, không báo cố định136 hoặc suy từ lớp response. Resolve B xác minh contentID7692808825228807442/typevideo; không mượn contentID lịch sử cho A. Chỉ có finalURL và quan hệ short→final qua handler; intermediate redirect status/hops bên trong handler không expose nên không bịa301/chain.

**Giới hạn diagnostic của raw B:** aggregate1.462byte hợp lệ nhưng trường decoded_bytes0 và markerfalse của GET bị callbackclose chốt trước khi underlyingread trả dữ liệu. Không dùng các giá trị đó để khẳng định maintenance/captcha/không cóJSON trong HTML. Chỉ biết extractor không parse được rehydration và nhận HTML nhỏ; body không lưu nên không thể tái phân loại offline. HTTP Content-Length688 là header của response br, không tự coi là số byte đọc trên wire. Không khẳng định lỗiIP/UA, nội dung bị xóa hay cần login.

ProcesspeakRSS A55.396KiB/B64.584KiB (Linux rusage, không phải tổngcontainer/cgrouppeak); egress dockerstats sau mỗi analyze13.61/13.76MiB. Cgroup limits tổng480MiB mới là trần resource; không dùng RSS+stats khác thời điểm làm peakRAM của toànlab. Runner begin06:50:09.187294UTC, end06:50:59.795303UTC/VN13:50:59.795303; **runner exit20 = BOTH_FAIL**, không cóPASSmetadata vì process chạy xong.

## 4. Fixture và cleanup thực

Offline A/B mỗi lượt:10regressionhelper+6reviewhelper+3fixture instrumentation =19PASS, container/runner exit0; networknone. Các fixture dùng BytesIO và request/handler doubles, khôngbackend/nguồn thật. Sau A/B, bổ sung đúng1fixture autoclose trong underlyingread: baseline3PASS/1FAIL (0!=47byte), containerexit1/runnerexit30, giữrawFAIL. Sửa lab instrumentation refresh sau boundedread, không reread response hay đổi cap/helper. Final4/4PASS/container/runnerexit0; không analyze lại. `diag-before/`, `diag-after/` là offline nhỏ, không một đợt harness tổng quát.

Cleanup từng ID/run-label trước rm; A/B probe được gỡ riêng sau mỗi arm, cuối gỡegress+2networks. `cleanup-verified` chỉ đếm1container ở finally, cộng2probe ở rm-arm-A/B =3containers thực đã tạo/dọn; không báo đếm1 là tổngcoverage. Mọi lượt offline cũng cleanup0resourcesleft. Khôngdown-v/prune/flush/mainreset hoặc xóa evidence. Image B giữ cache có pin cho tái hiện; rollback là gỡ đúng taglab khi có yêu cầu, không cần revertproduction vì không thay. Không thao tác cáclab cũ.

## 5. Lệnh tái hiện và bước sau

Các lệnh dưới **đã chạy phiên này**, PowerShell7 bundled củaCodex; native exits/UTC-VN/stdout-stderr đã sanitize ở `build.jsonl` và từng `runner-*.jsonl`. Lượt read GitHub/Docker ban đầu bị sandbox DNS/npipe từ chối; đã xin đúng escalation kỹ thuật rồi thành công, không coi là nguồnTikTokFAIL. Không dùng stdout thiếu quyền làm capability/cleanupPASS.

```powershell
cd 'D:\WED SNAP'
$pwsh373 = 'C:\Users\LENOVO\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe'
& $pwsh373 -NoProfile -File tests/p37/build-373.ps1
$pin = Get-Content docs/evidence/p37-3-20261007/image-pin.json -Raw | ConvertFrom-Json
& $pwsh373 -NoProfile -File tests/p37/run-373.ps1 -Stage offline -ImageTag $pin.tag -ImageId $pin.image_id -EvidenceDir docs/evidence/p37-3-20261007/offline-B
& $pwsh373 -NoProfile -File tests/p37/run-373.ps1 -Stage offline -EvidenceDir docs/evidence/p37-3-20261007/offline-A
& $pwsh373 -NoProfile -File tests/p37/run-373.ps1 -Stage ab -ImageTag $pin.tag -ImageId $pin.image_id -Target 'chrome-136:macos-15' -EvidenceDir docs/evidence/p37-3-20261007/ab
# Sau A/B: chỉ fixture offline; baseline chạy trước sửa observed_read, final chạy sau sửa.
& $pwsh373 -NoProfile -File tests/p37/run-373.ps1 -Stage offline -InstrumentationOnly -ImageTag $pin.tag -ImageId $pin.image_id -EvidenceDir docs/evidence/p37-3-20261007/diag-before
& $pwsh373 -NoProfile -File tests/p37/run-373.ps1 -Stage offline -InstrumentationOnly -ImageTag $pin.tag -ImageId $pin.image_id -EvidenceDir docs/evidence/p37-3-20261007/diag-after
```

Không chạy lại các tên evidence này: runner/build từ chối directory đã có; baseline diag-before cần source snapshot, source final sẽPASS. Gói `manifest.json` có full distinct path/size/SHA256 của mọi artifact evidence, source/tools373 và4docs+handoff; manifest tựexcluded, hash riêng trong `manifest-sha256.txt` (cũng selfmetadataexcluded). `completion.json` ghi preservation, coverage, actual cleanup và rawexits; verifier chỉ offline file, không rerun19–36.

**Hướng tiếp theo cần phạm vi/quyền riêng:** cùng pinnedimages/yt-dlp/egress/caps/link trên một mạng khác đã có của chủ, đúng2analyze mới, giữ instrumentation autoclose đã sửa và kiểm soát defaultheaders giữa2arms; ghi handler/extensiontarget thực. Không tự chuyển mạng, thuêVPS/proxy, nhậncookie/solver hoặc retry thêm trong37.3. Vì raw hiện không chứng minh HTML chứa metadata, chưa có căn cứ đề xuất resolverCobalt hẹp hoặc tích hợpCobalt. Chỉ khi metadata thành công mới giao bước nguồnplay/download, watermarkprovenance và3file/visual/no-buttonE2E thật. Mục tiêu tải37/P0/P2 chưa đạt.
