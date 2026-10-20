// Independent source/plan matrix; not imported from builder or snapshot.
export const bounds:Record<string,[number,number]>={
  maxDuration:[1,600],maxBytes:[1024,209715200],maxInputBytes:[1024,262144000],
  analyzeTimeout:[5,30],prepareTimeout:[10,180],sessionTtl:[5,3600],releaseGrace:[1,120],
  readyTtl:[5,600],sweepSeconds:[1,30],leaseTtl:[30,90],retryGrace:[1,120],
  transferMax:[5,1800],monthlyBytes:[0,Number.MAX_SAFE_INTEGER],diskStopPercent:[10,80],queueLimit:[1,20],
};
export const operations=[
  ['ads','get','/api/v1/ads',200,'AdsSelection',{},'guest'],
  ['ad-event','post','/api/v1/ad-events',201,'OkResponse',{400:['INVALID_REQUEST'],403:['SESSION_REQUIRED','CSRF_INVALID'],404:['CAMPAIGN_UNAVAILABLE'],429:['RATE_LIMITED']},'guest-write'],
  ['login','post','/api/v1/admin/login',201,'OkResponse',{400:['INVALID_REQUEST'],403:['SESSION_REQUIRED','CSRF_INVALID','LOGIN_FAILED'],429:['RATE_LIMITED']},'guest-write'],
  ['logout','post','/api/v1/admin/logout',201,'OkResponse',{403:['SESSION_REQUIRED','CSRF_INVALID']},'guest-fallback'],
  ['dashboard','get','/api/v1/admin/dashboard',200,'AdminDashboard',{403:['ADMIN_REQUIRED']},'admin'],
  ['settings-get','get','/api/v1/admin/settings',200,'AdminLimits',{403:['ADMIN_REQUIRED']},'admin'],
  ['settings-put','put','/api/v1/admin/settings',200,'AdminLimits',{400:['INVALID_REQUEST','PLATFORM_NOT_VERIFIED'],403:['SESSION_REQUIRED','CSRF_INVALID','ADMIN_REQUIRED']},'admin-write'],
  ['campaign-list','get','/api/v1/admin/campaigns',200,'AdminCampaignList',{403:['ADMIN_REQUIRED']},'admin'],
  ['campaign-create','post','/api/v1/admin/campaigns',201,'AdminCampaign',{400:['INVALID_REQUEST'],403:['SESSION_REQUIRED','CSRF_INVALID','ADMIN_REQUIRED']},'admin-write'],
  ['campaign-update','put','/api/v1/admin/campaigns/{id}',200,'AdminCampaign',{400:['INVALID_REQUEST'],403:['SESSION_REQUIRED','CSRF_INVALID','ADMIN_REQUIRED']},'admin-write'],
  ['campaign-delete','delete','/api/v1/admin/campaigns/{id}',200,'OkResponse',{400:['INVALID_REQUEST'],403:['SESSION_REQUIRED','CSRF_INVALID','ADMIN_REQUIRED']},'admin-fallback'],
] as const;
// GET ads missing-cookie branch, separate from readonly admin.
export const adsErrors={403:['SESSION_REQUIRED']};
export const id='11111111-1111-4111-8111-111111111111';
export const campaign={title:'Fixture contract',imageUrl:null,targetUrl:'https://example.invalid/ad',linkType:'sponsored',placement:'banner',enabled:true,startsAt:'2026-10-03T00:00:00.000Z',endsAt:'2026-10-04T00:00:00.000Z',weight:1};
export const limits={...Object.fromEntries(Object.entries(bounds).map(([k,[min]])=>[k,min])),acceptJobs:true,enabledPlatforms:['youtube']};
export const schemaNames=['AdminLoginInput','AdminCampaignInput','AdminCampaign','AdminCampaignList','AdminLimits','AdsSelection','AdEventInput','AdminDashboard'];
