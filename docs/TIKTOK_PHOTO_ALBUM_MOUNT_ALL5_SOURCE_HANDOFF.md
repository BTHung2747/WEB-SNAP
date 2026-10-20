# Nguồn all5 qua mount-fix — 15/10/2026

**PASS_SOURCE_ALL5_TECHNICAL_NEEDS_VISUAL_REVIEW**. Đúng một workflow đã tải đủ5JPEG thật, ffprobe/full decode/SHA và validator đạt. Chưa human review cho workflow này, chưa nghiệm thu hình/watermark/album tổng thể hoặc main/gallery/API E2E. Raw `contentIdentity=UNKNOWN` giữ nguyên; metadata id/count/key đã đúng không tự thay kết luận visual của raw.

## Quyền và lệnh thực chạy

Human mới call_3bd01f5c55c34e3c8dabdad46b55ca52 được reviewer đối chiếu trực tiếp, ba packet candidate/orchestration/human seal/read-only và WorkflowGates real đạt trước entry. Preflight so exact code/source/runtime/packets/task/quota; không matrix/history/default entry để thăm dò, không sửa code/pins/proposal/human. Lời agent chuyển việc không thay human grant.

- Task6fae7022e9f546cdbc21fc1d4d7caa5c/allocation1adb550d1ef3467f944f3b7b499b511a; proposalbe99e5b05c604ed3b26ec852bd654a5d.
- Actual proposalSHA `d482b22e1d98440a0dfd65f2941d8545394530202eee852afe0b9b860cff3207`; freezeSHA `ae089542fd42dd2e42df491d210859d9573567913b6a546f2175545e3ff7a090`; workflow codeHash `8b5b522aeb99c12d77fe5596ad7e6d5d268ace27555a7a85e9b3a197011133ae`.
- Candidate6dd72e4f1f958f269e803a03d4855f924a0e3a43726dd26ec22ba577eeefc4dd/runtimec000b715baf471373fab65bbd83b30ab9b9b76542d24ef2bfcfa9e000604458b; image31742091…dfa417e/CA9cc2a774…d730f; dependencies/license/locks/reader/downloader/Cobalt nguyênbyte như đã nghiệm thu.
- Candidate/orchestration/human manifest lần lượt952754b9…41831/32a4570b…d8b5f/703d37ff…110e0; human rawSHA18434058…71387/schema2/contentSHA256UTF8/observedUTC. Full hashes ở preflight.json, packet files gốc giữ nguyên.

Lệnh duy nhất: `pwsh -NoProfile -File labs/tiktok/photo-album-mount-workflow/run.ps1 -Mode source`. Entry native0, UTC15/10 `01:17:16.4050444Z`→`01:18:29.5368240Z`, VN `08:17:16`→`08:18:29`, 73,132s host. Cold native/container0, source runner/proxy/worker container/worker child/parent/validator đều0/noOOM; worker signalnull/readerJoinedtrue. Không coi packet PASS đơn lẻ là native0; state/native/validator đã đối chiếu riêng. Raw before/fail histories không sửa hoặc chạy lại.

## Kết quả nguồn, hạn mức thực

Target duy nhất https://www.tiktok.com/@adne_la.veil/photo/7678209751167110421; fresh summary7678209751167110421/count5/key8fa38af83f8dc423d4d78b8044d5d7b26ae3fdef9ec73eab59fe04f8475c2127. Validator admission/files/accounting/httpSuccess/trace/registry/dns đều true. Lỗi mount cũ không tái hiện trong lượt này; native start proxy/worker/validator đã thực chạy. Không khái quát thành nguyên nhân mọi lỗi mạng trước đã sửa.

Request-accounting exact/packet+observer/linkage COMPLETE: **2 metadataGET +5 prepareGET**, observed status `[200,200]` và5×200; không HEAD/redirect/retry/fallback/URL khác. HTTP decompressed input metadata416.091 +JPEG2.029.809 = **2.445.900 byte**; output5JPEG **2.029.809 byte**. Meta7,433s/prepare19,940s/active27,574s. Host73,132s khác active watchdog225; không tuyên bố host E2E225 từ active scope.

Giữ caps2+5GET/meta8–16MiB/JPEG20–16MiB/tổng116–80MiB/meta30/prep180/item60reserve10/connect10/read20/active225; source worker512MiBCPU.75+proxy96MiBCPU.25=608MiB. Cold none96MiBCPU.25/UID65534/rootfsRO/privateIPC/dropALL/NNP/deadline30/lease590. Source SSRF/TLS/CA/defaultseccomp/noports/private worker-network/egress/resources/DNSraw256unique64/policyC/trace256/owner32/map64/IPC giữ. Expiry release bằng cold lease `2026-10-15T01:27:08.4062814Z`, không renew/reset; task/reservation/claim consumed giữ nguyên dù lease hết sau chạy.

