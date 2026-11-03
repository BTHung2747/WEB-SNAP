import { createRoot, hydrateRoot } from 'react-dom/client';
import App from './App';
import './style.css';
import './styles/admin.css';
import './styles/home.css';
import './styles/layout.css';
import './styles/legal.css';
import './styles/responsive.css';
import './styles/support.css';
import './styles/feedback.css';
const root = document.getElementById('root')!;
// Production has build-time public markup; dev still starts with an empty root.
const adminEntry = document.querySelector('meta[name="wed-snap-page"]')?.getAttribute('content') === 'admin';
if (root.hasChildNodes()) hydrateRoot(root, <App adminEntry={adminEntry} />);
else createRoot(root).render(<App adminEntry={adminEntry} />);
