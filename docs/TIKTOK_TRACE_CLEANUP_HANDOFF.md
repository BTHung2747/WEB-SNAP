# Sửa F-CLOSURE-TRACE-PREEMPTS-CLOSE — 10/10/2026

**F-CLOSURE-TRACE-PREEMPTS-CLOSE CLOSED_OFFLINE trong successor.**
Lab successor `labs/tiktok/trace-cleanup/` tách cleanup thật khỏi observer.
Targeted31 và full69 (38contracts kế thừa +31targeted) đạt native0
cùng source hash, ghi tại assessment/native/verification của namespace
`docs/evidence/tiktok-trace-cleanup-20261010/`. Không thay gate38/21-of22 lịch sử,
không gán finding này là cause của TLSFAIL cũ; historicalTLScause vẫnUNKNOWN.

## Code và API đã dùng

Chỉ sửa successor lab và tài liệu. Apps/oldlabs/vendor/lock/main/deps/DB/settings/
lifecycle/golden/manifests/verifiers/raw/humanreview giữ. Cache31742091…dfa417e,
actualPython3.11.2/Requests2.34.2/urllib3-2.8.0/yt-dlp2026.8.19/aio2.7.1 giữ;
vendor aiohappyeyeballs unmodifiedRO, commit4dfc926e30eea8d24c1a71602d73c0e9a895c191,
wheelSHA9243213661e29250eb41368e5daa826fc017156c3b8a11440826b2e3ed376472,
PSF/LICENSE/NOTICE và AGPL của fixture/core giữ. Không build/pull/install/deps mới.

- `Trace` kế thừa public caps/count/incomplete/lock từ TraceSink đã kiểm ở
  setup-trace/trace.py. Adapter chỉ bổ sung enum lifecycle và persistent FileOps,
  vì sink mạng không có contract pha finish/close này. Best-effort BEGIN/END/ERROR
  không ném lỗi observer ra delegate; incomplete latched, count≤256/perowner32,
  owners≤64, attempted/dropped saturating≤65535. Fileopen/write/flush/close lỗi
  không reset cap hoặc báo coveragePASS. Mọi actualfile đã mở được giữ ownership
  và đóng trong finally dù FileOps.close lỗi. Không có default message/repr/stack.
- `Trace.phase` luôn yield; ERROR observer không thay exception của delegate.
  `delegate_cleanup` luôn chạy cleanup trong finally, giữ primary exception identity
  khi cleanup có secondary error. Không HTTP/TLS/DNS/race/privatehelper mới.
- Requests accepted registry có state REGISTERED/STARTED/RETURNED/ABORTED.
  Callback/thread-create/thread-start fail đóng/rollback request; aborted chưa chạy
  không bị bịa workersStarted/Returned. Actual worker luôn shutdown/close/final-return
  và notify condition dù error emission lỗi. Delegate exception giữRAM theo bounded
  owner để kiểm identity, không serialize token/URL/message/stack.
- `wait_cleanup` chỉ kiểm physical sockets/threads/absolute budget; `wait` còn
  reject DiagnosticIncomplete hoặc delegateErrors. Vì thế resources0 không biến
  diagnosticFAIL thànhPASS. `test_poc.py` vẫn reject incomplete sau Trace.close.
- `diagnostic_gate.py` là **child gate lab nhận numeric receipt≤4KiB**, không nguồn/
  extractor/file/API. Nó reject missing/incomplete/closure/delegate failures bằng
  **native exit20 thực**. Receipt control trả0; sourceFileAccepted luônfalse.
  Chỉ lab evidence gate, không claim adapter CLI/photo wholeflow được tích hợp.

