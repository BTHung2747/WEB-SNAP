import { api, ApiError } from './api';

export type SupportFields = {
  enabled: boolean;
  title: string;
  message: string;
  bankName: string;
  accountName: string;
  accountNumber: string;
  transferNote: string;
};
export type PublicSupport = { enabled: false } | (SupportFields & { enabled: true; qrUrl: string | null });
export type AdminSupport = SupportFields & { qrUrl: string | null; qrPending: boolean };
export const qrByteLimit = 2 * 1024 * 1024;

// Assets are API-owned; never render a configurable external URL or server path.
export function supportQrUrl(value: string | null, admin = false): string | null {
  if (!value) return null;
  const prefix = admin ? '/api/v1/admin/support/qr/' : '/api/v1/support/qr/';
  return value.startsWith(prefix) && /^[a-f0-9]{64}$/.test(value.slice(prefix.length)) ? value : null;
}
export function supportFields(data: SupportFields): SupportFields {
  return {
    enabled: data.enabled, title: data.title, message: data.message,
    bankName: data.bankName, accountName: data.accountName,
    accountNumber: data.accountNumber, transferNote: data.transferNote,
  };
}
export function getPublicSupport(): Promise<PublicSupport> { return api('support', ''); }
export function getAdminSupport(csrf: string): Promise<AdminSupport> { return api('admin/support', csrf); }
export function saveSupport(data: SupportFields, csrf: string): Promise<AdminSupport> {
  return api('admin/support', csrf, 'PUT', supportFields(data));
}
export function removeSupportQr(csrf: string): Promise<AdminSupport> { return api('admin/support/qr', csrf, 'DELETE'); }
export async function uploadSupportQr(file: File, csrf: string, signal: AbortSignal): Promise<AdminSupport> {
  const body = new FormData();
  body.append('file', file);
  const response = await fetch('/api/v1/admin/support/qr', {
    method: 'POST', credentials: 'same-origin', signal,
    headers: { 'x-csrf-token': csrf }, body,
  });
  const data = await response.json();
  if (!response.ok) throw new ApiError(data.error?.code || 'INTERNAL_ERROR', response.status);
  return data;
}
