import {readFileSync,writeFileSync,openSync,closeSync,unlinkSync,existsSync} from 'node:fs';
import {resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
export function deliveryKey(releaseId,destination,account){return JSON.stringify([releaseId,destination,account]);}
export function begin(state,release,destination,account,now=new Date().toISOString()){
 if(release.buildStatus!=='verified')throw Error('Only verified releases enter distribution');
 if(!release.releaseId||!destination||!account)throw Error('Missing release or destination identity');
 const key=deliveryKey(release.releaseId,destination,account);
 if(state[key])return {send:false,entry:state[key]};
 const entry={releaseId:release.releaseId,destination,account,status:'in_flight',startedAt:now};
 state[key]=entry;return {send:true,entry};
}
export function recordReceipt(state,key,url,now=new Date().toISOString()){
 const entry=state[key];if(!entry)throw Error('Delivery was not reserved');
 if(entry.status==='published'){if(entry.url!==url)throw Error('Conflicting receipt');return entry;}
 const parsed=new URL(url);if(parsed.protocol!=='https:')throw Error('Receipt must use HTTPS');
 Object.assign(entry,{status:'published',url,observedAt:now});return entry;
}
export function markUnknown(state,key,reason){
 if(!state[key]||state[key].status==='published')throw Error('Cannot mark this delivery unknown');
 Object.assign(state[key],{status:'needs_reconciliation',reason});return state[key];
}
export function transact(path,operation){
 const lock=path+'.lock';let fd;
 try{fd=openSync(lock,'wx');const state=existsSync(path)?JSON.parse(readFileSync(path,'utf8')):{};
 const result=operation(state);writeFileSync(path,JSON.stringify(state,null,2)+'\n');return result;
 }finally{if(fd!==undefined){closeSync(fd);unlinkSync(lock);}}
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 const [command,path,releasePath,destination,account,value]=process.argv.slice(2);
 if(!['begin','receipt','unknown','show'].includes(command)||!path)throw Error('Usage: node tools/delivery.mjs begin|receipt|unknown|show LEDGER MANIFEST DESTINATION ACCOUNT [URL|REASON]');
 if(command==='show'){console.log(existsSync(path)?readFileSync(path,'utf8'):'{}');}
 else{const release=JSON.parse(readFileSync(releasePath,'utf8'));const key=deliveryKey(release.releaseId,destination,account);
 console.log(JSON.stringify(transact(path,state=>command==='begin'?begin(state,release,destination,account):command==='receipt'?recordReceipt(state,key,value):markUnknown(state,key,value)),null,2));}
}
