export default function Header({ productName = 'WED SNAP' }: { productName?: string }) {
  return (
    <><a className="skip-link" href="#main-content">Bỏ qua đến nội dung</a><header className="nav" itemScope itemType="https://schema.org/WebSite">
      <meta itemProp="name" content="WED SNAP" /><meta itemProp="alternateName" content="WEDSNAP" /><link itemProp="url" href="https://savlivo.online/" />
      <a href="/" className="brand">
        <span className="brand-icon" aria-hidden="true">w.</span>
        {productName === 'WED SNAP' ? (
          <>
            WED<span className="brand-light">SNAP</span>
          </>
        ) : (
          productName
        )}
      </a>
      <nav aria-label="Điều hướng">
        <a href="/#how">Cách sử dụng</a>
        <a href="/privacy">Quyền riêng tư</a>
        <a href="/ung-ho">Ủng hộ</a>
        <a className="nav-status" href="/#support">
          Nền tảng
        </a>
      </nav>
    </header></>
  );
}
