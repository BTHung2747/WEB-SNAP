import {writeFile} from 'node:fs/promises';
let closeConnections=async()=>{};
async function main(){
 if(process.env.STEP5_EXECUTE_SOURCE!=='1'){console.log('SOURCE_DISABLED');process.exitCode=78;return;}
 const common=await import('./workflow');closeConnections=common.closeConnections;
 const result=await common.runWorkflow({mode:'source',case:'source',url:'https://www.tiktok.com/@adne_la.veil/photo/7678209751167110421',expectation:'/lab/expectation-source.json'});
 await writeFile('/control/source-result.json',JSON.stringify(result,null,2));if(result.status!=='PASS_TECHNICAL_NEEDS_VISUAL_REVIEW')process.exitCode=1;
}
main().catch(()=>{console.error('DRIVER_FAILED');process.exitCode=1;}).finally(()=>closeConnections());
