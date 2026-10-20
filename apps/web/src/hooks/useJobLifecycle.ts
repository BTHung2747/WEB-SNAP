import { useCallback, useEffect, useRef } from 'react';
import { api, isMissingJob } from '../lib/api';
import type { Job } from '../types';

/** Page ownership is independent of the server's transfer lease. */
export function useJobLifecycle(
  jobId: string | null, tracking: boolean, csrf: string,
  onJob: (job: Job) => void, onError: (error: Error, missing: boolean) => void,
) {
  const current = useRef<string | null>(null);
  const callbacks = useRef({ jobId, tracking, onJob, onError });
  callbacks.current = { jobId, tracking, onJob, onError };
  const stopCurrent = useRef<() => void>(() => {});
  const stop = useCallback(() => stopCurrent.current(), []);
  useEffect(() => {
    if (!jobId || !tracking) return;
    let live = true;
    const isCurrent = () => live && callbacks.current.jobId === jobId && callbacks.current.tracking;
    current.current = jobId;
    const stopTracking = () => {
      live = false;
      current.current = null;
      clearInterval(poll);
      clearInterval(beat);
      window.removeEventListener('pagehide', release);
      window.removeEventListener('pageshow', restore);
      document.removeEventListener('visibilitychange', restore);
    };
    stopCurrent.current = stopTracking;
    const failure = (error: Error) => {
      if (!isCurrent()) return;
      const missing = isMissingJob(error);
      if (missing) stopTracking();
      callbacks.current.onError(error, missing);
    };
    const check = () => {
      if (!isCurrent()) return;
      api(`jobs/${jobId}`, csrf).then((job: Job) => {
        if (!isCurrent()) return;
        if (['failed', 'cancelled', 'expired'].includes(job.state)) stopTracking();
        callbacks.current.onJob(job);
      }).catch(failure);
    };
    const renew = () => {
      if (isCurrent()) api(`jobs/${jobId}/heartbeat`, csrf, 'POST').catch(failure);
    };
    const release = () => {
      if (live) {
        navigator.sendBeacon(
          `/api/v1/jobs/${jobId}/release`,
          new Blob([JSON.stringify({ csrf })], { type: 'application/json' }),
        );
      }
    };
    const restore = () => renew();
    const poll = setInterval(check, 2000);
    const beat = setInterval(renew, 15000);
    window.addEventListener('pagehide', release);
    window.addEventListener('pageshow', restore);
    document.addEventListener('visibilitychange', restore);
    check();
    return () => {
      release();
      stopTracking();
    };
  }, [jobId, tracking, csrf]);
  return { current, stop };
}
