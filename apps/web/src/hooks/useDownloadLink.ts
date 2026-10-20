import { useCallback, useEffect, useState } from 'react';
import { api } from '../lib/api';
import type { Job } from '../types';

/** Mint the session-bound ticket before the user's click, then use a native link. */
export function useDownloadLink(job: Job | null, csrf: string) {
  const jobId = job?.state === 'ready' ? job.id : null;
  const [attempt, setAttempt] = useState(0);
  const [ticket, setTicket] = useState<{ jobId: string; url: string } | null>(null);
  const [error, setError] = useState('');
  const retry = useCallback(() => setAttempt((value) => value + 1), []);
  useEffect(() => {
    let active = true;
    setTicket(null);
    setError('');
    if (jobId) {
      api(`jobs/${jobId}/download-ticket`, csrf, 'POST')
        .then((response) => {
          if (active) setTicket({ jobId, url: response.url });
        })
        .catch((e: Error) => {
          if (active) setError(e.message);
        });
    }
    return () => {
      active = false;
    };
  }, [jobId, csrf, attempt]);
  return { url: ticket?.jobId === jobId ? ticket.url : null, error, retry };
}
