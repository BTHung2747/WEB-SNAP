import { z } from 'zod';
export const supportId='support-page-v1';
export const qrLimit=2*1024*1024;
export const uploadLimit=qrLimit+64*1024;
const text=(max:number,min=0)=>z.string().trim().min(min).max(max).refine(v=>!/[<>\x00-\x08\x0b\x0c\x0e-\x1f\x7f]/.test(v));
export const supportConfig=z.object({enabled:z.boolean(),title:text(100,1),message:text(2000,1),bankName:text(100),
  accountName:text(120),accountNumber:text(64).refine(v=>!v||/^[\p{L}\p{N} ._-]+$/u.test(v)),transferNote:text(240)}).strict();
export const supportDefaults={enabled:false,title:'Ủng hộ WED SNAP',
 message:'WED SNAP hiện chưa có quảng cáo. Nếu thấy công cụ hữu ích, bạn có thể ủng hộ một khoản nhỏ để giúp mình duy trì máy chủ và tiếp tục phát triển. Mọi sự ủng hộ đều tự nguyện. Cảm ơn bạn!',
 bankName:'',accountName:'',accountNumber:'',transferNote:''};
const qr=z.object({id:z.string().regex(/^[a-f0-9]{64}$/),png:z.string().max(4*Math.ceil(qrLimit/3)).regex(/^[A-Za-z0-9+/]+={0,2}$/),
 width:z.number().int().min(32).max(2048),height:z.number().int().min(32).max(2048)}).strict();
export type SupportQR=z.infer<typeof qr>;
export const supportRow=z.object({version:z.literal(1),config:supportConfig,qr:qr.nullable(),pending:z.object({qr:qr.nullable()}).strict().nullable()}).strict();
export type SupportRow=z.infer<typeof supportRow>;
export const emptySupport=():SupportRow=>({version:1,config:{...supportDefaults},qr:null,pending:null});
export function adminSupport(row:SupportRow){const image=row.pending ? row.pending.qr : row.qr;
 return {...row.config,qrUrl:image?`/api/v1/admin/support/qr/${image.id}`:null,qrPending:row.pending!==null};}
