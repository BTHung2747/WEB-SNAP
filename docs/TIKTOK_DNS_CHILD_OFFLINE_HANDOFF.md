# DNS child source wiring — offline15/10/2026

**PASS_OFFLINE_DNS_CHILD_FIX_PENDING_REVIEW**. Đã chứng minh một lỗi tích hợp cục bộ, sửa tối thiểu trong successorlab và kiểm đối chứng. SourceRequestsNew=0/sourceGrantNew=false; không ExecuteSource, publicDNS/TikTok/CDN/externalbridge/Attempt2/retry/main/gallery/deploy. Kết quả nguồn trước vẫn FAIL_STOPPED_AT_ANALYZE_NO_FILE.

## Kết quả đo thật

Cachedproxy `sha256:8bc0a567955111ea3cfbab2dd3b14f40a602f2d10ac987e78eb465f9d48d7f10`, interpreter `/usr/local/bin/python`, CPython3.12.12/cwd/app. Baseline khôngPYTHONPATH, parent-I thêm sys.path source/vendor như source_entry cũ. Parent thật import `/repo/apps/egress/src/tiktok_policy/dns_ipc.py` SHA `0f45720271c4d057c42eea953b3a5007af5f47f9974db9ff586714e8762386d5` và dns_helper SHA `5ed38c98b9e52f4e1f05ca560965d5e081505c1de9a245757017707572859487`.

Child public subprocess dùng cùnginterpreter/cwd/inheritedenv, `-c` import-probe để quan sát cùng quy tắc searchcwd của `-m`: **không tìm thấy tiktok_policy hoặc aiohappyeyeballs**, import-probeexit21. Chạy đúng `python -m tiktok_policy.dns_helper` với JSON rỗng `{}`: actualexit1/response0. Lỗi xảy ra trước xử lý input/DNS. Không phải cachedpolicy khác: tại searchpath này package thiếu. Baseline2 còn gọi production Request.connect với hostname rỗng, actual dns_ipc spawn helperexit1/reapedtrue/pipesclosed/groups0/response0; ownedprojection ghi DNS_HELPER ERROR. Đây là probe local/invalidinput, không sourceGET hoặc publicDNS/socketconnect.

**Confirmed:** cấu hình source cha–con cũ không truyền module searchpath cho child và child không import được package trong đúng cache/cwd/env đã đo. **Giới hạn:** source-1 lịch sử không lưu childnativeexit/modulepath; không thể gọi phép đo mới là quan sát trực tiếp nguyên nhân duy nhất của lượt13:37. Lỗi tích hợp tái hiện đủ căn cứ sửa trước mọi lượt nguồn khác; chưa chứng minh mạng/TikTok bị chặn hoặc hết lỗi mạng sau sửa.

## Sửa tối thiểu, tái dùng API

Successor `labs/tiktok/photo-dns-child-offline/`30file riêng;25tool cũ/apps128/source-1/history nguyênbyte. `common/dns_child_environment.py.configure()` chỉ đặt PYTHONPATH đúng hai readonly source/vendor mounts. Source proxy_entry gọi hàm trước import egress; parent-I vẫn explicitpath, production Popen child không-I thừa kế env này. Không sửa production dns_ipc, parser/transport/DNSengine/SSRF/TLS/locks/deps/image/host. Vì CPython sys.path của parent không tự truyền qua exec, cần glue env công khai; không private monkeypatch.

Corrected2 gọi **cùng configure()** trong parent probe. Child6module đều import từ source/vendor đúngSHA: tiktok_policy/package, dns_helper, dns_ipc, dns_admission, runtime và aiohappyeyeballs; probeexit0. Native-m với `{}` exit20/response0: helper mới từ chối schema trước DNS, **không coi20 là DNS thành công**. OwnedRequest hostname rỗng exit20/reapedtrue/groups0/pipesclosed. Negative1 đặt path không tồn tại → import21/helper1/ownedfailureclosed, không silentlyfallback. Native failure numbers được ghi từ returncode thật, không dùng fixturePASS thay.

CPython3.12.12 docs/source chính thức về subprocess/envinherit/PYTHONPATH/-I/-m được đối chiếu trong API_REFERENCES.md. Không cài thư viện; tái dùng WED Trace/Request/dns_ipc/Broker và validator admission public sẵn có. Import-only không là DNS/networkPASS. Probe không mount /offline/sitecustomize/fakeDNS/CA; controlsecret phiên nguồn không mang vào probe vì không cần đo import. Direct ownedRequest unit dùng socketpair nội bộ và cờ complete(True) fixture để kiểm projection của failure, không chứng minh threadbarrier/serverproof; commonflow bên dưới kiểm actualserverclosure/gate riêng.

