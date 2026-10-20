import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import type { OpenAPIObject } from '@nestjs/swagger';
import type { INestApplication } from '@nestjs/common';
import type { SchemaObject, OperationObject, ResponseObject } from '@nestjs/swagger/dist/interfaces/open-api-spec.interface';

/** Shared by the API and offline generator; no listen or business method calls. */
export function createOpenApiDocument(app: INestApplication) {
  const doc = SwaggerModule.createDocument(app,
    new DocumentBuilder().setTitle('WED SNAP').setVersion('0.1.0')
      .addCookieAuth('ws_session')
      .addApiKey({ type: 'apiKey', in: 'header', name: 'x-csrf-token' }, 'csrf').build());
  describeContracts(doc);
  return doc;
}

/** Describe the explicit cookie/CSRF guards and manual streaming responses. */
export function describeContracts(doc: OpenAPIObject) {
  // Per-document state: legacy streaming descriptions extend this header map.
  // Never carry those additions into the next factory call's early responses.
  noStore = { 'Cache-Control': header('Global API middleware; lỗi/JSON/HEAD không cache.', { type: 'string', enum: ['no-store'] }) };
  doc.components ??= {};
  doc.components.securitySchemes ??= {};
  doc.components.securitySchemes.adminCookie = { type: 'apiKey', in: 'cookie', name: 'ws_admin' };
  for (const [path, item] of Object.entries(doc.paths)) {
    for (const method of ['get', 'head', 'post', 'put', 'delete'] as const) {
      const operation = item[method];
      if (!operation) continue;
      const mutation = ['post', 'put', 'delete'].includes(method);
      const publicRoute = path.endsWith('/health') || path.endsWith('/session');
      const adminRoute =
        path.includes('/admin/') && !path.endsWith('/login') && !path.endsWith('/logout');
      operation.security = publicRoute
        ? []
        : adminRoute && !mutation
          ? [{ adminCookie: [] }]
          : [
              {
                cookie: [],
                ...(mutation ? { csrf: [] } : {}),
                ...(adminRoute ? { adminCookie: [] } : {}),
              },
            ];
      if (mutation) {
        operation.description =
          `${operation.description || ''}\nOrigin phải khớp APP_ORIGIN; x-csrf-token từ GET /api/v1/session.${path.endsWith('/release') ? ' Beacon release cũng nhận csrf trong JSON body.' : ''}`.trim();
      }
      if (method === 'post' && (path.endsWith('/analyze') || path.endsWith('/prepare'))) {
        operation.responses = {
          '202': {
            description: 'Tác vụ được tiếp nhận; poll GET /jobs/:id để đọc kết quả',
            content: {
              'application/json': {
                schema: {
                  type: 'object',
                  required: ['jobId'],
                  properties: {
                    jobId: { type: 'string', format: 'uuid' },
                    ...(path.endsWith('/prepare') ? { state: { type: 'string' } } : {}),
                  },
                },
              },
            },
          },
        };
      }
      if (path.includes('/downloads/')) {
        const binary =
          method === 'head'
            ? {}
            : {
                content: { 'video/mp4': { schema: { type: 'string' as const, format: 'binary' } } },
              };
        operation.responses = {
          '200': { description: 'MP4; HEAD chỉ trả headers', ...binary },
          '206': {
            description: 'Một byte Range hợp lệ; Content-Range và Accept-Ranges',
            ...binary,
          },
          '403': { description: 'Không có phiên hợp lệ' },
          '410': { description: 'Ticket/tệp hết hạn hoặc không thuộc phiên' },
          '416': { description: 'Range không hợp lệ; Content-Range: bytes */size' },
          '429': { description: 'Vượt rate limit' },
          '503': { description: 'Vượt ngân sách truyền mới' },
        };
        operation.parameters ??= [];
        operation.parameters.push({
          name: 'Range',
          in: 'header',
          required: false,
          schema: { type: 'string' },
          example: 'bytes=0-99',
        });
      }
      const rateDescription = path.endsWith('/session')
        ? 'Tạo mới tối đa 10 phiên/60 giây/IP trước insert; cookie phiên hợp lệ không dùng hạn mức tạo.'
        : path.endsWith('/download-ticket')
          ? 'Cấp tối đa 10 ticket/60 giây/phiên và 5 ticket/60 giây/job; một ticket dùng nhiều Range.'
          : path.endsWith('/analyze')
            ? '10 yêu cầu/60 giây/phiên và 30/60 giây/IP. RATE_LIMITED khác QUEUE_FULL (admission).'
            : path.endsWith('/login')
              ? '5 lần đăng nhập/300 giây/IP, dùng chung qua nhiều cookie phiên.'
              : null;
      if (rateDescription) {
        operation.description = `${operation.description || ''}\n${rateDescription}`.trim();
        operation.responses['429'] = {
          description: path.endsWith('/analyze')
            ? 'RATE_LIMITED hoặc QUEUE_FULL; phân biệt bằng error.code'
            : 'RATE_LIMITED: vượt hạn mức',
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['error'],
                properties: {
                  error: {
                    type: 'object',
                    required: ['code'],
                    properties: {
                      code: {
                        type: 'string',
                        enum: path.endsWith('/analyze')
                          ? ['RATE_LIMITED', 'QUEUE_FULL']
                          : ['RATE_LIMITED'],
                      },
                    },
                  },
                },
              },
            },
          },
        };
      }
    }
  }
  describePublicContracts(doc);
  describeAdminAdsContracts(doc);
  describeAdStatisticsContract(doc);
}

