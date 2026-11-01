import { useEffect, useState } from 'react';
import Icon from './Icon';

/** Preview transport is API-owned. Never let platform/CDN URLs reach an image element. */
export function ownedPreviewUrl(value: string | null | undefined, jobId: string): string | null {
  if (!value) return null;
  try {
    const url = new URL(value, location.origin);
    const prefix = `/api/v1/jobs/${encodeURIComponent(jobId)}/preview`;
    if (url.origin !== location.origin || url.username || url.password || url.hash ||
      !(url.pathname === prefix || url.pathname.startsWith(prefix + '/'))) return null;
    return url.pathname + url.search;
  } catch { return null; }
}

export default function MediaPreview({ url, jobId, alt, compact = false }: {
  url?: string | null; jobId: string; alt: string; compact?: boolean;
}) {
  const safeUrl = ownedPreviewUrl(url, jobId);
  const [failed, setFailed] = useState(false);
  useEffect(() => setFailed(false), [safeUrl]);
  return <div className={`media-preview${compact ? ' compact' : ''}`}>
    {safeUrl && !failed
      ? <img src={safeUrl} alt={alt} loading={compact ? 'lazy' : 'eager'} decoding="async"
          referrerPolicy="no-referrer" onError={() => setFailed(true)} />
      : <div className="preview-unavailable"><Icon name="play" /><span>{compact ? 'Chưa có xem trước' : 'Ảnh xem trước chưa sẵn sàng'}</span>
          {!compact && <small>Bạn vẫn có thể chọn và chuẩn bị tệp.</small>}</div>}
  </div>;
}
