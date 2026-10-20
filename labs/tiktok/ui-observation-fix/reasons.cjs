'use strict';
const stages=new Set(['BROWSER_ACCEPTED','CORE_VERIFIED']);
const primaryCodes=new Set(['PHOTO_METADATA_UNAVAILABLE','JOB_CANCELLED','JOB_EXPIRED','RESPONSE_CONTRACT','RESPONSE_CAP','RESPONSE_ERROR','UPSTREAM_TIMEOUT','UPSTREAM_ERROR','REQUEST_GUARD','CONNECT_DENIED','UPGRADE_DENIED','EVENT_LOG_FAILED','QUEUE_ERROR','WORKER_OUTPUT_CAP']);
function safePrimary(code){return primaryCodes.has(code)?code:'PRIMARY_CODE_UNKNOWN';}
class StageStop extends Error{constructor(stage,reason,primary){super();this.stage=stage;this.reason=reason;this.primary=primary;}}
function waitReason(stage,{primary='',aborted=false,now,end}){
 if(!stages.has(stage))return new StageStop('UNKNOWN','INVALID_WAIT_STAGE','PRIMARY_CODE_UNKNOWN');
 if(primary)return new StageStop(stage,'PRIMARY_FAILURE',safePrimary(primary));
 if(aborted)return new StageStop(stage,'BROWSER_ABORT','PRIMARY_CODE_UNKNOWN');
 if(now>=end)return new StageStop(stage,'DEADLINE',stage+'_DEADLINE');
 return null;
}
function reasonRow(error,fallback){
 if(error instanceof StageStop)return{stage:error.stage,reason:error.reason,code:error.primary};
 return{stage:'UNKNOWN',reason:'UNCLASSIFIED',code:fallback?safePrimary(fallback):'GATEWAY_CONTRACT'};
}
module.exports={waitReason,reasonRow};