Đối chiếu nguồn:
[TraceSink có sẵn](../labs/tiktok/setup-trace/trace.py),
[socketserver3.11.2](https://github.com/python/cpython/blob/v3.11.2/Lib/socketserver.py),
[contextlib3.11.2](https://github.com/python/cpython/blob/v3.11.2/Lib/contextlib.py),
[aio2.7.1 public API](https://github.com/aio-libs/aiohappyeyeballs/blob/v2.7.1/src/aiohappyeyeballs/impl.py).
Stdlib/library delegates giữ; fixture injection FileOps, callback và worker_factory
là project-owned public dependency, không monkeypatch private library.

## Kiểm thực chạy và ý nghĩa native exit

Bundled pwsh -NoProfile -File labs/tiktok/trace-cleanup/run.ps1 từ D:\WED SNAP:

| Attempt/Cases | Evidence/kết quả |
|---|---|
|1/Targeted|sandbox Docker pipe denied trướccontainer; wrapper1, giữraw, không functional/sourceFAIL|
|2/Targeted|30/30 native0, legacy3probe+29faultgroups; gateActualExit20 lúc này là assigned policycode, chưa child native; giữ nguyênraw|
|3/All|68/68 native0 trên đúng mã attempt2;38contracts+30targeted, không nguồn|
|4/Targeted|31/31 native0 sau review native-label; thêm gatechild thực và missingreceipt|
|5/All|69/69/suite-container-runner0, đúng mã/hashes attempt4; verdict từ actualresult/completion|

Review sửa field gateActualExit được lưu native-gate-review.json/snapshot trước sửa.
Không đổi raw2/3 để biến policycode thành exit đo được. Các lượt sau có code/case mới
cụ thể và fullgate tương ứng, không chạy mù đếnPASS.

Legacy reproduction load **mã cũ nguyênhash** cee0a83fe2856855a9f6a7d917aa62a9271358085e36b2d6627a638d5b4e05d9:
control closed1; cap-close/io-shutdown FDleft1/closed0/incompleteTrue. FD4→4 sau manual
recovery chỉ thuộc probe; không gọi là candidate đã cleanup. Bản sửa control/cap/
write-before-shutdown dùng acceptedTCP thật: FD−1/closed1, không manual request cleanup
sau đo; incomplete/dropped giữ và gatechild20 ở negatives, controlclose0. Directprobe
không dispatch nên workersStarted/Returned0 được giữ đúng, không acceptance workflow.

Fault30groups bao phủ control, cap-before-close, write-before-shutdown, total256,
owner32, acceptEND, finishBEGIN/END/ERROR, shutdownBEGIN/END, closeBEGIN/END,
worker-return, barrierEND, fileopen/write/flush/close, handlererror, threadfactory/
start, acceptcallback, registry64, delegateclosebefore/after, trace+delegate,
servercloseBEGIN, registryclose và missingevidence. Các dispatch đi qua public
process/handler/finish/shutdown/close thực; barrier thật trướcFD/thread kiểm.

Abortcases: accepted1/closed1/aborted1/started0/returned0/errors1/identityTrue;
registry-cap: accepted64/closed64/returned64/rejected1, sockets/thread0. Combined
trace+delegate và ERRORobserver giữ original error identity, requestFD closed;
file-close lỗi vẫn physical closes ownedfile. Missingtrace vẫn rejection ngay cả
khi actual Trace đầy đủ và resources0. Fault harness0 nghĩa expectation đúng;
diagnostic gatechild20 nghĩa dữ liệu thiếu/lỗi bị từ chối, không thành metadata/filePASS.

38contracts kế thừa kiểm TLSverifyTrue/early/slow/cert/stall, absolute10 từtrướcspawn/
end−1reserve/predicateReady/socketFactoryexpiry, DNSPopen/threaded/cancel/crash/
IPC16–32KiB/64answer/inheritance/parentblock/epoch-reap, order/interleave0/delay0,25/
group2/candidate/loserclose và exceptionidentity. SIGKILLnegatives chỉcontainment,
không gracefulchild0. No-source/numeric-localhost fixture, OSresolver/D-state/
TLSdetail/correlation/historicalTLScause UNKNOWN. Core metadata30/prepare60/
connect≤10/read≤20/body/input/output/pixel/decode/SHA/lifecycle/ownership giữhash.

## Evidence và bước sau

Baseline4914/currentwhole-source107/newruntime14/vendor10/core23 được verifier mới
đối chiếu; targeted4 và full5 source snapshots phải byte/hash bằng nhau. Trace faults
được coverage như incomplete, không đòi log-row equality rồi sửa manifest đểPASS.
Source/golden/verifier/raw cũ giữ qua predecessor+document before bridge; chỉ
AUDIT/PROGRESS prepend, newmanifest bao phủ newraw/snapshots/native/guard/results.

Sequential network-none512MiB/swap512/CPU0,75/pids96/user1000/RO/capALL/NNP/privateIPC/
sourceRO/nohostport/tmp32, helper/gatechild cùngcgroup/tổng512≤608. Remove exactownID/
runlabel, mainimagee7f93577…0184b giữ. Không source/TikTok/HEAD/browser/JPEG thật/
mainapply/deploy. Gallery/mainOFF/sourceAPI E2ENOT_RUN/video2/3/mẫu3reviewchờ.

Bước kế tiếp chỉ review negative+fullgate, không nguồn hoặc wiring tự động. Finding
chỉ đóng **offline của successor** khi assessment và verifier chỉ rõ samehash/native/
cleanup0/diagnosticFAIL đúng; lịch sử auditREJECT_PENDING_FIX vẫn giữ nguyên bản.
Sau review và nhiệm vụ riêng mới xét own-egress+wholephotooffline. Prompt cùng
namespace giữ các điều kiện này; file/metadatafixture không thay source/review.
