# Runbook local và vận hành

## Shutdown ownlab36: await sweep đang chạy, main chưa apply

Chỉmain.ts sửa saubaselineproductionFAIL: hủy/chặn timer mới, awaitactiveSweep rồiđóngworker/DB/Redis. CùngmatrixV4 9PASS2FAIL→11PASS/exit0; tail expiredSession gone khiactualchildcònstateR, fresh/admin/settings/charged37 giữ. HeldPGlock313.265ms, nhả346.862ms sausignal, exit13.949ms saurelease, postexit4110.537ms khôngchange. Idlecontrol riêngPASS. Giữsource default30/concurrency1/TTL/batches/cleanup; khôngapplystackchính.

README6.25 hướngdẫn ownlab36/cached3services800MiB/internal/privatePID/source-rootfsRO/noports;DBwed_snap_worker_shutdown_test/Redis9/serverriêng/privateclienttmpfs/4existingmigrationsonlyownDB. Fixture2s/effective2 khácdefault30; khôngjob/transfer/API/browser/Internet. Không dùng2s/boundedwindow đểnhậnload/SLA/defaultmain/shutdownlivejobs/fullR10/P3/P4/public/P0–P6.

Matrixfinally cleanup đúngownIDs/knownqueuekeys/sentinels/locks/children/nativeclients/media vớiidentityguard; charged37 trướccleanup/allmodelskeys0/nonrecursiveownmediarmdir. **Own36Stop kiểmStores+Empty rồistop-removecontainers**, giữvolumes/network/raw; khôngcleanupfixture thayMatrix. Ngắttrướcfinally/nonempty thì giữfinding và xácminhownidentity, khôngreset/flush/down-v/prune/bypassguard/chuyểnmain. Labđãremoved17:03:27.894Zexit0. RawFAIL/harnesscorrections/baseline/final/typecheck/offlinephânbiệttrongTEST_REPORT.

35đãaudit nghiệmthu scoped11/F35.H1đóng/frozen61+65giữ;36chờaudit. Successor36 chỉ6currentdocs+exactmainrevisionbackedbybaselineFAIL, mọiproductionkhác/frozen19–35giữ; khôngsửaoldverifier/manifestđểép liveSHA.

## Entrypoint ownlab35: fixture2s, main/default30 chưa kiểm nhận

Production không đổi. Ownlab35 chạy child đúng `apps/worker/src/main.ts`:11controls PASS, startup500 trước ready/timer500 rồi1; periodic ownPG rowlock4273.065ms/81samples chỉmộtDELETE trong cửa sổ đo. SIGTERM idle actualexit0/connectionsclosed, không shutdown-inflight/livejobs. Fixture SWEEP_SECONDS2/effective2 khác source default30/concurrency1; không nhận cadence main/load/SLA/toànR10/P3/P4/P0–P6/public.

README6.24 có lệnh Start/Matrix/Typecheck/Stop/verifier riêng35; noports/internal/privatePID/source-rootfsRO/3cachedservices800MiB/noAPI-browser-Internet-mainmounts. DBwed_snap_worker_scheduler_test/Redis10 server riêng,4existing migrations/privateclienttmpfs chỉownlab. RawFAIL PIDs64/native thread ceiling+cgroupmax2/OOM0 giữ; ownlabPIDs192 final11PASS/typecheck/max0/OOM0, không đổi host/production.

Matrix finally+post-Empty mới là proof ownfixtures/media sạch; Stop chỉ guardconfig/identity rồi stop/remove đúngown3, giữvolumes/network/raw. Ngắt trướcfinally có thể cònfixture dù StopPASS; không reset/flush/down-v/prune/chuyển main. Successor35 chỉ6currentdocs exemptions/production0, giữ accepted34 current4/64artifacts/frozen19–34/Composeaccepted33; verifier là offline proof, không rerun runtime lịch sử. **34 đãnghiệmthu/F34.H1đóng;35đã audit nghiệm thu scoped.**

Offline capture35 exit0 UTC12:52:53.252,61artifacts; actual coverage/hash đối chứng exit0 UTC12:53:46.806. Live-doc completion/supplement sau frozen sourcecopies giữ riêng; không sửa oldsnapshot để ép currentdocSHA. 35 đã audit scoped; main chưa apply.

## Policy mới34: retention worker.metrics, main chưa apply

Chỉ AuditLog actor=`worker` VÀ action=`worker.metrics` có TTL30×24h UTC: strict createdAt<cutoff, tối đa500/sweep theo createdAt/id; delete recheck actor/action/cutoff trên đúng ids. Nhật ký quản trị và nhóm khác không có TTL mới này. Không loop purge toàn backlog. AdEvent30ngày và vòng đời job/lease/media giữ nguyên. Source thêm composite index `[actor,action,createdAt,id]`; migration `202610040001_worker_metrics_retention_index` chỉ CREATE INDEX, **mới apply ownlab34/main chưa apply**.

