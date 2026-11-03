export const feedbackKinds = {feedback: 'Góp ý', bug: 'Báo lỗi', idea: 'Đề xuất'};
export const feedbackStatuses = {unread: 'Chưa đọc', read: 'Đã đọc', resolved: 'Đã xử lý'};
export type FeedbackKind = keyof typeof feedbackKinds;
export type FeedbackStatus = keyof typeof feedbackStatuses;
export type FeedbackRow = {id: string; kind: FeedbackKind; subject: string; name: string | null; status: FeedbackStatus; createdAt: string};
export type FeedbackDetail = FeedbackRow & {message: string; email: string | null};
export type FeedbackList = {items: FeedbackRow[]; page: number; pages: number; total: number; pageSize: number};
