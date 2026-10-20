import Footer from './components/Footer';
import Header from './components/Header';
import { useSession } from './hooks/useSession';
import Admin from './pages/Admin';
import Home from './pages/Home';
import Legal from './pages/Legal';
import { useEffect } from 'react';
export default function App() {
  const { session, error } = useSession();
  const page = location.pathname.split('/')[1];
  useEffect(() => {
    document.title = `${session?.productName || 'WED SNAP'} · Tải nội dung được phép`;
  }, [session?.productName]);
  return (
    <>
      <Header productName={session?.productName} />
      <div id="main-content" tabIndex={-1}>{session ? (
        page === 'admin' ? (
          <Admin session={session} />
        ) : ['privacy', 'terms', 'report'].includes(page) ? (
          <Legal page={page} session={session} />
        ) : (
          <Home session={session} />
        )
      ) : (
        <main className="loading" role="status">
          {error || 'Đang kết nối phiên…'}
          {error && (
            <button className="secondary" onClick={() => location.reload()}>
              Thử lại
            </button>
          )}
        </main>
      )}</div>
      <Footer productName={session?.productName} />
    </>
  );
}
