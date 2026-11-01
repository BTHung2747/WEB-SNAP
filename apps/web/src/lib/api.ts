export const messages: Record<string, string> = {
  FIXTURE_URL_NOT_SIMULATED: 'Link này chưa được bản minh họa mô phỏng. Chỉ dùng link TikTok canonical /photo/ hoặc /video/; bản local không gọi nguồn thật.',
  INVALID_URL: 'Link chưa hợp lệ. Hãy dán đường dẫn HTTPS đến một bài đăng.',
  UNSUPPORTED_PLATFORM: 'Nền tảng này chưa được bật sau kiểm chứng tải thật.',
  UNSUPPORTED_CONTENT: 'Loại nội dung này chưa được hỗ trợ.',
  CONTENT_UNAVAILABLE: 'Không lấy được nội dung. Bài có thể đã xóa hoặc nguồn đang chặn truy cập.',
  AUTH_REQUIRED: 'Nội dung cần đăng nhập hoặc có giới hạn truy cập. Chỉ hỗ trợ bài công khai.',
  FORMAT_UNAVAILABLE: 'Định dạng này không còn khả dụng. Hãy phân tích lại link.',
  RATE_LIMITED: 'Bạn gửi yêu cầu quá nhanh. Vui lòng thử lại sau một phút.',
  QUEUE_FULL: 'Đang có nhiều yêu cầu. Vui lòng thử lại sau.',
  LIMIT_EXCEEDED: 'Nội dung vượt giới hạn dung lượng hoặc thời lượng.',
  SOURCE_TIMEOUT: 'Nguồn phản hồi quá lâu. Hãy thử lại sau.',
  JOB_EXPIRED: 'Tác vụ đã hết hạn. Phân tích lại link để tiếp tục.',
  CAPACITY_UNAVAILABLE: 'Hệ thống đang tạm ngừng nhận thêm tải. Hãy thử lại sau.',
  WORKER_INTERRUPTED: 'Xử lý đã bị gián đoạn. Hãy tạo lại tác vụ.',
  CSRF_INVALID: 'Phiên đã thay đổi. Tải lại trang rồi thử lại.',
  LOGIN_FAILED: 'Email hoặc mật khẩu không đúng.',
  INVALID_REQUEST: 'Thông tin chưa hợp lệ. Kiểm tra các trường rồi thử lại.',
  SUPPORT_QR_INVALID: 'Ảnh QR không hợp lệ. Chọn PNG hoặc JPEG rõ nét, kích thước tối đa 2.048 × 2.048 pixel.',
  SUPPORT_QR_LIMIT: 'Ảnh QR vượt giới hạn 2 MiB. Hãy chọn ảnh nhỏ hơn.',
  SUPPORT_UPLOAD_BUSY: 'Máy chủ đang xử lý một ảnh QR. Vui lòng thử lại sau.',
  SUPPORT_UPLOAD_TIMEOUT: 'Tải hoặc kiểm tra QR quá lâu. Vui lòng thử lại.',
  SUPPORT_PAYMENT_REQUIRED: 'Để bật trang, cần có QR hoặc đủ ngân hàng, chủ tài khoản và số tài khoản.',
  SUPPORT_LOCAL_FILE: 'Ảnh vừa chọn chưa tải lên. Tải ảnh lên bản chờ hoặc bỏ ảnh trước khi Lưu.',
  SUPPORT_TEXT_INVALID: 'Nhập tiêu đề và lời kêu gọi bằng văn bản thuần, không dùng mã HTML hoặc ký tự điều khiển.',
  SESSION_REQUIRED: 'Phiên đã hết hạn. Vui lòng tải lại trang.',
  PLATFORM_NOT_VERIFIED: 'Nền tảng chưa có bằng chứng kiểm chứng P0.',
};
export class ApiError extends Error {
  constructor(public code: string, public status?: number) {
    super(messages[code] || `Không xử lý được yêu cầu (${code}).`);
  }
}
/** Only these status/code pairs mean the old job may safely be discarded. */
export function isMissingJob(error: unknown): error is ApiError {
  return error instanceof ApiError &&
    ((error.status === 404 && error.code === 'JOB_NOT_FOUND') ||
      (error.status === 410 && error.code === 'JOB_EXPIRED'));
}
export async function api(url: string, csrf: string, method = 'GET', body?: unknown) {
  const r = await fetch('/api/v1/' + url, {
    method,
    credentials: 'same-origin',
    headers: {
      'Content-Type': 'application/json',
      ...(method !== 'GET' ? { 'x-csrf-token': csrf } : {}),
    },
    ...(body !== undefined ? { body: JSON.stringify(body) } : {}),
  });
  const data = await r.json();
  if (!r.ok) throw new ApiError(data.error?.code || 'INTERNAL_ERROR', r.status);
  return data;
}
