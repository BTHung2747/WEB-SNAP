# Sửa hai P2 trong successor offline — 12/10/2026

**FIXED_PENDING_INDEPENDENT_REVIEW**, chưa tự CLOSE hai finding. Lab mới
labs/tiktok/dns-overcap-inspection-hardening, evidence riêng cùng hậu tố20261012;
old lab/evidence/verifier/manifest/golden/apps/pins/claims/latch giữ byte.

- F-DNS-V3-TRACE-BYTE-CONTRACT: receipt bytes int thật/dương/input≤16384,
  response≤32768, inputCap16384/responseCap32768 đúng int; trace samehelper byte
  fields kiểm type/range trước so equality. Missing/bool/float/NaN/negative/zero/
  overflow/cap mismatch/missing/link mismatch PARTIAL; không normalize/default0.
- F-DNS-V3-RETURN-AFTER-CLEANUP-DEADLINE: try chỉ pending, return guarded sau
  finally cleanup/observer và absolute recheck cuối. Resolution luônFAIL tới
  authorization, lateTimeoutError/FAIL dù nativechild0. All-cleanup best effort,
  secondary không thay primary DNS/OSError/cancel. END/REAPED là closure quan sát,
  chưa cam kết success; latecleanup ERROR/DEADLINE, lateobserver END/REAPED và
  diagnosticFAIL, khôngEND/OK giả hoặc pending operation cho hai đường late.

Cached image/actual Debian3.11.2-6+deb12u8/ipaddress8fc7549e…5355e1 và public APIs/
libraries/guard/backend/metadata30/prepare60/setup10/end−1/HTTP10–20/acceptance64/
inspection256/cooperative250ms/retained96KiB/designheap128KiB/combinedstats512/
IPC16–32KiB/policyC/SSRF/TLS/RAM512+96=608/UIDROprivateIPCcapALLNNP giữ.
[API/licensing/provenance](evidence/tiktok-dns-overcap-inspection-hardening-20261012/NOTICE.md).

**87fresh narrow cases/native0** networknone96MiBCPU.25/UID65534RO:3old counter-
examples accepted trước/reject sau, byte presence/type/bounds/caps/mismatch và
controls;8numeric helpers thật với owned callback injection, không resolvermock
cho deadline. Early0.280880sPASS/budget1; delayedcleanup1.051758sTimeoutError/
FAIL/native0/reaped/pipesclosed/group0; delayedobserver1.051597s cùngFAIL. Cảhai
late trace pairingCOMPLETE/open0/noEND-OK. PrimaryOSError object identity giữ khi
cleanup/observer lỗi hoặc late; cancel/cancel-late giữ CancelledError/native−15.
FD4→4/thread1→1. Group-scan injectedthrow =>groupsUnknown/FAIL (không fabricate0).
Observer injectedthrow trước ghi terminal =>traceINCOMPLETE/open1 được giữ như
bằng chứng thiếu vàFAIL, physical reap/pipe/group0; không gọi đó là tracecomplete.

**5fresh whole same finalsource88/runtime86:** normal2metadataGET+conditional1JPEG,
nativeworker/proxy/validator/parentchild0,2170bytes/64×64/static1frame/fullDecode/
SHA3c94b9a6bbfab0c44c02d0c520dca952e23dc7a396e30a6ef3b0fe00bcc0cc3e.
65dup/65unique thống kêCOMPLETE(endpoint1/65) vẫnmetadataFAIL/ANSWER_CAP trước
TCP/image; parent20/child−9/workercontainer20/validator20/proxyhelper0. Byte-missing
tamper receipt+trace packet/fileprovisionalPASS nhưngvalidator20/DNSgatefalse và
dọnonlyownJPEG; sentinel cũ giữSHA. Wrapper0 làexpected-negative, khôngsourcePASS.

**8actual validator replays** trên own copies normal: control old0/new0 và ảnhgiữ;
missing/float/overflow old0/DNSgateTRUE/ảnhgiữ →new20/DNSgateFALSE/ownảnhdọn. Không
producer rerun cho replay, input before snapshots/private receipts giữ. Đây là
fresh counterexamples ở old readonlycode, không đổi manifest/golden hay gọi nguồn.
Không rerun105/302/13 hoặc fullhistory để tăng số PASS.

Exactown24containers/10internalnetworks absent;13image/25oldcontainers/35volumes/
rendererabsent giữ. Globalnetworkdelta nếu có causeUNKNOWN, không daemonfix hoặc
nói toànnetwork invariant. Source88/runtime86 frozen gate cùng probe/whole và
codecopies; protected1669 +latest audit435/parent608/docs before substitutions
và accepted95/runtime93/predecessor87/runtime85 giữ. New sealed namespace/verifier/
UTC-VN/native/function/signal receipts; SOURCE_DISABLED20 before network.

Lệnh thực (bundledpwsh7.6.5 -NoProfile -File): prepare.ps1;run-probe -Attempt1;
make-gate;labrun -Stageoffline -Attempt1normal;run-whole (2–5);mutate-replays;
run-replays (old/new/control+3variants);inspect-cleanup;default CLI;record;
verify -Seal rồi readonly. Các scripts nằm trong newevidence/lab; sourcecalls0/
claims0/no build-pull-install/main/UI/API/DB/settings/host/deploy/browser.

Consumed task2713473edcf94a139dd91d1d82939d0a/allocationa0c19e584c614c9badfa47bbc46b35b2
giữ, không reset/reuse/newauthority/sourcegate. SourceảnhFAIL/noJPEG/visualNOT_REVIEWED/
actualraw-unique-duplicate/networkcauseUNKNOWN;videohuman2/3/sample3pending/main-
galleryOFF giữ. [Prompt kiểm độc lập](evidence/tiktok-dns-overcap-inspection-hardening-20261012/NEXT_PROMPT.md).