Ownlab34 đã13PASS với PG thực/helper clock fixture và sweep production gọi thủ công clock thật; ba row-lock race recheck giữ row. Không thử startup/timer scheduler/load/SLA hoặc live job/lease. Settings/charged37 sentinel giữ; cleanup finally/post-Empty xác nhận ownmodel/key/media sạch, rồi Stop đúngcontainers và giữ volumes/network/raw. Stop không tự kiểm datastore rỗng hoặc cleanup fixture sau crash. README6.23 hướng dẫn test riêng, không chuyển main hoặc reset/flush/down-v/prune để chạy lại.

34 đã kiểm toán độc lập nghiệm thu scoped13PASS/F34.H1coverage đóng64artifacts;33 scoped source logging6services10m/3 +probe64k/3;32/F31.1 đóng,31scoped giữ. Đây là lịch sử không rerun35;35chờaudit riêng ở đầu. Main/public/toànR10/P4/P0–P6 chưa nhận. Verifier34 chỉ đọc proof/hash, giữ verifier/manifests lịch sử nguyên trạng.

## Docker logs: policy cấp dự án33, main chưa áp dụng/kiểm chứng

Compose source dùng policy chung `json-file` với `max-size: '10m'`, `max-file: '3'` đủ api/worker/web/postgres/redis/egress. Đây là policy cấp container trong project, không sửa daemon.json/OS/Docker Desktop. Source thay đổi không tự áp dụng vào container hiện hữu; phiên33 không start/recreate main và không đọc LogConfig main/default daemon. Không kết luận log hiện tại unlimited/diskfull. Việc áp dụng main phải nằm trong maintenance được giao riêng; không làm trong33.

