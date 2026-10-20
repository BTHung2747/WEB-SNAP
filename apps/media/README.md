# Bộ xử lý media

Code tải thật nằm trong `src/media_adapter.py`. Worker gọi adapter này cho hai pha analyze và prepare; adapter dùng yt-dlp để nhận dạng nguồn và FFmpeg/ffprobe khi cần. Nhánh YouTube giữ nguyên. Core TikTok mới ở `src/tiktok/`, mặc định tắt (TIKTOK_ADAPTER_ENABLED phải là1); chưa bật stack chính hoặc nghiệmthu nguồn/API E2E.

TikTok analyze/prepare là hai child riêng. Prepare trích xuất mới, xác minh Cobalt bodyID và format fingerprint từ metadata công khai; cookie/signed URL chỉ RAM, không giữ child hoặc lưu DB/tệp. Hợp đồng CLI/JSON/media.mp4 giữ; workflow URL dài≤2GETanalyze+2GETmetadataPrepare+1GETMP4. Shortlink fail closed, không tự resolve.

LICENSE/NOTICE/INTEGRATION/PROVENANCE ở src/tiktok giữ Cobalt AGPL-3.0/commit và thay đổi WED SNAP; npm lock giữ exact versions/SRI. Chỉ core/validator/vendor tối thiểu vào runtime; fixture ở labs/tiktok/app-integration.

`requirements.lock` giữ phiên bản Python dependencies. Dockerfile ở đây là runtime media, build từ gốc dự án. Đường dẫn adapter trong container được giữ `/app/infra/media_adapter.py` để tương thích worker/fixture.

Xem `../../docs/STRUCTURE.md` và `../../docs/ADAPTERS.md` trước khi thay đổi chính sách nền tảng, giới hạn hoặc cách tải.
