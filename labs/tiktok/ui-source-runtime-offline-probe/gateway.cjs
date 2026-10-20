'use strict';
try{
 const assert=require('node:assert/strict');assert.equal(process.platform,'linux');assert.equal(process.versions.node.split('.')[0],'22');
 const contract=require('/labs/tiktok/ui-source-glue/contract.cjs'),policy=require('/labs/tiktok/ui-source-glue/policy.cjs');
 assert.equal(typeof contract.runtimeContract,'function');assert.equal(typeof policy.createSelectionGuard,'function');
 console.log(JSON.stringify({kind:'role',role:'gateway',ok:true,node:process.versions.node,imports:['contract.cjs','policy.cjs'],serverStarted:false,sourceContractCalled:false}));
}catch{console.log(JSON.stringify({kind:'failure',role:'gateway',stage:'NODE_VERSION_OR_IMPORT'}));process.exitCode=20;}