Driver rotate và loại logs cũ theo policy, nên Docker logs không phải lưu trữ lịch sử vĩnh viễn. Không dùng `rm`/Remove-Item/truy cập trực tiếp daemon log files để vận hành, không reset/flush/down-v/prune. Không coi10m×3 là hard diskcap toàn project: overhead, nhiều services và policy daemon/container thực cần đo riêng. Tài liệu driver: [Docker JSON File logging driver](https://docs.docker.com/engine/logging/drivers/json-file/).

Ownlab33 chỉ một Node container cached/network:none/rootfsRO/privatePID/usernode/96MiB/CPU0.25/PIDs32, noports/datastores/worker/media/data volumes. Probe **64k/3**, khác threshold10m/3 source: writer actualexit0/drain,524468bytes; đọc **logs --tail all** còn suffix355–512(158records)+completion, đầu1–354 mất. Không chứng nhận chính xác3physical files/runtime10m/main/load/SLA. Capture proof trước stop/remove owncontainer; raw/evidence host giữ. Failed attempts guard/harness và cleanup-only được tách khỏi rotation PASS.

Kiểm offline bàn giao33 (không gọi engine/main, không rerun31/32):

```powershell
cd "D:\WED SNAP"
powershell -NoProfile -File scripts/verify-log-rotation-evidence.ps1
if ($LASTEXITCODE -ne 0) { throw 'Successor33 hash/policy/proof mismatch' }
```

Successor33 giải thích exemption đúng currentcompose/docs được phép khi đối chiếu inventory lịch sử; không exempt frozen copies/manifests/tests/expected/runtime app16. Không sửa oldvalidator/manifest cho khớp currentcompose, không dùng CaptureSnapshot để ghi đè.32đã nghiệm thu/F31.1đóng,31retention scoped giữ;33đã nghiệm thu độc lập scoped. Sau sửa schema/lifecycle34 dùng successor34; verifier33 lịch sử/current runtime hashes giữ, không ép oldmanifest. Các lệnh vận hành chung bên dưới không được thực thi trong phiên33.

## Kiểm tra, restart, rollback

```powershell
cd "D:\WED SNAP"
docker compose ps
docker compose logs --tail 100 api worker
docker stats --no-stream
Invoke-RestMethod 'http://localhost:5173/api/v1/health'
```

Không đưa `.env`, cookie, signed URL hoặc DB dump lên nơi công khai. Log ứng dụng không in URL nguồn. API hiển thị mã lỗi ổn định; dashboard không trả sourceUrl hoặc path.

Restart worker sau sửa adapter, hoặc restart API khi lỗi runtime. Dừng nhận tác vụ trong admin trước maintenance. Cho transfer hiện tại hoàn tất trước khi dừng API: restart API sẽ ngắt socket, client phải retry trong grace nếu còn hạn. Không dùng restart như thao tác dọn file đang truyền.

Rollback: lưu tag image hiện tại trước upgrade; backup DB; migrate tương thích lùi trước nếu schema thay đổi. Không tự rollback schema bằng reset. Khi thay migration không tương thích, restore bản sao DB riêng rồi kiểm chứng trước khi đổi live.

## Disk đầy, sweeper lỗi, hàng đợi

1. Tắt `acceptJobs` trong admin, giữ API chạy để transfer hiện tại hoàn tất.
2. Kiểm tra disk trong worker và stats, không xóa volume.
3. Xem lỗi `sweep_failed`; kiểm tra DB/Redis còn healthy, restart worker để đối soát.
4. Chỉ dọn tài sản đã `deleting`, không có TransferLease `started` chưa hết hạn, bằng sweeper có khóa DB. Không `Remove-Item`/`rm` trực tiếp media đang hoạt động.
5. Worker khôi phục outbox, đối soát crash/processUntil; job stalled không được chạy trùng vì workerToken. Retry tối đa một lần ở HTTP extractor/download cho lỗi network; business job không auto retry vô hạn.
6. Dọn mồ côi UUID sau 1 giờ; metadata terminal sau 24 giờ. Tệp probe P0 trong docs/evidence là artifact nghiên cứu do operator giữ, không thuộc media volume/sweeper; tự lưu/loại bỏ khi không cần.

```powershell
cd "D:\WED SNAP"
docker compose exec worker python3 -c "import shutil; print(shutil.disk_usage('/media'))"
docker compose restart worker
```

## Backup CSDL

Backup chứa dữ liệu quản trị, phải cất ngoài Git và bảo vệ quyền truy cập. Không đưa secret vào lệnh. `pg_dump` dùng kết nối nội bộ container. Xuất file binary qua `docker cp` để tránh PowerShell làm đổi encoding:

```powershell
cd "D:\WED SNAP"
New-Item -ItemType Directory -Force .\backups | Out-Null
docker compose exec -T postgres pg_dump -U wed_snap -d wed_snap -Fc -f /tmp/wed-snap.dump
docker compose cp postgres:/tmp/wed-snap.dump .\backups\wed-snap.dump
```

Đặt tên backup theo ngày nếu muốn giữ nhiều bản. Không cần backup media tạm. Redis AOF phục vụ phục hồi queue, DB vẫn là nguồn metadata/outbox. `.env` backup riêng trong nơi bảo mật để restore môi trường; không chia sẻ.

## Kiểm tra restore trên môi trường riêng

**Không chạy pg_restore --clean trên CSDL thật.** Dừng stack chính giảm RAM, dùng `wed-snap-restore` với volumes riêng và không bật worker/web. Quy trình dưới đây phải dùng file override restore tạo sẵn trong infra:

```powershell
cd "D:\WED SNAP"
docker compose stop
docker compose -f compose.yaml -f infra/compose.restore.yaml up -d postgres
docker compose -f compose.yaml -f infra/compose.restore.yaml cp .\backups\wed-snap.dump postgres:/tmp/restore.dump
docker compose -f compose.yaml -f infra/compose.restore.yaml exec -T postgres pg_restore -U wed_snap -d wed_snap --no-owner /tmp/restore.dump
docker compose -f compose.yaml -f infra/compose.restore.yaml exec -T postgres psql -U wed_snap -d wed_snap -c 'SELECT count(*) FROM "AdminUser";'
docker compose -f compose.yaml -f infra/compose.restore.yaml stop
docker compose up -d --no-build
```

Restore target phải là CSDL trống của project restore; nếu đã restore một lần, tạo target khác sau khi kiểm tra tên volume. Không overwrite bản đã restore hoặc volume production. Thử đăng nhập bản sao admin và đối soát campaign/settings trước P6. Lưu kết quả restore trong PROGRESS.

## Ngân sách dữ liệu

Dashboard đọc EgressBudget theo tháng UTC; charged gồm số byte đã đưa vào pipeline + reservation đang truyền/crash. Trần ngân sách chặn request mới trước khi đọc tệp, không ngắt request hợp lệ đang hoạt động. Set `monthlyBytes=0` để chặn download mới mà không xóa file đang truyền. Mốc tháng UTC là quyết định kỹ thuật để đồng bộ các container.

Ước lượng dữ liệu ≈ lượt tải × dung lượng trung bình × hệ số retry. Ghi cả CPU, RAM, thời gian worker, input byte, disk và error code. Counter ứng dụng không phải số tính phí; đối soát hóa đơn VPS. Direct chưa bật nên chưa có dữ liệu direct cần phân biệt. Chưa có kênh cảnh báo bên ngoài; chỉ logs/dashboard, phải bổ sung monitor ở P5.

## Tắt adapter khẩn cấp

Trong admin, bỏ chọn nền tảng hoặc tắt nhận tác vụ. Analyze mới bị chặn; worker kiểm tra lại enabledPlatforms trước bắt đầu xử lý. Transfer đã có lease tiếp tục. Muốn gỡ nền tảng khỏi cổng kiểm chứng, sửa VERIFIED_PLATFORMS trong `.env`, recreate API/worker; settings không thể vượt cổng này. Không dùng cookie/token khách để cứu extractor hỏng.