Proxy summary final=true/incomplete=false, TCPcoverage COMPLETE3attempt/29operations COMPLETE; owners accepted/closed/workersReturned3, sockets/threads/errors0, helpers/groups0. DNS receipts raw-all validate trước dedup, publicState ALL_ALLOWED/ALLOW, rawCap256/uniqueCap64, helper native0/reaped/pipesClosed/groups0. `perSocketNetworkCause=UNKNOWN` giữ, không bịa tách TCP/CONNECT/TLS ngoài boundary đã đo. `sourceCalls=UNKNOWN_USE_REQUEST_ACCOUNTING` trong wrapper/final raw giữ; số2+5 lấy từ accounting/observer, không sửa nhãn raw.

## File thật và review

| Ảnh | Kích thước | Byte | SHA256 |
|---|---|---:|---|
|1|2132×2132|518342|7fc4899a9e249f93789724dd036852110f360eb570b4b85539fb38ebdde1f0d2|
|2|2132×2132|322655|62308e76366aece0368f8c326f6430669fa4601ff1d963bb99378507091f5a8b|
|3|2132×2132|212626|de61f4d1cc7af992bbf2ded46b09f20a4e34378c6098f62278c5e6a124243dea|
|4|2248×2132|305717|7d1ca150479df7da0f6dc4cfee78952c5b2826aa93a10a9592a27790adb1735a|
|5|2132×2132|670469|ddc88ce0cbb36bf3ac1369e215288d802608a4050ee97866feeb17caed80db2c|

Tất cả JPEG/image/jpeg/1frame, full decode PASS; mỗi file2ffprobe END returncode0 và decode END0. Collector đọc lại actual fileSHA/bytes/magicFFD8FF…FFD9, đối chiếu itemKey/summary/ledger. Files gốc ở `lab-runs/tiktok-photo-album-mount-fix-v1/real/task-registry/task-6fae7022e9f546cdbc21fc1d4d7caa5c/worker/image-0001.jpg`…0005. files.json ghi absolute paths; [IMAGE_REVIEW](evidence/tiktok-photo-album-mount-all5-source-20261015/IMAGE_REVIEW.md) trình ảnh gốc và SHA.

Đã mở đủ5file bằng view_image trong task, preview tool tự giảm kích thước; actualJPEG không chỉnh sửa. Chữ có sẵn hiển thị “You the main attraction”, “Lights”, “Camera”, “Action!!!”, “Ohh la la la~” được giữ. Không crop/blur/transcode/xóa logo. Chưa lấy assistant preview làm human acceptance/watermark PASS. Ảnh1 SHA trùng ảnh1 lịch sử đã human accepted; không áp dụng lời review cũ cho cả5 hoặc ảnh2–5 mới. Current visual-review.json vẫn NEEDS_VISUAL_REVIEW, đợi reviewer trình/ghi xác nhận từng SHA sau kiểm độc lập.

## Cleanup và evidence

Fresh execution6dc3a255322f4ea18fb620381338bfac; explicit workflow task root, core execution root, task-registry root và global reservation file trong namespace-index.json. Không quét base để nhận nhầm scope khác. Bốn own container (cold/proxy/worker/validator) và hai network đã dọn theo ownership; after inventory không còn IDs. Images13/oldcontainers25/volumes35/main giữ, renderer absent. Có một network baseline thay ID ngoài own scope, cause UNKNOWN; không thao tác/prune. Sentinels preserved, files5 giữ nguyên.

Evidence mới `docs/evidence/tiktok-photo-album-mount-all5-source-20261015/`: preflight/before-code/packets/history hashes, entry/native/raw dưới explicit roots, files/accounting/DNS/TCP/cleanup/visual/assessment/docs chain/manifest/seal/read-only. Protected13.768 file trước/sau giữhash; original77/270/84/audit26/human16 coverage được kiểm bằng inventory functions và phục hồi shared docs đúng hash trong bộ nhớ, không chạy assertions lịch sử trước source hoặc sửa golden. AUDIT/PROGRESS insert-only có immediate-before/bytes/SHA.

Task nguồn đã hoàn tất kỹ thuật; chưa toàn bộ nghiệm thu album. Bước tiếp chỉ kiểm độc lập kết quả và human visual từngSHA. Không nguồn mới/cold/claim/retry/reset/renew/main/gallery/API/UI/DB/settings/host/build/pull/install/deploy/video3/prune. Một album năm ảnh không chứng minh mọi album, shortlink API E2E hoặc gallery sản phẩm đã hoạt động.
