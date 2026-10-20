# Cấu hình hạ tầng

Thư mục này chứa cấu hình Compose, env mẫu, security profiles và Docker recipes cho các lab lịch sử. Code tải media hiện ở `apps/media/`, code proxy ở `apps/egress/`; đây không còn là nơi đặt implementation ứng dụng.

Compose chính vẫn ở gốc dự án. Cấu hình lab phải dùng đúng project directory, env riêng, image/resource/ownership guards theo hướng dẫn của nó. Sắp xếp thư mục không cho phép thay security profile hay thao tác stack/dữ liệu chính.