function describeAdStatisticsContract(doc: OpenAPIObject) {
  doc.components!.schemas!.AdminAdStatistics = object({
    window: object({ from: {type:'string',format:'date-time'}, to: {type:'string',format:'date-time'}, timezone: {type:'string',enum:['UTC']} }),
    rows: {type:'array',items:object({campaignId:uuid,title:{type:'string'},impressions:{type:'integer',minimum:0},clicks:{type:'integer',minimum:0},ctrPercent:{type:'number',minimum:0,nullable:true,description:'clicks / impressions *100; null khi impressions0. Không clamp100.'}})},
  });
  const o=doc.paths['/api/v1/admin/ad-statistics']?.get;
  if(!o)throw Error('Ad statistics route missing');
  o.summary='Thống kê quảng cáo theo cửa sổ UTC';
  o.description='AdminCookie chỉ; không guest/Origin/CSRF, không ghi DB/audit. from/to cùng có hoặc cùng bỏ, scalar ISOdatetime có timezone và ngày tồn tại, chuẩn hóa UTC; [from,to), from<to, tối đa90x24h. Mặc định7x24h đến server now, trả window thực đã dùng. Reject duplicate/array/unknown query400 INVALID_REQUEST. Đếm AdEvent.createdAt/type impression hoặc click, đủ các campaign hiện có kể cả disabled/0events; không phải doanh thu/lượt xem nền tảng.';
  o.security=[{adminCookie:[]}];
  o.parameters=['from','to'].map(name=>({name,in:'query' as const,required:false,schema:{type:'string' as const,format:'date-time',maxLength:64},description:'Cùng có/cùng bỏ với tham số kia; ISO có timezone. Không array/duplicate.'}));
  o.responses={'200':success('AdminAdStatistics','Window UTC và rows; rows[] nếu chưa có campaign'),...errors({'400':['INVALID_REQUEST'],'403':['ADMIN_REQUIRED'],'500':['INTERNAL_ERROR']}),default:{description:'SafeErrors giữ status HttpException;404 NOT_FOUND, status khác INTERNAL_ERROR; không giả định mọi parser fault400.',headers:noStore,content:{'application/json':{schema:ref('ApiError')}}}};
  for (const response of Object.values(o.responses)) {
    (response as ResponseObject).headers = { 'Cache-Control': structuredClone(noStore['Cache-Control']) };
  }
}

