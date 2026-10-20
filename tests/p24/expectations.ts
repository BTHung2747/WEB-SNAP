// Frozen BEFORE docs changes; independently transcribed from controllers/services,
// auth/validation/SafeErrors and plan1.1 sections6/7/9/10/13/14. Not imported from docs.
export const expected = [
  ['health','get','/api/v1/health',200,{500:['INTERNAL_ERROR']},'public'],
  ['session','get','/api/v1/session',200,{429:['RATE_LIMITED'],500:['INTERNAL_ERROR']},'public'],
  ['analyze','post','/api/v1/jobs/analyze',202,{400:['INVALID_REQUEST','INVALID_URL','UNSUPPORTED_PLATFORM','UNSUPPORTED_CONTENT'],403:['SESSION_REQUIRED','CSRF_INVALID'],429:['RATE_LIMITED','QUEUE_FULL'],503:['CAPACITY_UNAVAILABLE'],500:['INTERNAL_ERROR']},'header'],
  ['status','get','/api/v1/jobs/{id}',200,{400:['INVALID_REQUEST'],403:['SESSION_REQUIRED'],404:['JOB_NOT_FOUND'],410:['JOB_EXPIRED'],500:['INTERNAL_ERROR']},'cookie'],
  ['preview','get','/api/v1/jobs/{id}/preview',200,{400:['INVALID_REQUEST'],403:['SESSION_REQUIRED'],404:['JOB_NOT_FOUND'],410:['JOB_EXPIRED'],500:['INTERNAL_ERROR','INVALID_ASSET_PATH']},'cookie'],
  ['prepare','post','/api/v1/jobs/{id}/prepare',202,{400:['INVALID_REQUEST','FORMAT_UNAVAILABLE','UNSUPPORTED_PLATFORM'],403:['SESSION_REQUIRED','CSRF_INVALID'],404:['JOB_NOT_FOUND'],409:['IDEMPOTENCY_CONFLICT'],410:['JOB_EXPIRED'],429:['RATE_LIMITED','QUEUE_FULL'],503:['CAPACITY_UNAVAILABLE'],500:['INTERNAL_ERROR']},'header'],
  ['heartbeat','post','/api/v1/jobs/{id}/heartbeat',201,{400:['INVALID_REQUEST'],403:['SESSION_REQUIRED','CSRF_INVALID'],404:['JOB_NOT_FOUND'],410:['JOB_EXPIRED'],500:['INTERNAL_ERROR']},'body-or-header'],
  ['release','post','/api/v1/jobs/{id}/release',201,{400:['INVALID_REQUEST'],403:['SESSION_REQUIRED','CSRF_INVALID'],404:['JOB_NOT_FOUND'],500:['INTERNAL_ERROR']},'body-or-header'],
  ['cancel','post','/api/v1/jobs/{id}/cancel',201,{400:['INVALID_REQUEST'],403:['SESSION_REQUIRED','CSRF_INVALID'],404:['JOB_NOT_FOUND'],410:['JOB_EXPIRED'],500:['INTERNAL_ERROR']},'body-or-header'],
  ['ticket','post','/api/v1/jobs/{id}/download-ticket',201,{400:['INVALID_REQUEST'],403:['SESSION_REQUIRED','CSRF_INVALID'],404:['JOB_NOT_FOUND'],410:['JOB_EXPIRED'],429:['RATE_LIMITED'],500:['INTERNAL_ERROR']},'body-or-header'],
  ['download-get','get','/api/v1/downloads/{ticket}',200,{403:['SESSION_REQUIRED'],410:['JOB_EXPIRED'],416:['INVALID_RANGE'],429:['RATE_LIMITED'],503:['CAPACITY_UNAVAILABLE'],500:['INTERNAL_ERROR','INVALID_ASSET_PATH']},'cookie'],
  ['download-head','head','/api/v1/downloads/{ticket}',200,{403:['SESSION_REQUIRED'],410:['JOB_EXPIRED'],416:['INVALID_RANGE'],429:['RATE_LIMITED'],500:['INTERNAL_ERROR']},'cookie'],
] as const;
export const states=['analyzing','selectable','queued','preparing','ready','failed','cancelled','expired'];
export const jobKeys=['id','state','errorCode','title','duration','metadataAcceptedAt','metadataExpiresAt','items','previewUrl','mode','serverMeaning'];
export const sessionKeys=['csrf','supported','verified','contact','productName','heartbeatSeconds'];
export const sourceRefs={health:'session.service.ts:health',session:'session.service.ts:createSession',jobs:'jobs.service.ts/status/preview/prepare/heartbeat/release/cancel/ticket',download:'downloads.service.ts:HEAD branch before budget/lease',validation:'validation.ts + auth/session.ts + safe-errors.filter.ts',plan:'1.1 sections6/7/9/10/13/14'};
