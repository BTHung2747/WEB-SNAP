export default function Footer({ productName = 'WED SNAP' }: { productName?: string }) {
  return (
    <footer>
      <a href="/" className="brand small">
        {productName === 'WED SNAP' ? <>WED<span className="brand-light">SNAP</span></> : productName}
      </a>
      <p>Lưu nội dung bạn có quyền sử dụng.</p>
      <div>
        <a href="/terms">Điều khoản</a>
        <a href="/privacy">Quyền riêng tư</a>
        <a href="/report">Báo cáo nội dung</a>
        <a href="/ung-ho">Ủng hộ</a>
        <a href="/admin">Quản trị</a>
      </div>
    </footer>
  );
}
