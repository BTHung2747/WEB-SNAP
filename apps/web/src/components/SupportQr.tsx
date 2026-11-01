import { useEffect, useState } from 'react';
export default function SupportQr({ url, alt }: { url: string | null; alt: string }) {
  const [failed, setFailed] = useState(false);
  useEffect(() => setFailed(false), [url]);
  return <div className="support-qr">
    {url && !failed ? <img src={url} alt={alt} onError={() => setFailed(true)} /> :
      <p>{url ? 'Không hiển thị được ảnh QR. Hãy tải lại trang hoặc dùng thông tin chuyển khoản bên dưới.' : 'Chưa có ảnh QR.'}</p>}
  </div>;
}