/** Documentation only: exact admin/ads paths. Public24/25 schemas remain unchanged. */
function describeAdminAdsContracts(doc: OpenAPIObject) {
  const string: SchemaObject={type:'string'};
  const date: SchemaObject={type:'string',format:'date-time'};
  const integer=(minimum:number,maximum?:number):SchemaObject=>({type:'integer',minimum,...(maximum===undefined?{}:{maximum})});
  const https: SchemaObject={type:'string',format:'uri',maxLength:2048,description:'HTTPS refinement production: URL protocol https:, không userinfo/port còn lại sau URL normalization; loại localhost/127./10./192.168./169.254./IPv6 literal theo validation.ts. HTTPS: và :443 chuẩn hóa có thể được nhận; không chứng nhận DNS/SSRF/redirect. OpenAPI3 không biểu diễn hết refinement này.'};
  const campaignInput=object({title:{type:'string',minLength:1,maxLength:120},imageUrl:{...https,nullable:true},targetUrl:https,linkType:{type:'string',enum:['sponsored','affiliate']},placement:{type:'string',enum:['banner','sponsor']},enabled:{type:'boolean'},startsAt:date,endsAt:date,weight:integer(1,100)},['title','targetUrl','linkType','placement','enabled','startsAt','endsAt','weight']);
  const campaignOutput=object({id:string,title:string,imageUrl:{type:'string',nullable:true},targetUrl:string,linkType:string,placement:string,enabled:{type:'boolean'},startsAt:date,endsAt:date,weight:{type:'integer'}});
  campaignOutput.description='Prisma AdCampaign row; dates serialize ISO. Persisted string/weight/title/URL không tự bị giới hạn lại theo input validator. Không events/audit/password.';
  const limits=object({
    maxDuration:integer(1,600),maxBytes:integer(1024,209715200),maxInputBytes:integer(1024,262144000),
    analyzeTimeout:integer(5,30),prepareTimeout:integer(10,180),sessionTtl:integer(5,3600),releaseGrace:integer(1,120),
    readyTtl:integer(5,600),sweepSeconds:integer(1,30),leaseTtl:integer(30,90),retryGrace:integer(1,120),transferMax:integer(5,1800),
    monthlyBytes:integer(0,Number.MAX_SAFE_INTEGER),diskStopPercent:integer(10,80),queueLimit:integer(1,20),acceptJobs:{type:'boolean'},
    enabledPlatforms:{type:'array',maxItems:4,items:{type:'string',enum:['youtube','tiktok','facebook','x']},description:'PUT chỉ nhận phần tử thuộc env VERIFIED_PLATFORMS; GET filters bằng verified. Zod enum/max4 không thay thế guard service động.'},
  });
  const count=integer(0),bytes:SchemaObject={type:'string',pattern:'^-?[0-9]+$',description:'String(BigInt); không JSON number, không tự áp trần/unsigned khi DB không constraint.'};
  const array=(items:any):SchemaObject=>({type:'array',items});
  Object.assign(doc.components!.schemas!,{
    AdminLoginInput:object({email:{type:'string',format:'email',maxLength:254},password:{type:'string',minLength:12,maxLength:256,writeOnly:true}}),
    AdminCampaignInput:{...campaignInput,'x-production-refinements':['startsAt < endsAt','HTTPS URL refinement in validation.ts; not fully expressible in OpenAPI3']} as any,
    AdminCampaign:campaignOutput,
    AdminCampaignList:array(ref('AdminCampaign')),
    AdminLimits:{...limits,'x-enabled-platforms':'Mọi enabledPlatforms phải thuộc VERIFIED_PLATFORMS khi PUT; guard service động, lỗi PLATFORM_NOT_VERIFIED. Không giả định schema enum là danh sách đã kiểm chứng.'} as any,
    AdsSelection:{...object({id:string,title:string,imageUrl:{type:'string',nullable:true},targetUrl:string,linkType:string,placement:{type:'string',enum:['banner','sponsor']}}),nullable:true,description:'Campaign projection hoặc null. placement do query branch chọn; linkType persisted string, không tự enum theo input.'},
    AdEventInput:object({id:uuid,campaignId:uuid,type:{type:'string',enum:['impression','click']}}),
    AdminDashboard:object({
      groups:array(object({state:string,_count:count})),
      leases:array(object({state:string,_count:count,_sum:object({bytes})})),
      budget:array(object({month:string,charged:bytes})),
      failed:array(object({id:string,platform:string,errorCode:{type:'string',nullable:true},updatedAt:date})),
      events:array(object({campaignId:string,type:string,_count:count})),queue:object({waiting:count,active:count}),verified:array(string),
    }),
  });
  const frameworkDescription='SafeErrors: AppError giữ status/code; HttpException giữ getStatus(),404→NOT_FOUND/status khác→INTERNAL_ERROR; unknownError500. Envelope chỉ error.code. Parser admin/ads chưa được HTTP đo trong phần26, không khẳng định mọi malformed request400 hoặc gán mọi HttpException status cho từng route. HeadersSent chỉ destroy.';
  // AppError lists document service branches, not an exhaustive enum of framework
  // codes. Generic safe envelope avoids excluding e.g. HttpException code at the
  // same status. No invented missing-row404 or parser-specific status is added.
  const adminErrors=(map:Record<string,string[]>):Record<string,any>=>({...Object.fromEntries(Object.entries({...map,'500':['INTERNAL_ERROR']}).map(([status,codes])=>[status,{description:(status==='500'?'Unexpected/datastore exception không map thành404. ':'AppError branches: '+codes.join(', ')+'. ')+frameworkDescription,headers:noStore,'x-app-error-codes':codes,content:{'application/json':{schema:ref('ApiError')}}}])),default:{description:frameworkDescription,headers:noStore,content:{'application/json':{schema:ref('ApiError')}}}});
  const operation=(path:string,method:'get'|'post'|'put'|'delete')=>{
    const o=doc.paths[path]?.[method];if(!o)throw Error('Admin/ads docs route missing '+path+' '+method);
    o.parameters=[];if(path.includes('{id}'))o.parameters.push({in:'path',name:'id',required:true,schema:uuid,description:'UUID campaign, validation trước admin(); missing row không có AppError404 mapping.'});return o as OperationObject & Record<string,any>;
  };
  const mutation=(o:OperationObject & Record<string,any>,admin:boolean,fallback=false)=>{
    const primary={cookie:[],csrf:[],...(admin?{adminCookie:[]}:{})};o.security=fallback?[primary,{cookie:[],...(admin?{adminCookie:[]}:{})}]:[primary];
    o.parameters!.push({in:'header',name:'Origin',required:true,schema:string,description:'Phải khớp APP_ORIGIN.'},{in:'header',name:'x-csrf-token',required:!fallback,schema:csrf,description:fallback?'Header hoặc csrf body còn bắt buộc; header có giá trị ưu tiên.':'Header bắt buộc cho success: auth có body fallback nhưng strict schema từ chối extra csrf.'});
    o.description+=' Cookie guest + Origin/CSRF'+(admin?' và adminCookie.':' ; không bắt buộc adminCookie.');
    if(fallback){o.requestBody={required:false,content:{'application/json':{schema:ref('CsrfFallbackBody')}}};o['x-csrf-alternatives']=['header:x-csrf-token','body:csrf'];o.description+=' Cookie-only alternative vẫn bắt buộc token CSRF trong body nếu thiếu header; không được bỏ CSRF, OpenAPI3 không ràng buộc security/body chéo.';}
  };
  const request=(o:OperationObject,schema:string)=>{o.requestBody={required:true,content:{'application/json':{schema:ref(schema)}}};};
  const writes={'400':['INVALID_REQUEST'],'403':['SESSION_REQUIRED','CSRF_INVALID','ADMIN_REQUIRED']};
  let o=operation('/api/v1/ads','get');o.security=[{cookie:[]}];o.summary='Campaign theo placement, có thể null';o.description='Guest cookie/session, không CSRF. Chỉ req.query.placement === sponsor chọn sponsor; giá trị khác/thiếu/non-string chọn banner. Campaign enabled và startsAt<=now<endsAt; weighted selection. GET sponsor có side effect cooldown bảo thủ: response mất vẫn tiêu claim, không auto retry/prefetch. Không campaign hoặc không grant trảnull.';
  o.parameters!.push({in:'query',name:'placement',required:false,schema:string,description:'Chỉ chuỗi sponsor chọn sponsor; banner/giá trị khác/thiếu chọn banner. Không enum reject hoặc INVALID_REQUEST cho query khác.'});
  o.responses={'200':success('AdsSelection','Campaign projection hoặc null'),...adminErrors({'403':['SESSION_REQUIRED']})};o['x-sponsor-policy']={cooldownSeconds:600,claim:'Redis SET NX EX',emptyCampaignConsumes:false,bannerCooldown:false,responseLostConsumes:true};
  o=operation('/api/v1/ad-events','post');o.summary='Ghi event UUID dedupe';o.description='Rate60/60s/guest session; body strict UUIDid/campaignId và impression|click. Campaign phải enabled/đúng lịch, không cần campaign thuộc cookie; CAMPAIGN_UNAVAILABLE404. createMany skipDuplicates giữ event đầu tiên. Thất bại thống kê không chứng nhận doanh thu/platform.';request(o,'AdEventInput');mutation(o,false);o.responses={'201':success('OkResponse','Đã xử lý insert/dedupe, ok:true'),...adminErrors({'400':['INVALID_REQUEST'],'403':['SESSION_REQUIRED','CSRF_INVALID'],'404':['CAMPAIGN_UNAVAILABLE'],'429':['RATE_LIMITED']})};o['x-event-policy']={idempotency:'event UUID/createMany skipDuplicates',rateMax:60,rateSeconds:60};
  o=operation('/api/v1/admin/login','post');o.summary='Đăng nhập admin';o.description='Guest CSRF trước rate5/300s/IP, rồi strict email/password. Email lookup lowercase, password scrypt/dummy path; LOGIN_FAILED403. Token+HMAC cookie và Redis TTL3600s. Nest POST default201 kể cả manual @Res; không yêu cầu adminCookie có sẵn.';request(o,'AdminLoginInput');mutation(o,false);o.responses={'201':{...success('OkResponse','Đăng nhập thành công'),headers:{...noStore,'Set-Cookie':header('ws_admin HttpOnly/SameSite=Lax/Path=/api/Max-Age3600; Secure theo COOKIE_SECURE. Không cookie value trong schema/example.')}},...adminErrors({'400':['INVALID_REQUEST'],'403':['SESSION_REQUIRED','CSRF_INVALID','LOGIN_FAILED'],'429':['RATE_LIMITED']})};
  o=operation('/api/v1/admin/logout','post');o.summary='Thu hồi cookie admin nếu có';o.description='Guest CSRF bắt buộc; không gọi admin() và không bắt buộc adminCookie hợp lệ/có sẵn. Nếu có token thì Redis del, clearCookie. POST default201, không thêm ADMIN_REQUIRED.';mutation(o,false,true);o.responses={'201':{...success('OkResponse','ok:true kể cả không có cookie admin khi guestCSRF hợp lệ'),headers:{...noStore,'Set-Cookie':header('Xóa ws_admin tại Path=/api, cookie options theo auth; không value example.')}},...adminErrors({'403':['SESSION_REQUIRED','CSRF_INVALID']})};
  o=operation('/api/v1/admin/dashboard','get');o.security=[{adminCookie:[]}];o.summary='Counts và queue/budget hiện có';o.description='AdminCookie chỉ; không cần guest/Origin/CSRF. Prisma groups theo state/type/campaign, lease _sum.bytes và budget.charged chuyển String(BigInt), bytes null→0. failed lấy20row gần nhất (id/platform/errorCode/updatedAt), queue waiting/active, verified env. Không CTR/doanh thu/time aggregation/source URLs.';o.responses={'200':success('AdminDashboard','Counts/BigInt-string/date serialization hiện có'),...adminErrors({'403':['ADMIN_REQUIRED']})};
  o=operation('/api/v1/admin/settings','get');o.security=[{adminCookie:[]}];o.summary='Đọc limits đã validation';o.description='AdminCookie chỉ. limits() parse settings value hoặc defaults; lọc enabledPlatforms bằng VERIFIED_PLATFORMS. Không trả rowid/audit/secret.';o.responses={'200':success('AdminLimits','17 trường limits'),...adminErrors({'403':['ADMIN_REQUIRED']})};
  o=operation('/api/v1/admin/settings','put');o.summary='Thay toàn bộ17 limits';o.description='Strict limitsSchema bounds; enabledPlatforms thuộc VERIFIED_PLATFORMS, nếu không PLATFORM_NOT_VERIFIED400. Transaction settings.upsert + auditLog, response là value đã parse, không auditrow. Không ghi settings khi generate docs.';request(o,'AdminLimits');mutation(o,true);o.responses={'200':success('AdminLimits','Value đã nhận, không partial patch'),...adminErrors({...writes,'400':['INVALID_REQUEST','PLATFORM_NOT_VERIFIED']})};
  o=operation('/api/v1/admin/campaigns','get');o.security=[{adminCookie:[]}];o.summary='Danh sách campaign';o.description='AdminCookie chỉ; Prisma findMany order startsAt desc, gồm campaign enabled/disabled, không filter lịch; dates ISO, persisted strings không enum input.';o.responses={'200':success('AdminCampaignList','Prisma campaign rows, có thể []'),...adminErrors({'403':['ADMIN_REQUIRED']})};
  o=operation('/api/v1/admin/campaigns','post');o.summary='Tạo campaign strict';o.description='campaignSchema strict, imageUrl optional-nullable, HTTPS refinement và startsAt<endsAt; transaction create + auditLog. POST201, response campaign row.';request(o,'AdminCampaignInput');mutation(o,true);o.responses={'201':success('AdminCampaign','Campaign row đã tạo'),...adminErrors(writes)};
  o=operation('/api/v1/admin/campaigns/{id}','put');o.summary='Thay toàn bộ campaign';o.description='UUID path validation trước admin/guestCSRF; strict campaign body + HTTPS/schedule relation. Transaction update + auditLog. DB update missing-row hiện không có AppError404, unexpected exception đi SafeErrors500.';request(o,'AdminCampaignInput');mutation(o,true);o.responses={'200':success('AdminCampaign','Campaign row sau update'),...adminErrors(writes)};
  o=operation('/api/v1/admin/campaigns/{id}','delete');o.summary='Xóa campaign';o.description='UUID path validation trước admin/guestCSRF, transaction delete + auditLog. Body không parse strict; CSRF body fallback có thể dùng. Missing row không map thành AppError404; SafeErrors500.';mutation(o,true,true);o.responses={'200':success('OkResponse','ok:true sau transaction'),...adminErrors(writes)};
}


