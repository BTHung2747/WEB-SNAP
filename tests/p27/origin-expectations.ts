// Independent supplementary route-specific controls, chosen BEFORE HTTP.
// Source: admin controller delete/logout -> production auth csrf(), Origin must match APP_ORIGIN.
export {sources,operationSuccess,requestDeadlineMs,responseMaxBytes} from './expectations';
export const maxRequests=12;
export const cases=[
 ['origin-fixture-bootstrap','GETsession200/login201/campaignPOST201 through production HTTP, real own fixtures'],
 ['delete-origin-missing-and-wrong','DELETE with valid admin+guest/headerCSRF but missing or wrong Origin403 CSRF_INVALID, DB/audit unchanged'],
 ['logout-origin-wrong','logout with valid admin+guest/bodyCSRF+extra and wrong Origin403 CSRF_INVALID, token retained'],
 ['origin-valid-cleanup-controls','same campaign DELETE200 with own Origin/bodyCSRF+extra; logout201 with own Origin/headerCSRF, token revoked'],
] as const;
