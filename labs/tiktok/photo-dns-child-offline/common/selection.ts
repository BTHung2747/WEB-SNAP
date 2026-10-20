import {checkedPhotoFormats} from '/app/packages/shared/src/tiktok-photo';
export function choose(job:any,expected:any){
 if(job.items?.length!==1||job.items[0].kind!=='photo')throw Error('PHOTO_STRUCTURE');
 const rows=checkedPhotoFormats(job.items[0].formats,expected.id);
 if(rows.length!==expected.imageCount||rows[0].snapshotKey!==expected.snapshotKey)throw Error('PHOTO_SNAPSHOT');
 rows.forEach((r:any,i:number)=>{const e=expected.images[i];if(!e||r.index!==e.index||r.width!==e.width||r.height!==e.height||r.itemKey!==e.itemKey)throw Error('PHOTO_STRUCTURE');});
 const selected=rows.find((r:any)=>r.index===2);if(!selected)throw Error('PHOTO_INDEX');
 return {itemId:job.items[0].id,formatId:selected.id};
}