## Collector mới và ca lỗi

`common/proxy_collect.py`: projection sau actualownedctx complete/result, lưu DNSchildexit/reap/pipes/groups/input-responsebytes, admission finite-schema/reason/counts từ stats_valid, validationreason finiteenum và selectednumericboundaries. Chỉ opaqueownerID/phase/finiteenum/số/bool; không hostname/IP/answerrows/URLpathquery/header/HTML/cookie/secret/token/nonce/cap/epoch/binding/message/repr/stack. ≤64connections,≤128trace rows/connection,≤32KiB/row và≤512KiB tổngfile. Missing/unsupported→UNKNOWN/diagnosticCompletefalse/traceincomplete, không giả0 hoặc PASS. Diagnosticpartial không đổi lỗi trước đó thành thành công.

Collector fault đánh dấu evidence incomplete, **vẫn gọi original Broker.finish đúng một lần** để không bỏ ownership completion; không sửa gate/brokerdecision hoặc thay physicalcleanup. Bảy ca hẹp mỗi mode: actualownedinvalidinputfailure; delegate realbroker; missingfields; injectionfakepath/query/host/IP/cookie/message; unsupportedcode; sinkfailure delegateidentity+count/closed sockets; trace129 cap. Raw failurediagnostics vẫn giữ native1/20 dù gate phảiFAIL. Sinkfailure fixture không là actualbroker closureproof.

## Lệnh đã chạy

```powershell
& ./labs/tiktok/photo-dns-child-offline/probe.ps1 -Mode baseline -Attempt 2
& ./labs/tiktok/photo-dns-child-offline/probe.ps1 -Mode corrected -Attempt 2
& ./labs/tiktok/photo-dns-child-offline/probe.ps1 -Mode negative -Attempt 1
& ./labs/tiktok/photo-dns-child-offline/run.ps1 -Mode offline -Attempt 1
& ./labs/tiktok/photo-dns-child-offline/run.ps1 -Mode source
```

Ba probe và wholeoffline nativeCLI0; probeexpectedchildfailed1/20 khác suiteexit0. Cuốisource thiếu switch exit78/noattemptdir; successor offline task khóa Mode source ngayđầu dù không phụ thuộc grant cũ. Baseline1/corrected1 exploratory giữ; finalbaseline2/corrected2/negative1/offline1 cùng30toolhash. Không chạy lại ma trận10/6/14/3, khôngbuild/pull/install. Entry imports mode kế thừa không chạy/không làm gate nhiệm vụ này; actual module gate là childprobe nêu trên.

Wholefixture chỉ2ca dùng actual API/BullMQ/processJob/parent/ProcessGroup/gate3b/photo core/Requests/Cobalt/FFmpeg: happy jobe0103885-e4d5-41d3-bdc5-761585b8d2b5,2childnative0/group0→prooftrue→release;2+2+1attempts, JPEG248B SHA `45cea83ba1889b4f948c9fca05932a47ff2bb92723dd8fa798fcf14149c51e00`,2ffprobe0/fullDecode0/nativeHEAD-no-lease/GET/Range206. Baactualproxycompletionrows diagnosticComplete/acceptedtrue/DNSexit0/reaped/groups0/admissionOK,24boundaries mỗirow. Missingproof ca thứhai native0 nhưng gatefalse/failed/no prepare. Fixture6metadata+1JPEG, nguồn0; wireGETUNKNOWN không cộng CONNECT/attempt. FixtureDNS/CA/TCPmapping tách /offline rõ, không dùng chứng minh sourcechild path.

Probe96MiB/CPU.25/PIDs96/user65534/networknone/RO/dropALL/NNP/privateIPC/noextraswap/noports/timeout25; childinvocationtimeout8. Cgroup và timeout vẫn giữ, không tăng để épPASS. Whole800MiB512/96/128/64/guards/internal/noports; metadata30/prepare180/HTTP10–20/whole250/cleanup20/watchdog360 và byte/DNSraw256→unique64 giữ. Native app0/API143stop/proxy0/consumer0/noOOM; own4container+1network removed/cleanup2.5178217s. Probesowncontainerremoved/left0/netcreated0; measuredcaps không peakRSS.

Evidence `docs/evidence/tiktok-dns-child-offline-20261015/`: exactsource/tool hashes+snapshots/rawnative/guards/cleanup/readonlyverifier/manifest; oldfrozen/source-1 checksum nguyênbyte. AUDIT/PROGRESS prepend nối cả dispatchoffline và UIbrief phát sinh song song, không overwrite nội dung hoặc sửa golden. Chờ kiểm độc lập; chưa có quyền nguồn mới, không xin/thử nguồn chỉ vì offlinePASS.
