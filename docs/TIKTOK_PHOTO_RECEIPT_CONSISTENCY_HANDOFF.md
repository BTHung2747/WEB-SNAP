# Successor receipt consistency — 11/10/2026

**FIXED_OFFLINE_PENDING_INDEPENDENT_REVIEW**. Lab `labs/tiktok/photo-receipt-consistency/`, evidence `docs/evidence/tiktok-photo-receipt-consistency-20261011/`. Chỉ offline; source/InternetDNS/new claim0. Hai finding chưa được đóng bởi review độc lập.

## Mã thay đổi và API

- `receipt_labels.valid(row, stage, file_accepted=False)` từ chối count0 khi metadataPacket/preparePacket khác null (kể cả packet lỗi/rỗng), hoặc file đã qua contract. Typed integer1 và sourceAnalyzeAttempts vẫn theo stage. Không suy invocation từ GET/send counters; count1 có thể bắt đầu nhưng chưa có packet. Count0 không có bằng chứng workflow vẫn hợp lệ. Producer `worker_entry.py` nguyên byte.
- `dns_diagnostic.validate_receipt` tái dùng `valid` nested và nối bốn cặp cùng helper, kiểu chính xác: dnsExit/nativeExit, dnsChildReaped/reaped, dnsPipesClosed/pipesClosed, dnsGroupLeft/groupsLeft. Thiếu/unknown/loại sai/mâu thuẫn cho statusPARTIAL/acceptedfalse với reason cố định. Không xuất giá trị gây lỗi, không sửa raw. Hai elapsed khác thời điểm không ép bằng nhau.
- `finalize.py` truyền file contract evidence vào label gate và bắt buộc các DNS receipt validations accepted. Cleanup code có sẵn giữ: chỉ ảnh không thuộc preexisting bị xóa, ảnh có sẵn và unrelated giữ. Runtime khác/helper/transport/trace/ownership không đổi.
- Runner/source_contract chỉ đổi namespace/inventory successor; source vẫn chặn ở runner và Python. Tái dùng validators dự án + [CPython3.11.2 JSONDecoder](https://raw.githubusercontent.com/python/cpython/v3.11.2/Lib/json/decoder.py) để giữ phân biệt int/float/bool/null, không viết parser hoặc DNS/HTTP mới. Đọc lock hiện có; không thêm deps/build/install.

Pins: image sha256:31742091e95df2cc62669a6c6a9e0892dc09a34341eaeefc16959dcd4dfa417e; Python3.11.2/Requests2.34.2/urllib3-2.8.0/yt-dlp2026.8.19/aiohappyeyeballs2.7.1. LICENSE/NOTICE/lock/vendor lịch sử giữ. Final source384/runtime91/hash **e5512492bb8c1ac4e3b85f9c8078cc4098b526c581b9cc7a6b8840faebfdf641**. Chỉ ba module validator thay hành vi.

## Lệnh thực chạy

Bundled shell `C:\Users\LENOVO\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe -NoProfile -File <script>`, cwd D:\WED SNAP; script dưới trong evidence mới.

| Lệnh | Kết quả thực |
| --- | --- |
| prepare.ps1 | baseline31.191files, successor riêng |
| run-probes.ps1 -Attempt1 | 37ca/native0; UTC14:56:07/VN21:56:07+07 |
| finish-tools.ps1 | verifier/snapshot code-final384files; không sửa runtime |
| run-whole-final.ps1 | 7fresh fixtures1–7, runner0 đúng kỳ vọng; UTC14:58:20/VN21:58:20 |
| run-revalidate.ps1 -Attempt1 | 29copies+12label controls/native0; UTC15:00:49/VN22:00:49 |
| lab/run.ps1 -Stage disabled / source | marker SUCCESSOR_SOURCE_DISABLED_NO_NETWORK/exit20 trước network/claim |
| inspect-final.ps1 | đúng23containers/14networks absent; main image nguyên |
| insert-docs.ps1 | chỉ chèn byte vào AUDIT/PROGRESS, giữ prefix/suffix lịch sử |
| verify.ps1 -Capture; verify.ps1 | fullcoverage manifest và readonly integrity; xem verification-capture.json/verification.json để biết actualexit/checks |

Lệnh kiểm source-block lần đầu bị auto-review từ chối thực thi do hết hạn mức, không có runtime receipt của lần chưa chạy. Sau user tiếp, bộ duyệt cho chạy và cả hai stage reject20. Không bypass approval, không gọi nguồn. `native.jsonl`, state/guard/completion ghi exit thực, UTC/VN và exact IDs. Không sửa hoặc rerun bằng chứng cũ để ép PASS.

## Bằng chứng và giới hạn

37ca kế thừa giữ primary exception identity/whitelist/unknown/malformed/trace failure và helper cleanup. DNS cases FD7→7/thread1→1/helper reaped/pipesclosed/group0/upstreamsocket0; số GET không thành invocation.12label controls gồm source/offline count0/1, packet metadata/prepare và file-only contradiction, requestcount1 nhưng chưa có workflow evidence. Đây là pure synthetic source labels, không mở source.

29validator input copies: ba counterexamples gốc analyze_zero/dns_outer_exit20/dns_outer_not_reaped return20/xóa ownJPEG. Control/elapsed-different return0 giữ ảnh; preexisting-conflict return20 giữ ảnh có sẵn/SHA. Mỗi bốn outerfields có conflict/wrongtype/missing/UNKNOWN; thêm nested missing/unknown/nativebool/malformed/extrafield/missingreaped đều PARTIAL/reject. Other gates file/trace/accounting/operation/batch PASS để cô lập lỗi. keep.bin SHA f630f2c173e4715bcce254c5a166449adc05729c2bcaa6b58f4e2f3b7fc21926 giữ. Các return của finalize.main là function return được harness kiểm; container native0 là kiểm xong, không gọi return20 thành subprocess exit20. Không HTTP/helper/worker mới trong copy tests; private worker observer UID65534 vẫn denied.

Whole normal worker0/proxy0/validator0, metadata2GET+prepare1GET internal. JPEG2170bytes/64×64/4096pixels/1frame/fullDecodePASS, SHA3c94b9a6bbfab0c44c02d0c520dca952e23dc7a396e30a6ef3b0fe00bcc0cc3e. Wrong-body/redirect/health-missing/preexisting worker20/proxy0/validator20; closure-live/missing worker0/proxy0/validator20 và xóa ownJPEG. Expected-negative runner0 là test expectation đạt, không filePASS.

Guards giữ: metadata30/prepare60/connect10/read20 clamp/setup10/end−1reserve; ≤2GETmetadata/conditional1GETJPEG/redirect-retry-HEAD0;8MiBresponse16MiBtotalmetadata/20MiBinput16MiBoutput/workflow36MiB/8192dim16Mpixels/static1frame/fullDecode. PolicyC pair1–2/singleton.60/reap.10/delay.25/interleave0/2socket/4group/prefix8/helper1/answer64/trace256-owner32-map64. Whole512+.75CPU +proxy96+.25CPU =608MiB; validator96 sau khi stop roles; probe512/networknone và revalidation96/networknone. RO/privateIPC/capALL/NNP/pids/user/nohostports giữ; secondary fixture network internal, TLS fixture CA như trước; source trust giữ.

Verifier kiểm baseline, source snapshots/runtime pins, final before/after hash mọi lượt, actual state exit/OOM, physicalimage cleanup/keep/preexistingSHA, exact ownedIDs, claims và fullmanifest. AUDIT/PROGRESS insert giữ nguyên lịch sử. Main image sha256:e7f9357708ac06fab1efbc247ad7a11c8b84d9f549d705ec30e7ce53a6d0184b. Các manifest/verifier/golden cũ giữ nguyên kể cả đang ghim AUDIT trước successor.

Nguồn cũ vẫn metadataFAIL/DNS_HELPER trước TCP, responseCode UNKNOWN_NOT_RETAINED; helperexit0 không DNS PASS. Network/root cause UNKNOWN; chưa ảnh nguồn hoặc gallery/main/API E2E/deploy. Video2/3/mẫu3 NEEDS_VISUAL_REVIEW. Bước tiếp [review độc lập offline](evidence/tiktok-photo-receipt-consistency-20261011/NEXT_PROMPT.md), không được tiêu thụ claim/source mới.
