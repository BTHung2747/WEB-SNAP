import { useEffect, useRef } from 'react';
import { api } from '../lib/api';
import type { Ad } from '../types';
import Icon from './Icon';
export default function Advertising({
  ad,
  csrf,
  onClose,
}: {
  ad: Ad;
  csrf: string;
  onClose?: () => void;
}) {
  const ref = useRef<HTMLElement>(null);
  const sent = useRef(new Set<string>());
  const campaign = useRef(ad.id);
  campaign.current = ad.id;
  useEffect(() => {
    let live = true;
    let timer: ReturnType<typeof setTimeout> | undefined;
    let ratio = 0;
    const clear = () => {
      if (timer !== undefined) clearTimeout(timer);
      timer = undefined;
    };
    const eligible = () => {
      if (!live || campaign.current !== ad.id) return;
      if (ratio < 0.5 || document.hidden || sent.current.has(ad.id)) {
        clear();
        return;
      }
      if (timer === undefined)
        timer = setTimeout(() => {
          timer = undefined;
          if (!live || campaign.current !== ad.id || ratio < 0.5 || document.hidden || sent.current.has(ad.id)) return;
          sent.current.add(ad.id);
          api('ad-events', csrf, 'POST', {
            id: crypto.randomUUID(),
            campaignId: ad.id,
            type: 'impression',
          }).catch(() => {});
        }, 1000);
    };
    const io = new IntersectionObserver(
      (entries) => {
        if (!live || campaign.current !== ad.id || !entries[0]) return;
        ratio = entries[0].intersectionRatio;
        eligible();
      },
      { threshold: [0, 0.5, 1] },
    );
    if (ref.current) io.observe(ref.current);
    document.addEventListener('visibilitychange', eligible);
    return () => {
      live = false;
      io.disconnect();
      clear();
      document.removeEventListener('visibilitychange', eligible);
    };
  }, [ad.id, csrf]);
  return (
    <aside ref={ref} className="advert">
      <div className="ad-label">
        TÀI TRỢ{' '}
        {onClose && (
          <button className="icon-btn" onClick={onClose} aria-label="Đóng tài trợ">
            <Icon name="close" />
          </button>
        )}
      </div>
      {ad.imageUrl && <img src={ad.imageUrl} alt="" referrerPolicy="no-referrer" />}
      <div>
        <strong>{ad.title}</strong>
        <a
          href={ad.targetUrl}
          target="_blank"
          rel="sponsored noopener noreferrer"
          onClick={() => {
            api('ad-events', csrf, 'POST', {
              id: crypto.randomUUID(),
              campaignId: ad.id,
              type: 'click',
            }).catch(() => {});
          }}
        >
          Xem nội dung tài trợ ↗
        </a>
      </div>
    </aside>
  );
}
