# Phương án DNS answer accounting — nghiên cứu offline12/10/2026

**Chọn A: giữ raw cap64, triển khai diagnostics số lượng có giới hạn trong successor offline ở bước sau.** Chưa sửa runtime đang nghiệm thu, chưa dedup/tăng cap/mở gate nguồn. Mô hình riêng đã đạt63ca, native container0; không chứng minh khả năng tải ảnh TikTok. Nguồn hiện tại vẫn NOT_ACCEPTED/visual NOT_REVIEWED; nguyên nhân resolver/mạng và số endpoint thực UNKNOWN_NOT_RETAINED.

## Căn cứ và thư viện

Nguồn mới thất bại DNS ERROR/ANSWER_CAP trước TCP: task2713473edcf94a139dd91d1d82939d0a/allocationa0c19e584c614c9badfa47bbc46b35b2 đã consumed. Helper hostname chỉ phát mã đó khi raw getaddrinfo list vượt64, sau đó answers=[] trước IPC. Không suy answerCount0 thành DNS không đáp án, không gán mã mới cho raw lịch sử không giữ responseCode. Audit độc lập PASS_INDEPENDENT_SOURCE_FAILURE_AUDIT/newFindings0; source acceptance FAIL. Hai giả thuyết tập nhiều endpoint khác nhau và tập nhiều bản ghi trùng đều phù hợp cùng receipt; chưa có dữ liệu để xếp một giả thuyết cao hơn.

