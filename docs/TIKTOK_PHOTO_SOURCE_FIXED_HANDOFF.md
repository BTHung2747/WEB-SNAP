# Bộ chạy nguồn kế tiếp — chỉ chuẩn bị/offline15/10/2026

**PASS_FIXED_SOURCE_RUNNER_PREPARATION_PENDING_REVIEW**. Đã có runner cụ thể dùng đồng thời DNSchildfix và diagnostic completenessfix; chưa chạy nguồn, chưa xin quyềnnguồn. sourceGrantNew=false/sourceRequestsNew=0. Lượt source-1 cũ vẫn FAIL_NO_FILE và không được retry/reuse. Không apps/UI/main/settings/schema/Compose/env/host/deps/image/transport thay đổi.

## Tái sử dụng và wiring

Successor `labs/tiktok/photo-source-fixed/`6file: run.ps1, mounts.ps1, source-pins.json, tool-dependencies.json, probe.ps1, wiring_probe.py. Không sao30file lab hoặc dựng wholeharness. Vì runner frozen không có seam đổi entry/mount/evidence, chỉ fork riêng orchestrator run.ps1 với diff bàn giao; code không được biến đổi/eval lúc thực thi. Native orchestration/timeouts/guard/DBRedis/cleanup kế thừa, không sửa runnerfrozen. Không đổi workflow/worker/media hoặc chạy lại wholeworkflow do không đổi integrationflow.

Appreadonly `/lab` lấy `photo-app-source-executor/common/`16file: sourceentry/driver/workflow/worker/media/collector/selection/supervisor/start.sh nguyênbyte. API/BullMQ/production processJob/runAdapter/ProcessGroup/gate3b/photo core/Requests/Cobalt/FFmpeg giữbyte. Media entrymount tới đường fixed `/app/infra/media_adapter.py` và sources readonly như trước.

Proxyreadonly `/lab` lấy `photo-dns-diagnostics-fix/`3file, `/base` lấy `photo-dns-child-offline/common/`17file, sourcevendor `/repo/apps/egress`. Command `python3 -I /lab/overlay_entry.py`. bind canonicalproxy_collect chọn module diagnosticsP2 mới, proxy_entry đúngbaseDNSfix. Entrybase configure PYTHONPATH hai source/vendor paths cho productionDNSchild; không chỉ sys.pathparent. No `/offline`/fixtureDNS/TCP/CA/body/sitecustomize/envhooks trong đường nguồn. Shared ProxyMounts() được cả future runner và probe gọi, không lặp đíchmount `/repo/apps/egress`; roleproxy không cộng repoMountsapp.

Pin128source trong source-pins.json và **36file frozen có thể truy cập qua3common/overlaymounts** trong tool-dependencies.json, không chỉ3wrapper. Từng fileactualhash kiểm trước sourceattempt/resources, dryrun cũng đọc và kiểmpins. Toàn bộ6filesuccessor cùng36frozen +128source nằm trong fingerprint/manifest bàn giao. Binary/dependencies trong4imagecontentIDs pinned, sourcevendor/license/notice/lockfile hiện hành giữ; khônginstall/pull/build. Runtime mountedmodulepins khác imagepackagepin; không nói import6module là kiểm mọi binarydependency.

## Lệnh và mặc định khóa nguồn

PowerShell7 tại D:\WED SNAP:

```powershell
& ./labs/tiktok/photo-source-fixed/run.ps1
& ./labs/tiktok/photo-source-fixed/run.ps1 -DryRun
& ./labs/tiktok/photo-source-fixed/probe.ps1 -Probe 1
```

Đã chạy: defaultdeny native78 trước pins/secrets/attemptdir/Docker/network; dryrun0 sau kiểm128+36pins, chỉ in config/mount/entry và không tạo runtimefolder. ParsePowerShell đạt. Probe1 actual0 networknone, owncontainercleanup0.6765864s/left0/no networkcreated. Không bật ExecuteSource hoặc STEP5_EXECUTE_SOURCE=1 trong nhiệm vụ này.

Lệnh nguồn **chỉ được chuẩn bị, CHƯA CHẠY**, dùng sau review và nhiệm vụ nguồn mới riêng của chủ:

```powershell
& ./labs/tiktok/photo-source-fixed/run.ps1 -ExecuteSource
```

