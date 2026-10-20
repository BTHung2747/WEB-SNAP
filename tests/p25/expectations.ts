// Independent source/plan expectations frozen before any production documentation edit.
// Parser status is deliberately measured: audit had not exercised this image.
export const filterCases = [
  ['app-validation', 'app', 400, 'INVALID_REQUEST'],
  ['app-session', 'app', 403, 'SESSION_REQUIRED'],
  ['app-owner', 'app', 404, 'JOB_NOT_FOUND'],
  ['app-expiry', 'app', 410, 'JOB_EXPIRED'],
  ['app-rate', 'app', 429, 'RATE_LIMITED'],
  ['app-capacity', 'app', 503, 'CAPACITY_UNAVAILABLE'],
  ['http400', 'http', 400, 'INTERNAL_ERROR'],
  ['http403', 'http', 403, 'INTERNAL_ERROR'],
  ['http404', 'http', 404, 'NOT_FOUND'],
  ['http500', 'http', 500, 'INTERNAL_ERROR'],
  ['unknown', 'error', 500, 'INTERNAL_ERROR'],
] as const;
export const id = '11111111-1111-4111-8111-111111111111';
export const token = 'a'.repeat(64);
export const targets = [
  ['health','GET','/api/v1/health','/api/v1/health'],
  ['session','GET','/api/v1/session','/api/v1/session'],
  ['analyze','POST','/api/v1/jobs/analyze','/api/v1/jobs/analyze'],
  ['status','GET','/api/v1/jobs/{id}','/api/v1/jobs/'+id],
  ['preview','GET','/api/v1/jobs/{id}/preview','/api/v1/jobs/'+id+'/preview'],
  ['prepare','POST','/api/v1/jobs/{id}/prepare','/api/v1/jobs/'+id+'/prepare'],
  ['heartbeat','POST','/api/v1/jobs/{id}/heartbeat','/api/v1/jobs/'+id+'/heartbeat'],
  ['release','POST','/api/v1/jobs/{id}/release','/api/v1/jobs/'+id+'/release'],
  ['cancel','POST','/api/v1/jobs/{id}/cancel','/api/v1/jobs/'+id+'/cancel'],
  ['ticket','POST','/api/v1/jobs/{id}/download-ticket','/api/v1/jobs/'+id+'/download-ticket'],
  ['download-get','GET','/api/v1/downloads/{ticket}','/api/v1/downloads/'+token],
  ['download-head','HEAD','/api/v1/downloads/{ticket}','/api/v1/downloads/'+token],
] as const;
export const parserPolicy = {
  malformedJson: { allowedObservedStatuses: [400,500], code:'INTERNAL_ERROR', evidence:'production Nest parser/filter; exact observed status saved, no forced400' },
  malformedUri: { allowedObservedStatuses:[400,500], code:'INTERNAL_ERROR', evidence:'router decoding before own/controller; no invented route status' },
  validNoCookie:{status:403,code:'SESSION_REQUIRED',datastoreCalls:0},
  headers:{cache:'no-store',contentType:'application/json',helmet:'nosniff'},
  limits:{timeoutMs:4000,maxResponseBytes:2048,requestBytes:256},
};
export const scope = 'production SafeErrors unit / Nest-Express parser HTTP loopback only; no lifecycle, DB, platform, main or success HTTP';