// Documentation only. Guards/validation/services remain the source of runtime behavior.
const ref = (name: string) => ({ $ref: `#/components/schemas/${name}` });
const object = (properties: Record<string, any>, required = Object.keys(properties)): SchemaObject =>
  ({ type: 'object', additionalProperties: false, required, properties });
const uuid: SchemaObject = { type: 'string', format: 'uuid' };
const csrf: SchemaObject = { type: 'string', pattern: '^[a-f0-9]{64}$', description: 'CSRF từ GET /session, gắn cookie phiên; không phải cookie value.' };
const states = ['analyzing', 'selectable', 'queued', 'preparing', 'ready', 'failed', 'cancelled', 'expired'];
const metadataDescription = 'Metadata lựa chọn chưa prepare có deadline cố định <=120000ms từ metadataAcceptedAt; now >= deadline hết hạn. Hạn nguồn tin cậy sớm hơn giảm deadline; heartbeat/updatedAt/ownerUntil không renew. Selectable legacy thiếu mốc bị expired. Prepare đã nhận trước hạn tiếp tục theo lifecycle riêng. Python hiện không trả signed URL expiry, không parse query.';

function schemas(): Record<string, SchemaObject> {
  return {
    ApiError: object({ error: object({ code: { type: 'string', description: 'Mã HTTP ổn định; chỉ error.code, không message/stack/path. Khác errorCode trên job failed.' } }) }),
    OkResponse: object({ ok: { type: 'boolean', enum: [true] } }),
    SessionResponse: object({
      csrf,
      supported: { type: 'array', maxItems: 4, items: { type: 'string', enum: ['youtube', 'tiktok', 'facebook', 'x'] }, description: 'enabledPlatforms sau lọc VERIFIED_PLATFORMS; không khẳng định tất cả nền tảng đã bật/kiểm chứng.' },
      verified: { type: 'array', items: { type: 'string' }, description: 'Danh sách env VERIFIED_PLATFORMS; không tự suy thành chứng nhận adapter.' },
      contact: { type: 'string', nullable: true, description: 'CONTACT_EMAIL hoặc null; env không có validation email tại endpoint này.' },
      productName: { type: 'string', maxLength: 60 },
      heartbeatSeconds: { type: 'integer', enum: [15] },
      capabilities: object({ tiktokPhoto: { type: 'boolean', description: 'Khả năng ảnh theo cấu hình server, mặc định false; không là cam kết nguồn khả dụng hoặc proof của job.' } }),
    }),
    AnalyzeInput: object({ url: { type: 'string', format: 'uri', maxLength: 2048,
      description: 'HTTPS URL được validateUrl kiểm tra: không userinfo, port hoặc fragment; host platform allowlist và enabledPlatforms. YouTube playlist/live bị UNSUPPORTED_CONTENT; ID video phải hợp lệ. Không có csrf trong strict body, dùng header.' } }),
    PrepareInput: object({ itemId: uuid, formatId: { type: 'string', maxLength: 80, pattern: '^[\\w-]+(?:\\+[\\w-]+)?$' }, idempotencyKey: uuid }),
    CsrfFallbackBody: { type: 'object', additionalProperties: true, properties: { csrf }, description: 'Body tùy chọn khi đã có header. Nếu không có x-csrf-token, bắt buộc csrf body hợp lệ; header có giá trị được ưu tiên. Endpoint này không parse strict body.' },
    AnalyzeAccepted: object({ jobId: uuid }),
    PrepareAccepted: object({ jobId: uuid, state: { type: 'string', enum: states, description: 'Thông thường queued; retry giữ state thực của cùng job/key/format (kể cả terminal khi có prepareKey và owner còn hợp lệ). Không ép mọi202 thành queued.' } }),
    MediaFormat: object({ id: { type: 'string' }, label: { type: 'string' }, size: { type: 'number', nullable: true, description: 'Byte metadata từ nguồn; null khi chưa biết, không phải byte tải đã chứng nhận.' }, height: { type: 'number', nullable: true }, kind: { type: 'string', enum: ['video'] } }, ['id', 'label', 'size']),
    MediaItem: object({ id: uuid, kind: { type: 'string', enum: ['video'], description: 'Worker hiện tạo video item, chưa adapter ảnh.' }, formats: { type: 'array', items: ref('MediaFormat'), description: 'JSON formats từ adapter; không công bố URL media/source.' } }),
    JobStatus: { ...object({
      id: uuid, state: { type: 'string', enum: states },
      errorCode: { type: 'string', nullable: true, description: 'Lỗi nghiệp vụ worker/job, ví dụ SOURCE_TIMEOUT/LIMIT_EXCEEDED/WORKER_INTERRUPTED/JOB_EXPIRED; có thể trong payload200, không phải HTTP error envelope.' },
      title: { type: 'string', nullable: true }, duration: { type: 'number', nullable: true },
      metadataAcceptedAt: { type: 'string', format: 'date-time', nullable: true, description: 'ISO timestamp processor chấp nhận analyze dưới khóa; null trước khi có metadata hoặc legacy.' },
      metadataExpiresAt: { type: 'string', format: 'date-time', nullable: true, description: metadataDescription },
      items: { type: 'array', items: ref('MediaItem'), description: 'Luôn [] nếu failed/cancelled/expired; metadata expired trả410 thay vì cung cấp lựa chọn.' },
      previewUrl: { type: 'string', nullable: true, description: 'Relative /api/v1/jobs/{id}/preview khi có title và state không terminal; không đảm bảo preview file tồn tại.' },
      mode: { type: 'string', enum: ['temporary'] },
      serverMeaning: { type: 'string', enum: ['server_finished không chứng minh tệp đã lưu vào thiết bị'] },
    }), description: metadataDescription },
    DownloadTicket: object({ url: { type: 'string', pattern: '^/api/v1/downloads/[a-f0-9]{64}$', description: 'Relative native link, gắn cùng cookie; nhiều Range hợp lệ dùng cùng ticket.' }, expiresIn: { type: 'integer', description: 'Giây transferMax từ settings hiện hành; tối đa1800, không phải token một lần.', minimum: 5, maximum: 1800 } }),
  };
}
const header = (description: string, schema: SchemaObject = { type: 'string' }) => ({ description, schema });
let noStore = { 'Cache-Control': header('Global API middleware; lỗi/JSON/HEAD không cache.', { type: 'string', enum: ['no-store'] }) };
function success(name: string, description: string): ResponseObject {
  return { description, headers: noStore, content: { 'application/json': { schema: ref(name) } } };
}
function error(codes: string[], description: string, bodyless = false): any {
  return { description, headers: noStore, 'x-error-codes': codes,
    ...(bodyless ? {} : { content: { 'application/json': { schema: { allOf: [ref('ApiError'),
      { type: 'object', properties: { error: { type: 'object', properties: { code: { type: 'string', enum: codes } } } } },
    ] } } } }) };
}
const idErrors = { '400': ['INVALID_REQUEST'], '403': ['SESSION_REQUIRED'], '404': ['JOB_NOT_FOUND'], '500': ['INTERNAL_ERROR'] };
const writeErrors = { ...idErrors, '403': ['SESSION_REQUIRED', 'CSRF_INVALID'] };
const errorsText: Record<string, string> = {
  '400': 'Validation/request/URL/format/platform bị từ chối theo error.code.',
  '403': 'Cookie phiên không hợp lệ hoặc CSRF/Origin sai (ở mutation).',
  '404': 'Job không tồn tại hoặc không thuộc cookie phiên; UUID không cấp quyền.',
  '409': 'IDEMPOTENCY_CONFLICT: key/format xung đột với job đã chọn.',
  '410': 'JOB_EXPIRED: metadata/owner/ticket/tệp không còn hợp lệ theo guard endpoint.',
  '429': 'Hạn mức/admission; phân biệt RATE_LIMITED với QUEUE_FULL bằng error.code.',
  '503': 'CAPACITY_UNAVAILABLE: từ chối nhận công việc hoặc reservation mới theo capacity/budget.',
  '500': 'SafeErrors chỉ trả error.code; không stack/message/path. Stream đã gửi headers có thể bị đóng thay vì JSON mới.',
};
function errors(map: Record<string, string[]>, bodyless = false): Record<string, any> {
  return Object.fromEntries(Object.entries(map).map(([status, codes]) => [status, error(codes, errorsText[status]+(bodyless ? ' HEAD không body, mã là metadata của nhánh lỗi nội bộ; không có error-code header.' : ''), bodyless)]));
}

