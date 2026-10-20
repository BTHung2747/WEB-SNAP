# HTTP success policy finalizer — 14/10/2026

**FIXED_PENDING_INDEPENDENT_REVIEW** cho F-ALBUM-FINALIZER-HTTP-SUCCESS-POLICY.
Hai P2 cũ accounting revalidation và Operations typed/order giữ CLOSED_OFFLINE_CONFIRMED.
Code successor `labs/tiktok/photo-album-http-success/`, evidence riêng
`docs/evidence/tiktok-photo-album-http-success-20261014/`; sourceGate=false.

Chỉ thêm `http_success.py` và lời gọi/gate trong finalizer sau revalidation. Không
sửa accounting.receipt/typed equality/observer/Operations/decoder/downloader/transport.
Runner/hash contract chỉ đổi namespace. Giữ Cobalt/imputnet/AGPL/LICENSE/NOTICE/lock,
Python3.11.2/Requests2.34.2/urllib3-2.8.0/yt-dlp2026.8.19/HE2.7.1/cachedimage31742091…417e.
Không dependency/build/pull/install. Provenance/code-diff/source-runtime hashes ghi thực.

Policy **FULL_GET_200_ONLY** cho cảmetadata vàảnh. Core.GuardedYDL.urlopen đã deny
redirect300–399 vàHTTPerror≥400; finalizer bổ sung content success thay vì chỉtin
quota/coverage/report equality. API status_code vàcore pin giữ nguyên. Ordinary
GET200 có representation theo RFC9110§15.3.1;206 liênquan range/multipart cần
Content-Range/assembly§15.3.7 mà lab này không hỗ trợ. Vì khôngRange/khôngassembly,
chọnallow200bảo thủ; informational1xx vàother2xx (kể cả204/206) failclosed, không
suyngược mọi2xx làbody đầyđủ. Thêm Range/statussemantics khác lànhiệm vụriêng.

Kiểm tất cả packet row.status, sendDiagnostic.status vàstatuses trongreceipt đã
tínhlại theoN; yêu cầutypedint200,metadata1..2statuses vàprepareNstatuses. Gate
accounting có thểTrue/COMPLETE khiresponse503, nhưng gatehttpSuccessFalse và
HTTP_SUCCESS_POLICY→albumFAIL/dọnallownedJPEG+parts/giữsentinel, filesoutputrỗng.
Mismatch vẫn bịaccounting revalidationdeny. Metadata/bodyID/type/index/selection,
JPEG/decodeSHA/native/projection0600/order/RID/bytes/scopes giữ;200 khôngđủmộtmình.
Origin UNKNOWN vàhashconsistency khôngauthentication nếuđối thủthaymọiproducerfiles.

**Kiểm thực đúngfreeze1**:1wholeTLS2JPEGpositive/nativeworker-proxy-finalizer0;
1whole actualHTTPfixture failitem2=503, đúng2imageGET/noGET3/item1discarded/item2failed/
item3skipped/rollback/sentinel. Wrapper0negative làtestđạt, outerworker20/child−9/
validator20 ghi thật. 18networknone copiedfixturefinalizerreplays:typed2000/PASS/2JPEG,
17negative20/FAIL/JPEG0/sentinel. Pairedmeta-prepare503/302/404/500/recomputedreports,
statusmismatch hai phase, secondimage503,204/206 và3counterexamples cũ đều đúng.
Replay không GET503 thật, HTTP/DNS/helper/extractor/download mới. Khôngrerun42/6/15
hoặc73historymatrix đểtăngcount;5selection/DNS/transport khôngđổi.

Caps/guards nguyên:meta≤50/selected≤5/all≤5/2meta+Nimages/8–16MiB+20–16MiB/116–80max/
metadata30prepare180item60reserve10/watchdog225activekhônghostE2E/trace256-owner32-map64/
DNSraw256unique64/SSRF-TLS/connect10read20. Sequentialworker512+.75CPU+proxy96/.25=
608MiB/validator96afterrolesstop; user1000-65534/RO/privateIPC/dropALL/NNP/noports/
internalnets. Clone copiedfixture theoUID vàbatch8/15s đãkiểm, khôngnới600loggốc.

Phiên bịngắt sau2whole; đã kiểmcompletion/owncontainers trướcresume, khôngrerunwhole
hoặcghiđènamespace. Docbefore banđầu vàdocbefore-dispatchsuccessor giữ riêng vì
reviewchat cập nhật mục giao việc; insert-only trên bản mới nhất. Actualcommands,
nativeguards/states/exits/UTC-VN/sourcehash/ownIDs/protected/manifest/seal+readonly đầyđủ.

Source0/newclaims0/noTikTok-CDN-sourceDNS/noreset/sourcealbum/main-gallery-UI-API/
DB-host-deploy. Giữbase2187+old2647/audits/goldens/rawFAIL/claims/source-humanJPEG1/
libraries và13images25oldcontainers35volumes/mainrenderer đúngID; networkdriftnếucó
UNKNOWN. Ảnh1humanaccepted giữ;ảnh2–5/albumnguồn vàAPI E2E chưađạt. Reviewer theo
NEXT_PROMPT mớiđóngP2 mới; khôngmởnguồn từbàn giao này.
