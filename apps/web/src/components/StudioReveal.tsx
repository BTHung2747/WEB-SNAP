import { useEffect, useRef, type ReactNode } from 'react';

/** Presentation only: content stays visible without observer support or motion. */
export default function StudioReveal({ children, className }: { children: ReactNode; className: string }) {
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const element = ref.current;
    if (!element || typeof IntersectionObserver !== 'function' || typeof matchMedia !== 'function') return;
    const preference = matchMedia('(prefers-reduced-motion: reduce)');
    let observer: IntersectionObserver | undefined;
    let seen = false;
    let live = true;
    const stop = () => { observer?.disconnect(); observer = undefined; };
    const observe = () => {
      stop();
      if (!live || preference.matches || seen) return;
      observer = new IntersectionObserver((entries) => {
        if (!live || seen || preference.matches || !entries.some(entry => entry.isIntersecting)) return;
        seen = true;
        element.classList.add('studio-revealed');
        stop();
      }, { threshold: .12 });
      observer.observe(element);
    };
    preference.addEventListener('change', observe);
    observe();
    return () => {
      live = false;
      stop();
      preference.removeEventListener('change', observe);
      element.classList.remove('studio-revealed');
    };
  }, []);
  return <div ref={ref} className={className}>{children}</div>;
}