Chỉ một namespace mới `docs/evidence/tiktok-photo-source-fixed-runtime-20261015/source-once`, hiện chưa có. Không tham sốAttempt, không fallback/increment; tồn tại namespace thì refuse. Không ghi thêm runtime vào gói chuẩn bịsealed hoặc source-1 cũ. ExecuteSource là switch thực thi đơn giản, không tự tạo frameworkclaim/cold/approval; lệnh trong tài liệu không cấp quyền nguồn. DryRun luôn khôngsideeffect kể cả thấy switch; nhiệm vụ này chỉ gọi DryRun khôngswitch.

## Probe wiring thực

Cachedproxy8bc0a567…7f10 inspect/create `--pull=never`, Python3.12.12/cwd/app/user65534,96MiB/CPU.25/PIDs96/networknone/RO/dropALL/NNP/privateIPC/noextraswap/noports, outer28s/child8s. Probe dùng sharedreadonlyProxyMounts, thêm `/probe` chỉ chứa công cụ đo; không nguồnflag hoặc fixture. Import có thể thực thi module code nhưng không gọi server/mainnguồn hoặc DNSpublic.

Actualpath/hash: overlay `/lab/overlay_entry.py` SHA78388f…3403; collector `/lab/proxy_collect.py` SHAa532b7…98ef; baseentry `/base/proxy_entry.py` SHAf83e3a…6370; configure `/base/dns_child_environment.py` SHA5f56ed…9e7c. Canonical import và configure thật đã gọi. ChildpublicPopen import6module tiktok_policy/package/dns_helper/dns_ipc/dns_admission/runtime/aiohappyeyeballs, đúng `/repo/apps/egress/src` hoặcvendor và từngSHA128source. Childexit0; nativehelper `{}` exit20/response0/reaped, **chỉ từchốiinvalidschema trước DNS**, không DNSnetworkPASS. Directoverlayentry missingflag actual78; parentbind path thực, không là giả lậpfilepath.

Probe dùng Python executable alias `python`, futureorchestrator kế thừa `python3` trong cùng pinnedimage. Version3.12.12 được đo; không dùng probeimport thay bằng chứng futuremain/server/sourcemetadata/file. Source topology2mạng/appDBRedis/phasegate/runtimeworkflow sauwiring **NOT_RUN** tronglượt này, không chạy wholematrix89/10/6/14/3 hoặc fixtureflow mới. Các kết quả fixture/gate/decode trước vẫnhistorical, không gọi thành testmới.

## Giới hạn giữ nguyên và dừng

Canonical `https://www.tiktok.com/@adne_la.veil/photo/7678209751167110421`, index2/1job/1analyzechild+1freshpreparechild; freshsummary/bodyID/count5/order/dimensions/itemKeys/snapshot exact, descriptor mới. ≤2+2+conditional1sourceGET/HEADredirectretry0/khôngảnhkhác/fallback. HistoricalSHA mismatch giữfilehost/dừngNEEDS_REVIEW/no retry; hashkhớp cũng cần reviewfilemới, không dùng5ảnhhumanacceptedcũ thay.

App512/proxy96/PG128/Redis64 tổng800MiB vàCPU/PIDs/nonrootRO/dropALL/NNP/privateIPC/noextraswap/noports/tmpfs/media64 kế thừa. Metadata30/prepare180/HTTPconnect10/read20/item60/whole250/queue10/local20/appcleanup20/Dockercleanup20/watchdog360; caps/SSRF/TLS/DNSraw256→unique64/policyC/ownership/ProcessGroup/gate3b giữ. Future appPGRedisinternal, proxyonlydedicatedegress, exactcontrolCIDRlocal+peer/newsecretRAM sanitized. Sourcefail/UNKNOWN/metadatachanged/native/group/proof/deadline/delta/cachemissing/cleanupmissing đều dừng, không retry/requeue/restart.

Probe chỉcache96MiB tuần tự RAM8GB; chưa đo peakRSS hoặc sourceguardsruntime800mới. Log whitelist/numeric/opaqueIDs/no URLpathquery/token/cookie/header/HTML/message/repr/stack giữ; wireGETUNKNOWN khácattempt/status/decodedBytes/CONNECT. Không sửa diagnosticsP2 đãreview, chỉ nối mountentry.

Evidence `docs/evidence/tiktok-photo-source-fixed-20261015/`: orchestrator diff/provenance/source+36tooldeps+6successorhash/snapshots/rawnative/probe/deny/dryrun/read-onlyverifier/manifest và NEXT_PROMPTreview. AUDIT/PROGRESS prepend latestreceipt bảo toànUIprototype. Chưa nguồn/appE2E/file/watermarkPASS, chưadeploy/main/gallery; không xin nguồn trong chatcode trướcreview.
