# Authority v4 strict scalar string — 13/10/2026

**F-V4-AUTHORITY-STRING-COLLECTION-COERCION FIXED_PENDING_INDEPENDENT_REVIEW.**
Successor riêng `labs/tiktok/photo-source-trial-v4-string-hardening/`; evidence
`docs/evidence/tiktok-photo-source-trial-v4-string-hardening-20261013/`.
Freeze mới109source/107runtime; candidate108/106 và mọi audit/history giữ nguyên.
Không tự đóng P2, chạy SOURCE_TRIAL_DRAFT, cấp quyền hoặc gọi nguồn thật.

`ScalarString` dùng PowerShell public `-isnot [string]` trước mọi thao tác equality/
regex/path/hash. Không ép kiểu, normalize hoặc lấy phần tử đầu. `StringSchema`
kiểm gate/proof/evidence/runtime rows/allocation/authorization/review/claim,
attestation/version fields và control release. SourceRead/SourceSHA/FixedPath/
Expiry/NewIDs/RowsHash/ExclusiveReceipt nhận untrusted type chưa ép kiểu. RowsHash
kiểm typed rows trước khi xây mảng string/sort/hash. Exact keys/case-sensitive/
JsonDocument duplicate+case-alias rejection giữ. Child source_admission thêm
explicit string gate cho control strings và claim.utc; các claim fields khác
vốn kiểm exact type trước equality. Claimed inputs không còn collection coercion.

Chỉ functional source_contract/source_admission thay đổi; namespace run/contract
inventory và notice mới. Source_policy/common/proxy/worker/finalizer/DNS/Cobalt/
Requests/urllib3/HE/yt-dlp/FFmpeg/classifier/locks/LICENSE/NOTICE/guards/quotas không
đổi. .NET/Python/PowerShell pins giữ PS7.6.5/.NET10.0.11/Python3.11.2. Glue là
schema riêng WED SNAP, không parser/resolver/downloader/private helper mới.
API chính thức đã đối chiếu:
[comparison7.6](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_comparison_operators?view=powershell-7.6),
[type operators7.6](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_type_operators?view=powershell-7.6).

Thực chạy mới:

- Frozen candidate probe17checks/4counterexamples, chỉ đổi output/SourceRoot;
  scope/status/target/type singleton JSON arrays vẫn falseaccepted/tạo5mockclaims
  cùngtypedcontrol. Source/capability/DNS-HTTP0, không sửa candidate để tái hiện.
- Successor384checks/native0: matrix string fields của7schema với empty/single/
  multiple array/null/object/bool/number, đúngscalar control;4counterexamples
  fullClaim path deny AUTHORITY_SCALAR_STRING_REQUIRED trước latch/claim/capability.
  Proof/evidence/runtime hash/path collections/fullcontract/wrongstring/untyped
  path APIs/JSONduplicate+casealias deny; typed consume/reuse/afterlatchfail giữ.
  Đây là checks cho fields vừa đổi, không rerun history để tăngcount.
- Cold101checks/native0/networknone96MiB/CPU.25: original21policy+fresh70control
  stringcases+10claim stringcases qua public IO delegate, actualcoldimports/
  runtime/trusthash giữ, DNS-TCP hooks0. Cold authority là mô phỏng cólabel, không
  live authorization. Host-Python consumer cùngreject arrays, claim.utc cũngstrict.
- 1wholeTLSmock129 qua runner/hash mới, mockconsume trướccapability,2metadata+
  1conditionalJPEG/parent-child-worker-proxy-validator0/2170bytes/64×64/1frame/
  fullDecode/SHA3c94b9a6bbfab0c44c02d0c520dca952e23dc7a396e30a6ef3b0fe00bcc0cc3e.
- 3copiedfixturefinalizerreplay:control0,outerbool20/DNSgatefalse/dọnownJPEG-part,
  sentinelbool20/giữpreexistingSHA/dọnownpart, noHTTP-DNS-helper-download mới.

RawFAIL giữ: contract1 harness dùnghashtable row không đúng PSCustomObjectshape,
đãschema reject RECEIPT_SCHEMA nhưng script kỳ vọng scalar code; successor fixture
JSON roundtrip/outputcontract2 riêng. Repair parse1 extra parenthesis giữscript/
receipt, trước execution. Runtime không đổi saufreeze; khôngsửa fixture/verifier
để nhận invalid. Failure schema không là sourcebug haymetadataPASS.

Gate preparation/sourceGatefalse, mock/live scopes/target7678209751167110421/index1/
expiryUTC≤10min/newtask-allocation/oldconsumed deny/CreateNew/FileShareNone/Flushtrue/
consume trước capability/noreset giữ. Byte/time/metadata30-prepare60/HTTP10–20/
2meta+1image/retry-redirect-HEAD0/SSRF-TLS/raw256-unique64/order/IPC/heap/trace/
cancel/ownership giữ. SequentialRAM8GB/cachedimage/no build-pull-install/narrow96/
whole512+96=608/validator96saurolesstop/UIDRO/privateIPC/dropALL/NNP/ROcode/noports.

Own7containers/2nets absent;13images/25oldcontainers/35volumes/main/rendererđúngID
giữ/globalnetdrift UNKNOWN/nohostfix/protected5279/parent504+auditfinal2 manifests/
rawFAIL/goldens/verifiers/consumedclaims/libs giữ. Docsinsert-only/fullcoverage
namespace mới. Bản verifieraudit1FAIL được đọc/bảo toàn cùngfinal2; không dùng
audit1 làm runtime kết quả. Sourcecalls0/realclaims0/ảnhFAIL_NO_JPEG/visualNOT_REVIEWED/
video2/3/mẫu3pending/galleryOFF/app/API E2E/deploy giữ. Không claim bypasslive hoặc
sourcePASS. Liveauthority/source networking và fullheap/IPv6/timing không kiểm lại.

Lệnh bundledpwsh -NoProfile -File:prepare;wire-harnesses;wire-cold-probe;freeze;
reproduce/probe;contract1FAIL→repairparseFAIL→contract2;run-cold;make-offline-gate;
run-whole;replay;collect;make-verifier/build-gatefalse;insert-docs;verifySeal/readonly.
Native/raw/signal/UTC-VN/hash/provenance/coverage ở evidence. Bước tiếp chỉ
[kiểm độc lập](evidence/tiktok-photo-source-trial-v4-string-hardening-20261013/NEXT_PROMPT.md).
