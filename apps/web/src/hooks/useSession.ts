import { useEffect, useState } from 'react';
import { api } from '../lib/api';
import type { Session } from '../types';
export function useSession() {
  const [session, setSession] = useState<Session | null>(null);
  const [error, setError] = useState('');
  useEffect(() => {
    api('session', '')
      .then(setSession)
      .catch((e) => setError(e.message));
  }, []);
  return { session, error };
}
