# Backend — logger cap đúng byte và nối diagnostic runtime, chỉ offline

19/10/2026. Chủ đã giao reviewer tự giao việc. [Review diagnostic](../evidence/ui-source-job-residual-diagnostic-review-20261019/ASSESSMENT.md) chấp nhận observation NOT_REPRODUCED nhưng có **F-DIAG-PERSISTED-BYTE-CAP[P2]** tái hiện18799B diagnostic vượt16KiB dù guard tính9543B. Mục tiêu task này: sửa cap thật và chuẩn bị một runner có diagnostic cho attempt kế, **không** chạy lại ps/runtime để săn lỗi.

## Nguồn và namespace

Đọc AGENTS/CURRENT, assessment và pure counterexample/proof, đúng diagnostic common/collector/build/diff/finalDLL plan và `ui-source-runtime-probe-fix/core.ps1`/native/prepare/run đã review. Kiểm dependencies/APIs hiện có, ưu tiên System.Text.Json/ConvertTo-Json/FileStream/helper sẵn có, không tự viết serializer/executor. Verify API mới bằng tài liệu chính thức nếu dùng. Không package/SDK/compiler/image/build/pull mới.

Chỉ code mới `labs/tiktok/ui-source-diagnostic-runtime/`, evidence `docs/evidence/ui-source-diagnostic-runtime-20261019/backend/`. Giữ diagnostic8source/32artifact manifest5d22…f902, original owner/helper/controls, fix6source/17artifact, failed runtime8+7,311baseline/frozen/historical snapshots/locks/app/UI/plan/trust nguyên. Không sửa logger cũ hoặc golden để che finding; successor chỉ phần glue cần thiết, có dependency map/pins/diff rõ. CURRENT reviewer cập nhật.

## Sửa actual persisted byte cap

1. Serialize UTF-8 bằng API có sẵn và **đo đúng bytes được ghi**, cùng formatting/depth/escaping/newline policy; không đo compressed rồi persist pretty. Cap diagnostic≤16384B, whole operation≤65536B. Nếu whole record nested indentation làm khác subobject riêng, phải đo diagnostic raw span thật hoặc chọn một serializer/buffer không đổi qua bước write. Trước khi mở file/persist, validate budget trên chính payload; không tăngcap.
2. Regress reviewer3snapshot×16PID, max events64, empty/error/long numeric values và Unicode/escaping phù hợp allowlist. Bao boundary cap-1/cap/cap+1, cả diagnostic/whole receipt và exact bytes đọc lại. Có strict no-overwrite và no partial-success/invalid-truncated-JSON. Overcap chỉ bounded incomplete marker/code nếu cần, không lưu raw/full diagnostic vượtcap hoặc tự bỏPID rồi tuyêncomplete.
3. Cap/serialization/sink failure phải **evidence incomplete + final completionFAIL**, không sửa Native Status/force/exit để giả nativeFAIL/PASS và không chặn Stop/finally/owner-only cleanup. Một logging lỗi không được tái tạo coupling đã sửa. Cleanup vẫn cần identity/mount safety thật, không nới ownership để bù thiếulog. Không che lỗi bằng return success hoặc resetdeadline.

## Wiring để attempt sau có chẩn đoán thật

- Tạo runnable prepare/run/delegate/sink successor tối thiểu, **reuse Invoke-ProbeAttempt từ fix core đã pin** và final diagnostic DLL/collector đã pin; không copy lại executor/lifecycle hoặc import old run/query/recovery body. Đổi namespace/folder chỉ trong wrapper cần thiết. Original integrated helper vẫn nguyên; không thay registry/private authority hoặc sửa Stop/force/FAIL semantics, grace/sleep/caps/timing policy.
- Delegate tới **WedJobDiagnostic.Engine** thật (không WedOwnerWin32.Engine nhầm) với source/DLL/location/MVID/layout/anchors inverse base pins. Thu kết quả native cùng diagnostic vào logger mới; raw stdout/stderr chỉRAM. Core guard/owner/state/packets/cleanup predicates không đổi. Metadata/attach deadlines15000/20000,64KiB, collector16PID/3snapshot,400ms tail và no reopen root giữ.
- Prepared plan mới trong evidence successor riêng, fresh runID/names, dependency map tới readonly observer files/cacheIDs/UID/quotas/tmpfs gốc. Core task marker đang fixed `runtime-probe-fix-20261019`; giữ tương thích owner label contract và ghi execution namespace riêng, không đổi core chỉ để rename. Source gate/flags không bật, networknone/noports/0customnetwork/max1running5roles giữ. Snapshot preparation không tự là runtime authority.
- Actual run entrypoint phải reject trước delegate/native khi chưa có task/switch riêng; switch không là capability/security boundary, không bịa authorization. **Không** gọi entrypoint với runtime switch hoặc actual Engine.Run trong task này. Không compile helper mới vì finalDLL hiện hành đủ; Add-Type load metadata để check admission được, không fake native run thành template/runtime proof.
- Preserve/tách native outcome/container state/runtime assertions/diagnostic persistence/evidence completion. Nếu diagnostic logger lỗi sau create/start, delegate vẫn trả native observation chính xác và coordinator vẫn có đường owner-only cleanup; completion/admission phải FAIL/UNKNOWN chứ không start role tiếp. Chứng minh đường wiring thực, không fixture helper không được runner dùng.

## Kiểm offline bắt buộc

Pure serialization/tests đi qua **logger+delegate/sink+Invoke-ProbeAttempt** bằng injected fake native result/executor rõ nhãn,0daemon/native process. Test success5roles fake, guardFAIL mà ownercleanupđúng, foreign/missing identitykhôngdelete, receipt/logcap/write failures sau create/start, forced root0 khôngPASS, containercreated/exit0khôngPASS, shutdown/cleanup budgetkhôngreset và no subsequent admission sau evidence incomplete. Verify actual disk bytes/hash/readback JSON cap-1/equal/+1,3×16/64events, no overwrite và safe incomplete marker.

Không cần rerun33nativecontrol assertions/6nativecontrols/58/17case cũ; tham chiếu evidence đã pin, case mới tách riêng. Nêu rõ collector timing perturbation:3.8555ms không bao mọi hook delay; root-capture→release7.1834ms ở observation cũ. Historical cause vẫnUNKNOWN, không chữa bằng delay hoặc tái định nghĩa nativePASS.

## Bàn giao rồi dừng

0Docker ps/query/container/network/lifecycle/browser/source/main/gallery/deploy/keys/grantclaim/hostsettings trong task này. Chỉ đọc official docs/source qua web khi cần API. HANDOFF/NEXT_REVIEW/manifest có closure scope của capfinding, exact serialized byte proofs, code/API sources/pins/delta/wiring/dependency map, fixture counts/expectedFAIL, ready entrypoint và phần chưa thực thi. Giữ mọidevelopmentFAIL, không sửa hồ sơ sealed hoặc gộp số ca lịch sử.

Báo reviewer chat `01a14259-19b0-73f0-bd0c-0f5be84f6a88` theo ủy quyền chủ rồi **DỪNG**. Reviewer nghiệm thu offline rồi mới giao một attempt runtime instrumented trong quyền lab đã có; frontend READY/chờ, không UI/contract delta. Không tự chạy lifecycle sau testPASS.
