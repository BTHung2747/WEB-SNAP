import type { Format } from '../types';
// Source default is explicit metadata; ordering/bitrate do not invent a default.
export function initialSourceFormat(formats: Format[]): string {
  return formats.find(f => f.sourceDefault)?.id || formats.find(f => f.highest)?.id || formats[0]?.id || '';
}
