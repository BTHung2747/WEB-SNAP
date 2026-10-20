import { writeFile } from 'node:fs/promises';
import { generated,canonical,raw } from './bootstrap';
async function main(){const {doc}=await generated();await writeFile('/tmp/p25.generated.json',JSON.stringify(canonical(doc),null,2)+'\n');raw('generated',{paths:Object.keys(doc.paths).length,operations:Object.values(doc.paths).reduce((n:any,p:any)=>n+['get','head','post','put','delete'].filter(m=>p[m]).length,0),destination:'/tmp/p25.generated.json',noManualSnapshot:true});}
main().catch(e=>{raw('HARNESS_FAIL',{error:String(e)});process.exitCode=1;});
