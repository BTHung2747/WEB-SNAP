import Footer from './components/Footer';
import Header from './components/Header';
import { useSession } from './hooks/useSession';
import Admin from './pages/Admin';
import Home from './pages/Home';
import Legal from './pages/Legal';
import Support from './pages/Support';
import PublicHome from './pages/PublicHome';
export default function App({ pathname = location.pathname }: { pathname?: string } = {}) {
  const { session, error } = useSession();
  const page = pathname.split('/')[1];
  const pageClass = page === 'admin' ? 'app-admin' : page === 'ung-ho' ? 'app-support' : ['privacy', 'terms', 'report'].includes(page) ? 'app-legal' : 'app-home';
  return (
    <div className={`app-shell ${pageClass}`}>
      <Header productName={session?.productName} />
      <div id="main-content" tabIndex={-1}>{page === 'ung-ho' ? <Support /> :
        ['privacy', 'terms', 'report'].includes(page) ? <Legal page={page} session={session} /> :
        page === '' ? session ? <Home session={session} /> : <PublicHome error={error} /> :
        page === 'admin' && session ? <Admin session={session} /> : page === 'admin' ? (
        <main className="loading" role="status">
          {error || 'Đang kết nối phiên…'}
          {error && (
            <button className="secondary" onClick={() => location.reload()}>
              Thử lại
            </button>
          )}
        </main>
      ) : <main className="legal"><h1>Không tìm thấy trang</h1><a href="/">Trở về WED SNAP</a></main>}</div>
      <Footer productName={session?.productName} />
    </div>
  );
}
