# Bàn giao phương án DNS overcap — 12/10/2026

Đã lập và kiểm mô hình offline; **chưa sửa runtime hoặc gọi nguồn**. Chọn đề xuất
inspection256/250ms clamped theo helper deadline sau khi acceptance64 đã từ chối.
Fullscan65–256 mới có raw/endpoint/duplicate/family và enum public;>256/deadline/
memory/incomplete vẫn PARTIAL/UNKNOWN. Mọi overcap vẫn ANSWER_CAP/answers[]/FAIL.
Không kết luận dedup hoặc thay policy sẽ sửa TikTok.

[Phương án/so sánh/API/budgets](evidence/tiktok-dns-overcap-plan-20261012/PLAN.md),
[schema/truth/helperID/linkage](evidence/tiktok-dns-overcap-plan-20261012/SCHEMA.md),
[prompt triển khai offline tiếp](evidence/tiktok-dns-overcap-plan-20261012/NEXT_PROMPT.md).

Evidence mới chỉ chứa harness nghiên cứu/count glue, reuse accepted endpoint_key,
ipaddress/sys.getsizeof/monotonic/json và publicPopen/mock. CPython3.11.2/
HE2.7.1 exactrefs/pins/PSF licenses và Requests2.34.2/urllib3-2.8.0/yt-dlp2026.8.19
đã đối chiếu; không library/install/image mới, parser/resolver/HTTP/TLS không đổi.
Actual stdlib là Debian3.11.2-6+deb12u8/ipaddressSHA8fc7549e…5355e1, khác upstream;
[provenance](evidence/tiktok-dns-overcap-plan-20261012/STDLIB_PROVENANCE.md) ghi
failed verifier exit20/PSnative1/check2669 và actual captured file, không sửa
frozen upstream/old verifier. PublicState theo distro đã pin; source reconstruction
upstream+Debianpatch chưa kiểm toànbyte. Supplemental capture networknone/native0,
own container đãremove; totalown2containers/networkcreated0, không rerun302.
Official socket docs/C source web đọc thành công, HE remote InternalError dùng
frozen official commit copy; actual socket.py hash trùng reference.

302 fixturecases/container native0 trong networknone96MiBCPU.25UID65534RO, chưa
whole integration. 12samples worst256: max191.669ms/median176.200ms/peak71,100bytes/
retained89,304bytes, so96KiB retained/128KiB scratch proposal; bulk resolver input
allocation không đo/không bị count cap giới hạn. Proposed stats239bytes riêng,
combinedCOMPLETE452bytes, all-variants worst469bytes; counts+inspection≤512/IPC32KiB
phải gate khi triển khai.7fakechild
processes native0/20/−15 preservedFAIL, truncated/IPCcap/traceincomplete/cancel
reaped/pipesclosed/group0, FD4→4/thread1→1/primaryOSError identity giữ. Error enum
fixture không phải DNS lỗi thật. Source/claim/socket/worker0.

Lệnh thực chạy, bundledpwsh7.6.5 -NoProfile:

```powershell
cd 'D:\WED SNAP'
$taskPwsh='C:\Users\LENOVO\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe'
& $taskPwsh -NoProfile -File docs/evidence/tiktok-dns-overcap-plan-20261012/prepare.ps1
& $taskPwsh -NoProfile -File docs/evidence/tiktok-dns-overcap-plan-20261012/run.ps1 -Attempt 1
& $taskPwsh -NoProfile -File docs/evidence/tiktok-dns-overcap-plan-20261012/finish-closure.ps1
```

prepare native0/2339 hashchecks/protected1564/audit151/parent615,95source/93runtime
unchanged. run native1 tại inventorysaucleanup, container native0/test302/remove0;
giữ nguyên raw1, không overwrite completion hoặc rerun test. finish-closure native0
chứng minh own1container absent/no ownnetwork.13image/25oldcontainers/35volumes giữ,
27networkIDs unchanged,1missing+1new daemon defaultbridgeID/causeUNKNOWN được lưu;
không nói full network inventory bất biến. Không explicit networkmutation/hostfix.

Lệnh record.ps1 thực native0; verify.ps1 -Seal lỗi20/PSnative1 được giữ. Sau capture-
runtime.ps1 native0, record2.ps1 bổ sung docs; verify-final.ps1 -Seal FAIL20/PS1/check2676
do so COMPLETE222 với maxPARTIAL239 được giữ. record3.ps1 phân biệt COMPLETE452/
worst469bytes; verify-final2.ps1 -Seal và verify-final2.ps1 đọc-only, native exits/
checks cuối trong record3-completion/verification-final2 receipts riêng. Không test rerun.
AUDIT/PROGRESS chỉ chèn với docs-before substitution; historical manifests/goldens/
claims/humanreview/acceptedlabs/apps/vendor/images giữ. Renderer đã gỡ vẫnabsent.
Hai lỗi schema A vẫn CLOSED_OFFLINE_CONFIRMED theo audit trước; nghiên cứu mới
PENDING_INDEPENDENT_REVIEW. Không sourcegate/allocation/claim tạo/reset; task/
allocation consumed giữ. SourceảnhFAIL/noJPEG/visualNOT_REVIEWED, main/galleryOFF/
API E2E/deploy chưa chạy; video human2/3/sample3pending giữ.
