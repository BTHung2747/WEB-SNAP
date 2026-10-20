# Diagnostic completeness P2 — successor offline15/10/2026

**PASS_PURE_DIAGNOSTIC_COMPLETENESS_FIX_PENDING_REVIEW**. Bốn ca reviewer nêu đã hết false-complete. Chỉ3file trong `labs/tiktok/photo-dns-diagnostics-fix/`: projection sửa, overlayentry mỏng và unitfixture. Giữ30tool lab DNSchild cũ/25oldtools/apps128/source-1/evidence/golden nguyênbyte. Không Docker/wholeworkflow/DNS/socket/source/build/pull/install/main/deploy trong lượt này; sourceGrantNew=false/sourceRequestsNew=0. Kết quả nguồn lịch sử vẫnFAIL_NO_FILE.

## Sửa gì

Tái dùng stdlib type/enum checks và `stats_valid`, PAIRED/SNAPSHOTS của module WED đã ghim. Không thêm schema library hoặc viết lại validatorDNS/Broker/gate. Bản copy một module `proxy_collect.py` là overlay cần thiết vì project() hiện được install() gọi qua moduleglobal; không sửa global của module frozen hoặc sao toàn bộ lab.

Closure `workerThreadClosed/clientClosed/loopClosed`, accepted và traceIncomplete chỉ là known khi **type(value) is bool**. False thật giữ False; thiếu/sai kiểu thành UNKNOWN và diagnosticCompletefalse. Thêm loopClosed vào projection lab để không bỏ chứng cứ closure có trong actualresult; không đổi API/DB/schema ứng dụng. diagnosticComplete là đầy đủ dữ liệu quan sát, không đồng nghĩa các closure đềutrue hoặc sourceđạt. TraceIncomplete true vẫnknown nhưng diagnosticCompletefalse.

Phase/owner/traceowner/event/code/elapsed không hợp lệ được chuẩn hóa UNKNOWN và góp vào completenessfalse. DNS/registry có opaqueowner hợp lệ khác ctx.cid vẫn giữ; không ép ownercon bằng ownercha. OperationIndex của PAIRED cần int1–64 theo contract sẵn; bool không nhận thay count/int, numeric/booleanfield sai kiểu là UNKNOWN/incomplete. DNSnumeric/bool/admission/responseCode/reasonCodes giữ whitelist/caps; dictcontainer sai kiểu được xử lý thiếu bằng chứng, không đọc tự do hoặc ghi message.

install() và policy Broker/gate không sửa. Projection/sinkfailure vẫn marktraceincomplete, **originaldelegate một lần với cùng ctx/result và đúng returnidentity**; không lấy diagnosticComplete làm proof thay Broker. Thử cap65 vẫn65delegatecalls, file tốiđa64record và512KiB; một connection không sinh lời gọi delegate thứhai.

## Kiểm thực và giới hạn

Bundled CPython3.12.14 đã có sẵn, `-I -B`, timeout ngoài30s; khác cachedproxy3.12.12 đã kiểm lịch sử. Chỉ type/importlib/JSON/WED purefunctions, không probe interpreterDocker vì không đổi startup/DNS và TASK ưu tiên unitnhẹ. CPython officialtag3.12.14 type/importlib APIs được đối chiếu; runtime/libraryproduction không nâng phiên bản.

Lệnh thực chạy cuối:

```powershell
& ./docs/evidence/tiktok-dns-diagnostics-fix-20261015/run-unit.ps1 -Attempt 2
& 'C:/Users/LENOVO/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -I -B labs/tiktok/photo-dns-diagnostics-fix/overlay_entry.py
```

Unit nativeexit0/0.2416117s/khôngtimeout/stderrempty,89projectioncases+5delegatecases. Bốn reviewerreproductions oldComplete=true→newComplete=false/newValueUNKNOWN; happy frozen record và ownercon hợp lệ giữcomplete. Các booleanfalse đãbiết giữfalse/complete, traceIncomplete true giữtrue/incomplete. Thiếu/sai kiểu closure, top/traceowner/phase/enum/elapsed/DNS/pairedindex/malformedcontainer, trace129, privacyfakeURLpathquery/IP/host/cookie/message đều đạt. Sinkfailure/invalidprojection/missingclosure/cap65 delegateidentity/count đúng; normalrecord không markincomplete. Inputfrozen SHA `566f2a707fcb114767e00e7f1bcdccb239759b8198ab07d5283152cfb9afb69d` không mutate.

Unit1(87case) trước bổ sung2case liên quan giữ làm intermediate; unit2 mới là gate cuối cùng3toolhash. Native overlayentry thiếu flag exit78 trước bind/startup; sourceExecutionStartedfalse. `overlay_entry.bind()` thực import projection từ successor và proxy_entry từ frozencommon, kiểm actual__file__; unitkhông chạy source main hoặc server. Dữ liệu dùng là bản sao actual frozen successful completion, **mutations là fixture**, không DNS/Request/socket/processgroup/file-download mới. Delegate test dùng stub nhận identity, không gọi cleanup runtime. Không suy unitPASS thành nguồn/appE2E/watermark hoặc nhận lại quyền nguồn.

## Overlay dùng fix thế nào ở lab kế tiếp

Không gọi runner cũ rồi mặc định cho rằng đã dùng fix: runner frozen vẫn mount common cũ và không bị sửa. Recipe overlay để một successor runner được giao sau này chọn rõ:

- Mount readonly `labs/tiktok/photo-dns-diagnostics-fix/` → `/lab`.
- Mount readonly `labs/tiktok/photo-dns-child-offline/common/` → `/base`.
- Giữ production source/vendor ở `/repo/apps/egress/...`, owncontrol ở `/control` cùng guards/env/caps đã nghiệm thu.
- Proxy entry là `python -I /lab/overlay_entry.py`. Thiếu flag thực thi vẫn78; lượt này chỉ chạy nhánhdeny. Không dựngcontainer/mạng hoặc setflagnguồn trong nhiệm vụ này.

bind() đưa overlay trước frozencommon, importcanonical `proxy_collect` và xác minh file đúng overlay, import `proxy_entry` đúngbase. Khi futureauthorizedentrymain chạy, frozenproxyentry vẫn configure PYTHONPATH source/vendor rồi `from proxy_collect import install` lấy canonicalmodule đã bind mới. Vì vậy giữ DNSchildfix mà dùng projection sửa; không private monkeypatch hoặc ghi đè frozenmodule. Sai/shadowpath fail OVERLAY_IMPORT_PATH; actualbind/path đã kiểm pureunit. Recipe chưa được chạy server/Docker/source trong lượt này; nhiệm vụ sau cần fingerprint/gate tương ứng khi wiringruntime đổi.

Evidence `docs/evidence/tiktok-dns-diagnostics-fix-20261015/`: diff/AST installeridentity/snapshots/hash/actualexits/readonlyverifier/manifest. AUDIT/PROGRESS prepend tiếp receipt mới nhất của reviewer, giữUIprototype cập nhật song song. Prompt kiểm độc lập nằm cùngnamespace. Không nguồn/retry/Attempt2/ExecuteSource/claim/cold/reset/reusegrant/main/gallery/deploy; không hỏi lại5ảnhhumanaccepted.
