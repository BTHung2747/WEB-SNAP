export const messages: Record<string, string> = {
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