/** Augment only public session/job/download operations. Admin/ads remain historical. */
export function describePublicContracts(doc: OpenAPIObject) {
  doc.components ??= {}; doc.components.schemas ??= {};
  Object.assign(doc.components.schemas, schemas());
  const mutation = (operation: OperationObject & Record<string, any>, bodyFallback: boolean) => {
    operation.security = bodyFallback ? [{ cookie: [], csrf: [] }, { cookie: [] }] : [{ cookie: [], csrf: [] }];
    operation.parameters ??= [];
    operation.parameters.push({ in: 'header', name: 'Origin', required: true, schema: { type: 'string' }, description: 'Phải bằng APP_ORIGIN, kể cả body CSRF fallback.' },
      { in: 'header', name: 'x-csrf-token', required: !bodyFallback, schema: csrf, description: bodyFallback ? 'Bắt buộc header này HOẶC csrf trong JSON body; không phải CSRF tùy chọn.' : 'Bắt buộc: strict analyze/prepare body không nhận field csrf.' });
    operation.description += bodyFallback ? '\nBắt buộc cookie + Origin và token CSRF qua header hoặc csrf JSON body; header có giá trị ưu tiên. Security cookie-only alternative chỉ hợp lệ khi body có csrf; OpenAPI3 không biểu diễn ràng buộc security/body chéo, không được bỏ CSRF.' : '\nCookie + Origin đúng APP_ORIGIN + x-csrf-token; request body strict.';
    if(bodyFallback){ operation.requestBody = { required: false, content: { 'application/json': { schema: ref('CsrfFallbackBody') } } }; operation['x-csrf-alternatives']=['header:x-csrf-token','body:csrf']; }
  };
  const op = (path: string, method: 'get'|'post'): OperationObject & Record<string, any> => {
    const operation=doc.paths[path]?.[method];if(!operation)throw new Error('Public OpenAPI route missing: '+method+' '+path);
    // Replace only target metadata; retain actual operationId and tags from controllers.
    operation.parameters=(operation.parameters || []).filter((p:any)=>p.in==='path').map((p:any)=>({ ...p, required:true, schema: p.name==='id'?uuid:p.schema }));
    if(path.includes('{id}') && !operation.parameters.some((p:any)=>p.in==='path'&&p.name==='id'))
      operation.parameters.push({in:'path',name:'id',required:true,schema:uuid,description:'UUID job; own() kiểm validation và cookie ownership trước thao tác.'});
    operation.security=[{cookie:[]}];return operation;
  };
  let o=op('/api/v1/health','get');o.security=[];o.summary='Health DB và Redis';o.description='Không yêu cầu cookie. Health thực gọi DB SELECT1 và Redis PING; lỗi backend trả500 safe. Generator chỉ quét metadata, không gọi endpoint này.';
  o.responses={'200':success('OkResponse','DB/Redis phản hồi; ok=true'),...errors({'500':['INTERNAL_ERROR']})};
  o=op('/api/v1/session','get');o.security=[];o.summary='Lấy hoặc tạo cookie phiên';o.description='Cookie hợp lệ được dùng lại; thiếu/hết hạn/không hợp lệ thì tạo mới. Tối đa10 phiên mới/60s/IP trước insert; reuse không tiêu quota. supported/verified là cấu hình, không chứng nhận platform.';
  o.responses={'200':{...success('SessionResponse','CSRF và cấu hình public; contact có thể null'),headers:{...noStore,'Set-Cookie':header('Chỉ khi tạo phiên mới: ws_session HttpOnly, SameSite=Lax, Path=/api, Max-Age24h; Secure khi COOKIE_SECURE=true. Không đưa cookie value vào JSON.')}},...errors({'429':['RATE_LIMITED'],'500':['INTERNAL_ERROR']})};
  o=op('/api/v1/jobs/analyze','post');o.summary='Tiếp nhận analyze';o.description='202 chỉ chấp nhận job, không chứng nhận analyze/tải thành công. Rate10/60s/phiên,30/60s/IP; QUEUE_FULL admission khác RATE_LIMITED. Source URL được validate và chỉ platform enabled được nhận.';
  o.requestBody={required:true,content:{'application/json':{schema:ref('AnalyzeInput')}}};mutation(o,false);
  o.responses={'202':success('AnalyzeAccepted','Job phân tích được nhận'),...errors({'400':['INVALID_REQUEST','INVALID_URL','UNSUPPORTED_PLATFORM','UNSUPPORTED_CONTENT'],'403':['SESSION_REQUIRED','CSRF_INVALID'],'429':['RATE_LIMITED','QUEUE_FULL'],'503':['CAPACITY_UNAVAILABLE'],'500':['INTERNAL_ERROR']})};
  o=op('/api/v1/jobs/{id}','get');o.summary='Trạng thái và metadata của job thuộc phiên';o.description=metadataDescription+' Job terminal thông thường có thể200 với items=[]; chỉ metadata expired guard trả410 tại status, không ép mọi failed/cancelled/expired thành410.';
  o['x-metadata-ttl']={maxAgeMs:120000,origin:'metadataAcceptedAt',expiresWhen:'now >= metadataExpiresAt',heartbeatRenews:false,legacyMissing:'expired',trustedEarlierSourceExpiry:true,acceptedPrepareContinues:true};
  o.responses={'200':success('JobStatus','Payload state/items/nullable metadata; không token/path/source/cleanup marker'),...errors({...idErrors,'410':['JOB_EXPIRED']})};
  o=op('/api/v1/jobs/{id}/preview','get');o.summary='Preview PNG/JPEG thuộc job';o.description='Metadata expiry/cancelled/failed/expired bị410 dưới khóa. Job tồn tại nhưng open preview không thành công trả404 body rỗng; own/notfound trả404 JSON JOB_NOT_FOUND. PreviewUrl trong status không bảo đảm file tồn tại.';
  o.responses={'200':{description:'Ảnh nhận dạng theo byte đầu, không JSON',headers:{'Cache-Control':header('Preview private, no-store',{type:'string',enum:['private, no-store']})},content:{'image/jpeg':{schema:{type:'string',format:'binary'}},'image/png':{schema:{type:'string',format:'binary'}}}},...errors({...idErrors,'410':['JOB_EXPIRED'],'500':['INTERNAL_ERROR','INVALID_ASSET_PATH']})};
  (o.responses['404'] as ResponseObject).description += ' Nếu job thuộc phiên nhưng không mở được preview: body rỗng, không JSON error.';
  o=op('/api/v1/jobs/{id}/prepare','post');o.summary='Chọn format và nhận prepare idempotent';o.description=metadataDescription+' UUID itemId và idempotencyKey, formatId max80/pattern; strict body. Same key/format giữ job; format xung đột409. Metadata expired chưa nhận prepare410; disk/admission503 có thể xảy ra trước TTL check; tối đa1prepare/phiên và queue20 theo settings.';
  o.requestBody={required:true,content:{'application/json':{schema:ref('PrepareInput')}}};mutation(o,false);
  o.responses={'202':success('PrepareAccepted','Job được tiếp nhận hoặc retry job/key/format hiện có'),...errors({...writeErrors,'400':['INVALID_REQUEST','FORMAT_UNAVAILABLE','UNSUPPORTED_PLATFORM'],'409':['IDEMPOTENCY_CONFLICT'],'410':['JOB_EXPIRED'],'429':['RATE_LIMITED','QUEUE_FULL'],'503':['CAPACITY_UNAVAILABLE']})};
  for(const name of ['heartbeat','release','cancel'] as const){
    o=op('/api/v1/jobs/{id}/'+name,'post');o.summary=name==='heartbeat'?'Gia hạn owner job còn hợp lệ':name==='release'?'Rời trang: bắt đầu grace':'Yêu cầu hủy job';
    o.description=name==='heartbeat'?'Gia hạn ownerUntil và bỏ releaseAt; không gia hạn metadata deadline. Owner/terminal/cancel/metadata expiry trả410.':'release'===name?'Chỉ đặt releaseAt theo releaseGrace, không xóa ngay/không tự reject metadata expiry bằng410. Best-effort beacon có thể dùng csrf body. Transfer đang chạy độc lập.':'Normal cancel201, lặp trên cancelled giữ201 không renewupdatedAt. Metadata expired (kể cả cancel đầu tại120000ms) commit rồi410 JOB_EXPIRED. Yêu cầu hủy không đồng nghĩa cleanup đã xong; transfer đang chạy được duy trì.';
    mutation(o,true);o.responses={'201':success('OkResponse','Đã nhận '+name+'; ok=true'),...errors({...writeErrors,...(name==='release'?{}:{'410':['JOB_EXPIRED']})})};
  }
  o=op('/api/v1/jobs/{id}/download-ticket','post');o.summary='Cấp native download link gắn phiên';o.description='Chỉ ready + available + chưa cancel + asset chưa hết hạn.10ticket/60s/phiên,5/60s/job. Không tạo transfer lease/reservation tại bước cấp ticket; cùng ticket có thể dùng nhiều Range. expiresIn từ transferMax settings, không chứng minh tệp đã lưu.';
  mutation(o,true);o.responses={'201':success('DownloadTicket','Relative url và expiresIn giây'),...errors({...writeErrors,'410':['JOB_EXPIRED'],'429':['RATE_LIMITED']})};
  const downloadPath='/api/v1/downloads/{ticket}';o=op(downloadPath,'get');
  o.summary='MP4 qua máy chủ, full hoặc một byte Range';o.description='Cookie + ticket cùng phiên, rate60request/60s/phiên trước HEAD/GET branch. GET khóa job→asset→budget, tạo lease và reserve trước open file. Range hợp lệ dùng lại ticket/tài sản nhưng không kéo dài absolute transferDeadline. server_finished chỉ kết thúc stream máy chủ, không chứng minh lưu thiết bị. Lỗi sau headers có thể ngắt stream; không luôn có error JSON.';
  o.parameters=[{in:'path',name:'ticket',required:true,schema:{type:'string',pattern:'^[a-f0-9]{64}$'},description:'Ticket random64hex gắn cookie; không UUID.'},{in:'header',name:'Range',required:false,schema:{type:'string'},example:'bytes=0-99',description:'Một bytes=start-end, start- hoặc -suffix; không multipart. Syntax/biên sai416, end quásize được clip.'}];
  const streamHeaders=(partial:boolean,head:boolean)=>({
    'Content-Type':header('MP4',{type:'string',enum:['video/mp4']}),
    'Content-Length':header('Số byte representation được chọn (HEAD không gửi byte)',{type:'integer',minimum:0}),
    'Accept-Ranges':header('Byte range',{type:'string',enum:['bytes']}),
    'Cache-Control':header(head?'Global middleware no-store; HEAD không set private stream header':'Stream private, no-store',{type:'string',enum:[head?'no-store':'private, no-store']}),
    ...(partial?{'Content-Range':header('bytes start-end/size',{type:'string',pattern:'^bytes [0-9]+-[0-9]+/[0-9]+$'})}:{}),
    ...(head?{}:{'Content-Disposition':header('Tên cố định không từ user',{type:'string',enum:['attachment; filename="wed-snap-video.mp4"']})}),
  });
  const downloadErrors={'403':['SESSION_REQUIRED'],'410':['JOB_EXPIRED'],'416':['INVALID_RANGE'],'429':['RATE_LIMITED'],'500':['INTERNAL_ERROR']};
  const downloadResponses=(head:boolean)=>{
    const responses:any={
      '200':{description:head?'HEAD full, không body':'Full MP4',headers:streamHeaders(false,head),...(head?{}:{content:{'video/mp4':{schema:{type:'string',format:'binary'}}}})},
      '206':{description:head?'HEAD range, không body':'Một Range MP4',headers:streamHeaders(true,head),...(head?{}:{content:{'video/mp4':{schema:{type:'string',format:'binary'}}}})},
      ...errors(head?downloadErrors:{...downloadErrors,'500':['INTERNAL_ERROR','INVALID_ASSET_PATH'],'503':['CAPACITY_UNAVAILABLE']},head),
    };
    responses['416'].headers['Content-Range']=header('Range không hợp lệ: bytes */size',{type:'string',pattern:'^bytes \\*/[0-9]+$'});return responses;
  };
  o.responses=downloadResponses(false);o['x-transfer-reservation']=true;
  doc.paths[downloadPath].head={operationId:o.operationId+'_HEAD',tags:o.tags,summary:'Implicit HEAD qua GET handler hiện có',description:'Express implicit HEAD dùng GET controller. Cookie/ticket/Range/rate và availability/expiry được kiểm tra trước end; không tạo lease, không reserve, không kiểm budget503, không open/stat file. HEAD không body cả lỗi, không Content-Disposition. Cache-Control no-store đến từ global middleware, không private header của GET stream.',security:[{cookie:[]}],parameters:structuredClone(o.parameters),responses:downloadResponses(true),'x-implicit-head-of':o.operationId,'x-transfer-reservation':false} as any;
  // P25 measured with cached Nest11.2.7/Express5.2.1: malformed JSON400 at
  // all12 public operations, and URI decode400 at parameter routes, before
  // controller/ownership. Do not infer other HttpException statuses per route.
  for(const [path,item] of Object.entries(doc.paths)) {
    if(!['/api/v1/health','/api/v1/session'].includes(path) &&
       !path.startsWith('/api/v1/jobs/') && path!=='/api/v1/jobs/{id}' &&
       path!==downloadPath) continue;
    for(const method of ['get','post','head'] as const) {
      const operation=item[method];if(!operation)continue;
      const existing=operation.responses['400'] as any;
      const codes=existing?.['x-error-codes']||[];
      operation.responses['400']=error([...codes,'INTERNAL_ERROR'],
        (existing?.description||'')+' Framework/parser: malformed JSON trả400/INTERNAL_ERROR trước controller; URI encoding lỗi tại route có parameter cũng trả400/INTERNAL_ERROR trên runtime đã thử. HttpException giữ getStatus(); không suy mọi lỗi parser hay mọi status từ fixture này.',method==='head');
    }
  }
}

