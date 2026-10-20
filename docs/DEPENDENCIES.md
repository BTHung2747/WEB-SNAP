# Phiên bản và giấy phép

Chốt 30/09/2026. Runtime không cài trên Windows. Dependencies JS khóa cả trực tiếp và bắc cầu trong `package-lock.json` (npm ci). Media Python khóa trong `apps/media/requirements.lock`; base images dùng tag phiên bản cụ thể. apt theo Debian Bookworm security repository, **chưa khóa snapshot apt**; phải ghi image digest và FFmpeg build khi phát hành production để tái tạo đầy đủ.

| Thành phần | Phiên bản chốt | Giấy phép chính |
|---|---|---|
| Node | 22.22.3 bookworm-slim | MIT + thành phần thứ ba |
| TypeScript | 5.9.2 | Apache-2.0 |
| React / React DOM | 19.1.1 | MIT |
| Vite | 7.3.6 | MIT |
| Tailwind | 3.4.17 | MIT |
| Nest core/common/platform-express | 11.2.7 | MIT |
| Nest Swagger | 11.4.7 | MIT |
| Prisma / Client | 6.19.0 | Apache-2.0 |
| BullMQ | 5.81.5 | MIT |
| ioredis | 5.7.0 | MIT |
| PostgreSQL image | 16.10-bookworm | PostgreSQL License |
| Redis image | 7.4.6-bookworm | RSALv2 / SSPLv1, không gọi là MIT/BSD |
| Python egress image | 3.12.12-slim-bookworm | PSF + image components |
| yt-dlp | 2026.08.19 | Unlicense source; có thành phần ISC/MIT khác |
| yt-dlp-ejs | 0.8.0 | Unlicense; kiểm tra notices gói khi phân phối |
| FFmpeg | Debian Bookworm package trong image | build Debian có GPL components; giữ notices/source obligations khi phân phối image |

Redis 7.4 áp dụng lựa chọn license riêng; bản local tự vận hành không bán dịch vụ Redis. Trước khi phân phối image/dịch vụ công khai, kiểm tra điều kiện license cho cách sử dụng cụ thể. Không tự đổi stack mà người dùng đã chốt.

Nguồn chính thức đã tham khảo:

- [Nest migration / Node requirements](https://docs.nestjs.com/migration-guide).
- [Vite getting started](https://vite.dev/guide/).
- [Prisma requirements và v6](https://docs.prisma.io/docs/orm/reference/system-requirements).
- [BullMQ stalled và concurrency](https://docs.bullmq.io/guide/workers/stalled-jobs), [concurrency](https://docs.bullmq.io/guide/parallelism-and-concurrency).
- [yt-dlp dependencies, proxy và FFmpeg](https://github.com/yt-dlp/yt-dlp), [release 2026.08.19](https://github.com/yt-dlp/yt-dlp/releases/tag/2026.08.19).
- [Redis license](https://redis.io/legal/licenses/), [FFmpeg legal](https://ffmpeg.org/legal.html).

Phải thử tải trên IP triển khai thật; extractor có tên nền tảng không phải bằng chứng tải được. Không dùng remote JS solver download tự động, cookie tài khoản hoặc DRM bypass.

Audit image/lockfile cuối01/10/2026:0 advisories. Overrides khóa Vite7.3.6, PostCSS8.5.28, js-yaml5.4.2, effect3.22.2/deepmerge-ts8.0.2 trong @prisma/config để vá dependency bắc cầu cùng major. Lockfile được tạo lại trong container sạch để loại package root cũ npm giữ. npm ci cài321 packages; audit đếm404 gồm optional/dev. Build/integration PASS sau thay đổi. Chưa scan OS/Python CVE; kiểm tra lại trước public.