Đã đọc locks, code helper/IPC/guard/proxy/batch/diagnostic và nguồn chính thức đúng bản. API getaddrinfo trả5tuple; AF_INET dùng sockaddr2tuple, AF_INET6 dùng4tuple. Các trường tạo socket và connect không thể thay bằng mỗi IP string. [CPythonv3.11.2 socket docs](https://raw.githubusercontent.com/python/cpython/v3.11.2/Doc/library/socket.rst).

Python wrapper giữ danh sách và đổi family/type thành enum, không dedup. [Lib/socket.pyv3.11.2](https://raw.githubusercontent.com/python/cpython/v3.11.2/Lib/socket.py). Hash nguồn official socket.py **6adf8b776dce1c1001865cdab0a336fbc9a149b82b017ad4dc7fcfd319599c06** khớp file thực trong container. Tag v3.11.2 và bytes/SHA đủ6file lưu ở official-references.json; không suy binary _socket hoặc libc đã được đối chiếu toàn bộ.

C extension gọi resolver hệ điều hành và dựng cả list trước khi trả; không có public streaming/cardinality/deadline option cho getaddrinfo. Flowinfo/scopeID đi vào sockaddr; port16bit, flowinfo20bit. [socketmodule.cv3.11.2](https://raw.githubusercontent.com/python/cpython/v3.11.2/Modules/socketmodule.c). Parent Popen/selector/kill/reap và cgroup vẫn là containment cho resolver bị block hoặc cấp phát nhiều; raw cap kiểm sau return không phải cap bộ nhớ lúc resolver cấp phát.

Mô hình dùng public ipaddress.ip_address/int và classifier is_global đúng Python3.11.2; không đổi danh mục địa chỉ hoặc tuyên bố is_global bảo đảm kết nối/routability. [ipaddress.pyv3.11.2](https://raw.githubusercontent.com/python/cpython/v3.11.2/Lib/ipaddress.py). Harness dùng public unittest.mock.patch, không sửa resolver thật. [mock.pyv3.11.2](https://raw.githubusercontent.com/python/cpython/v3.11.2/Lib/unittest/mock.py). Các tham khảo tải về chỉ để đọc; không import/chạy. Python license PSF Version2/G. van Rossum–PSF và lịch sử tác giả giữ trong LICENSE official.

aiohappyeyeballs2.7.1, commit **4dfc926e30eea8d24c1a71602d73c0e9a895c191**, J. Nick Koston/contributors, PSF-2.0, wheelSHA **9243213661e29250eb41368e5daa826fc017156c3b8a11440826b2e3ed376472**, Python>=3.10/no extra runtime deps. Official impl và wheel byte-identical SHA eb32b7ba…a64bb2. Public start_connection/socket_factory là lựa chọn kết nối đã ghim; source review cho thấy nó chuyển family/type/proto vào socket và sockaddr vào loop.sock_connect, bỏ canonname. [Nguồn tại commit](https://github.com/aio-libs/aiohappyeyeballs/blob/4dfc926e30eea8d24c1a71602d73c0e9a895c191/src/aiohappyeyeballs/impl.py). Không gọi helper private.

Public utils hiện có addr_to_addr_infos dựng mặc định family/type/proto, remove_addr_infos loại theo sockaddr và pop_addr_infos_interleave sửa thứ tự; không đáp ứng strict endpoint equivalence, all-answer validation và WED SNAP numeric receipt. Không chọn chúng làm dedup policy. Không cần resolver mới, c-ares/aiodns, Requests/urllib3 transport mới hoặc dependency mới. Phần tự viết chỉ là policy/count/schema mô hình; DNS, numeric parsing, IPC và connection API vẫn ủy quyền thư viện hiện có. Đây là review API/version/license hẹp, không đánh giá đầy đủ CVE/maintainability của mọi dependency.

## Ranh giới hiện hành

1. Proxy giữ host allowlist/CONNECT443, không redirect/retry/HEAD. Một helper, địa chỉ nguồn chỉ RAM. Helper hostname dùng getaddrinfo(host,443,typeSOCK_STREAM); proto/family/flags mặc định, không lọc DNS trước policy.
2. getaddrinfo return xong: deadline kiểm trước ANSWER_CAP. Raw>64 ⇒ ERROR/ANSWER_CAP/answers[]; all-answer validation không cần cho phép tập đã bị từ chối. Raw<=64 đi qua RAM IPC input16KiB/output32KiB; parent đọc streaming<=32KiB, native/helper identity/receipt/cleanup được kiểm. Oversize/deadline/unknown đều fail.
3. Parent dns_ipc.resolve chuẩn hóa JSON tuple rồi candidate.guard kiểm toàn bộ IP.is_global cùng familyAF_INET/6/typeSTREAM/port443. Private/invalid ở bất kỳ vị trí nào khiến cả tập bị từ chối, không lọc bỏ để tiếp tục. Không socket trước bước này.
4. candidate.connect giữ cap64 và kiểm lại tập trước batch. PolicyC có2socket/4groups/prefix8/stagger.25/interleave0; setup10s/end−1reserve và absolute metadata30/prepare60 không đổi. DNS64 không đồng nghĩa đã connect64; suffix chưa thử giữ UNKNOWN.
5. Trace256/owner32/map64; connection↔registry↔groups, closure evidence và native exits tiếp giữ. DNS diagnostic COMPLETE chỉ nói observation đầy đủ, không DNS resolution PASS hay metadata/JPEG PASS.

## Tuples, IP, sockaddr và endpoint

Raw tuple gồm family/type/proto/canonname/sockaddr. Cùng một IP có thể tạo nhiều socket/connect arguments; IP duy nhất không bằng endpoint duy nhất. Mô hình dùng key bảo thủ **(family,type,proto,numericIP,port[,flowinfo,scopeID])**, giữ first row nguyên dạng và stable order khi thử dedup; không serialize key hay trả IP vào receipt.

| Trường | Quy tắc tương đương nghiên cứu | Căn cứ/giới hạn |
|---|---|---|
| family/type/proto | Giữ cả ba; proto0 khác6, STREAM khácDGRAM; IPv4 khác IPv4-mapped IPv6 | Tham số socket khác, không chứng minh OS tương đương |
| IP literal | Parse bằng ipaddress, numeric value cùng family; IPv6 compressed/expanded có thể cùng key | Không DNS/inet name lookup; không gộp IPv4 sang IPv6 |
| port | Giữ port,443 khác444 | Tham số connect khác; source policy chỉ443 |
| flowinfo/scopeID | Giữ cả hai ngay cả IP global; key khác nếu khác giá trị | Kernel sockaddr còn các trường này, không bỏ scope |
| canonname | Không thuộc endpoint key; giữ first original row | Public connection code không dùng canonname; TLS vẫn original allowed hostname, không đổi SNI |
| textual zone `%...`, sai shape/type/family | UNKNOWN/ROW_INVALID trong mô hình bảo thủ | Không chứng minh alias scope name↔ID; không chuẩn hóa đoán hoặc gọi if_nametoindex |

Mô hình nhận family/type IntEnum và JSON int nhưng loại bool/float; AF_INET đúng2tuple, AF_INET6 đúng4tuple, numericIP<=45chars/nozone, canon<=255/noNUL, proto integer0..2^31−1, port0..65535, flow0..1048575/scope0..2^32−1. Đây là miền được chứng minh cho count/equivalence, không bản sao parser kernel tổng quát. B thêm sourceRow policy STREAM/proto0or6/443/global; fixture protocol17 cho thấy B từ chối trong khi current guard chỉ xét family/type/port/global. Vì vậy B không tự được coi là backward-compatible.

## Hai phương án và quyết định

| Tiêu chí | A — giữ raw64 + bounded diagnostics | B — validate all rồi stable endpoint dedup |
|---|---|---|
| Tập được runtime nhận | Giữ y nguyên cap64/error/answers/order; stats không làm FAIL thành PASS | Chính sách khác; có thể nhận raw>64/unique<=64 nếu có raw bound mới được duyệt |
| raw65/unique1 fixture | Vẫn ANSWER_CAP; stats chỉ AT_LEAST_65, uniqueUNKNOWN | Chỉ mô hình chọn1; không chứng minh nguồn trùng hoặc tải được |
| raw65/unique65 fixture | ANSWER_CAP | UNIQUE_BOUND, không connect |
| all-DNS SSRF | Reject nguyên tập ở cap; <=64 vẫn guard toàn bộ | Phải validate toàn raw bound trước dedup; private/invalid dù nằm sau64 vẫn fail |
| Deadline/RAM | Scan<=64 và thêm<=512bytes stats; parent/cgroup vẫn cần cho getaddrinfo bulk | O(R)+O(U) và initial resolver list; cần riêng bounds/time/IPC budget đã chứng minh |
| Receipt/compatibility | Versioned stats với strict same-helper linkage; không sửa v1 raw | DNS raw/unique/connect order/suffix và registry/group proof phải version lại |
| Thông tin còn thiếu | Không biết unique/duplicates của tập bị chặn | Chưa biết source R/U, chưa có raw bound hoặc socket equivalence kernel/TLS thực |

**Khuyến nghị A.** Dữ liệu thực chưa đủ để chọn B hoặc chốt raw bound lớn hơn64. Trong model.py, WITNESS_RAW_BOUND65 chỉ là mức nhỏ nhất để dựng counterexample65: raw66 bị từ chối, unique cap64; không đề xuất65 làm runtime cap, không import modelB vào successor triển khai. Key mới giữ first order nhưng việc giảm duplicates có thể đổi thời gian/groups/attempts; prefix8/trace256 vẫn không được nới. Không truncate raw, chọn subset để pass, lọc bỏ invalid/private, retry hoặc thay backend. Nếu equivalence/bounds thiếu bằng chứng, giữ policy hiện hành.

## Schema diagnostics đề xuất — chưa tích hợp

counts.version1/policyRAW64_OBSERVATION_ONLY, exact keys, encoded<=512bytes nằm trong IPC32KiB hiện có. Các receipt public chỉ chứa số/enum; hostname/IP/answers/token/cookie/message/repr/stack không xuất. Fixture constants chỉ là input giả trong harness; raw IPC answers ở RAM, không ghi packet đầy đủ.

| Trường | Miền/ý nghĩa |
|---|---|
| rawCount/rawCountMode | EXACT:int0..64; AT_LEAST_65:int65 là lower bound saturated, không exact65; UNKNOWN:null |
| endpointCount | null khi chưa hoàn tất hoặc raw>64; int0..64 khi cả tập thuộc miền key đã xử lý |
| duplicateCount | rawCount−endpointCount, chỉ EXACT0..64; số dư theo endpoint equivalence, không số textual tuples giống hệt |
| ipv4Rows/ipv6Rows | raw rows theo family, tổng==rawCount khi COMPLETE; không unique IP count |
| evidence/reason | COMPLETE/OK cho arithmetic hoàn tất; PARTIAL/RAW_CAP,ROW_INVALID,DEADLINE,IPC_CAP,MISSING còn null |

Raw>64 không scan/count family/unique; rawCount65 chỉ lower bound. Resolver lỗi/trước return/childkill/IPCcap không suy raw0 từ answers[], ghi UNKNOWN/null. Khi row invalid, không xuất prefix partial counts hoặc nối dòng chứa lỗi. count COMPLETE có thể xuất hiện cùng helperERROR/resolutionFAIL vì đây là số lượng, không acceptance. countsA của private fixture có thể COMPLETE về key arithmetic trong khi guardFAIL; không dùng stats làm public-IP verdict.

Wire tương lai: helper append counts vào cùng IPC object; parent observer whitelist/version kiểm, outer/nested cùng helper phải exact cùng stats/schema/policy/cap; timing hai điểm không ép bằng nhau. Old observer valid() yêu cầu exact keys nên không tự nhận v2; giữ nguyên v1 lịch sử và chỉ thêm validator v2 trong successor mới. StatusERROR/ANSWER_CAP không bị đổi thànhOK; decoded answers/guard/transport không lấy từ stats. Thiếu/mâu thuẫn stats phải PARTIAL và chặn nghiệm thu/dọn only-owned output, không sửa raw trước hoặc ghép stats từ request khác.

Giữ total setup10/metadata30/prepare60, HTTP connect10/read20clamp và process containment. Count scan kiểm cùng deadline trước/trong/sau; hết thời gian không cố hoàn tất, không thêm thời gian cho diagnostics. Không đổi helperINPUT16KiB/OUTPUT32KiB/answers64/threads1/pipes/group/inheritance, memory512+96=608MiB của pipeline. A không chứng minh được unique của source đang overcap: muốn nghiên cứu telemetry rộng hơn cần proposal riêng về bounded inspection, không tự thêm trong bước triển khai tiếp.

## Kết quả thực và phạm vi chứng minh

Runner mới labs/tiktok/dns-answer-research/run.ps1; một cached image31742091…dfa417e/network-none/96MiBCPU.25/UID65534/pids64/swapRAM/RO/privateIPC/capALL/NNP/nohostports. Integration/helper/vendor/trace/research mount read-only, output riêng. Container timeout30s là containment test; không sửa setup10 của runtime. Một container, không tạo network, không DNS tên nguồn, claim/allocation/worker/source0.

**63ca PASS, native test/container0**, Docker start−attach03:20:26.413→03:20:29.609UTC (10:20:26→29VN),3.20s gồm attach/runtime, không benchmark model hay deadline nguồn. Current helper25 function calls với getaddrinfo giả, không native child exits; input/output cap function20 đúng kỳ vọng.8 native helper processes dùng accepted dns_case: numeric0/PASS; deadline−15/cancel−15; oversize0/PARTIAL; answers65 fixture0/COMPLETE nhưng resolutionFAIL; crash20; primary trace0/PARTIAL+identitytrue; missing trace0/PARTIAL. Tất cả reaped/pipesclosed/group0/nochildleft; FD4→4/thread1→1 toàn harness. Native0 của harness nghĩa kiểm đúng kỳ vọng, không biến child−15/20 thành DNS PASS.

Đã kiểm raw64unique64,65unique1,65unique65; IPv4/IPv6 duplicate/numeric normalization/mapped family; scope/proto/type/port/flow khác; private và invalid ở đầu/giữa/cuối vượt64 và trong64; invalid bounds/shape/zone/bool; raw66,empty; schema bool/negative/huge/sum/family/mode/version/missing/extra; overflow10000 không scan; deadline trước/giữa validate/dedup; IPC input/output/answer caps/incomplete/cancel/primarycleanup. Public HE4 simulations dùng socket_factory và documented loop.sock_connect với fake sockets: chuyển đúng fields, OSError identity, cancel, loser close; không socket TCP thật và không kernel/TLS equivalence assertion. Không chạy lại ma trận lịch sử.

Source423/runtime96/canonical **a5492e613c9f322f52dd8ef2c78aa586df947df833e7194912734c6277dc1c06**, gateSHA **88d03e9c65e9b2444044647ad6926545c354fff822d5f5df9f8da43897016221**, helperSHA1c50f575…239af giữ. Existing libraries/apps/transport/timeout/caps/images/main/humanreviews/claims/latch không sửa. History preservation kiểm1.549 code/manifest/verifier/golden/capability files +current audit/live raw121artifacts và737proofs qua existing gate; không gọi đây là fresh rehash toàn34.416raw lịch sử. AUDIT/PROGRESS chỉ chèn giữ original bytes bằng docs2-before substitution.

## Lệnh thực và bàn giao

Shell bundledpwsh7.6.5, cwd D:\WED SNAP, không cài toàn máy. Lệnh đã chạy:

```powershell
& 'C:\Users\LENOVO\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe' -NoProfile -File docs/evidence/tiktok-dns-answer-research-20261012/prepare.ps1
& 'C:\Users\LENOVO\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe' -NoProfile -File docs/evidence/tiktok-dns-answer-research-20261012/fetch-references.ps1
& 'C:\Users\LENOVO\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe' -NoProfile -File labs/tiktok/dns-answer-research/run.ps1
```

Prepare0; official-reference capture0 (6GET tới official raw GitHub, không source HTTP/DNS); runner0. record.ps1 sau fixture ghi snapshots/cleanup/assessment/docs insert; verify.ps1 -Seal rồi verify.ps1 khóa manifest/SHA và kiểm chỉ đọc, actual counters/exits/UTC-VN trong terminal receipts. Không lệnh source runner, build/pull/install/retry hoặc sửa golden trong phiên.

[Prompt triển khai diagnostics-only offline](evidence/tiktok-dns-answer-research-20261012/NEXT_PROMPT.md). File cần đổi ở bước sau là **bản successor** của dns_helper.py,dns_ipc.py,dns_diagnostic.py cùng finalizer/receipt-link validator/probes/runner-inventory; giữ base current lab nguyên byte. Bắt đầu review63fixture/schema/plan, rồi mới copy glue tối thiểu. Không copy nghiên cứu/parser/fixture vào application/runtime main, không đưa modelB65 vào policy, không gate nguồn mới. Nghiệm thu cần fresh narrow helper/IPC/cold/receipt contradictions và whole metadata→JPEG fixture cùng final hash, caps/deadline/policyC/SSRF/TLS/cleanup/native/protected ownership. Sau triển khai vẫn cần kiểm độc lập; không cấp review/authorization/claim cho source.
