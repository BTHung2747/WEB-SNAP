// AGPL-3.0 lab glue, Undici6.24.1 public factories/connectors and diagnostic channels.
import dc from 'node:diagnostics_channel';
import { Pool, buildConnector } from 'undici';
export const EVENT_CAP=128;
const code=e=>typeof e?.code==='string'&&/^[A-Z0-9_]{1,64}$/.test(e.code)?e.code:'OTHER';
export function createStages({report,proxyURI='http://egress:8888',onUpdate}){
  const proxy=new URL(proxyURI),start=performance.now(),listeners=[],requests=new WeakMap(),sockets=new WeakMap(),origins=new Map(),connections=[],attempts=new Map();
  let current=null,closed=false;
  const data={schema:2,clock:'monotonic ms from observer start',scope:'sequential requests; request/origin/socket identity; unavailable correlations stay unknown',
    eventCap:EVENT_CAP,events:[],requests:[],origins:[],connections:[],dropped:0,observerFault:false,
    unobservable:['egress DNS versus upstream TCP','remote receipt of origin request','first wire byte versus complete response headers']};
  report.transportStages=data;
  const now=()=>Math.round((performance.now()-start)*1000)/1000;
  function origin(key){if(!origins.has(key)){if(origins.size>=16)throw new Error('DIAGNOSTIC_ORIGIN_CAP');const x={key,id:'o'+(origins.size+1)};origins.set(key,x);data.origins.push({originId:x.id})}return origins.get(key)}
  function phase(h){
    if(!h)return 'IDLE';
    if(h.bodyComplete)return 'COMPLETE';
    if(h.originHeaders)return h.bodyReaderStarted?'READING_BODY':'HEADERS_RECEIVED_BEFORE_BODY_READER';
    if(h.originSent)return 'WAITING_RESPONSE_HEADERS';
    if(h.originSendStarted)return 'SENDING_ORIGIN_REQUEST';
    if(h.originTLSReady)return 'BEFORE_ORIGIN_SEND';
    if(h.tunnelStatus===200)return 'WAITING_ORIGIN_TLS';
    if(h.tunnelStarted)return h.proxyTCPReady||h.proxyTCPAvailable?'WAITING_PROXY_CONNECT_RESPONSE':'WAITING_PROXY_TCP_OR_DNS';
    if(h.originTLSAvailable)return 'WAITING_CONNECTION_ASSIGNMENT';
    return 'BEFORE_CONNECT';
  }
  const fields=['bodyComplete','bodyReaderStarted','originHeaders','originSent','originSendStarted','firstDecoded','tunnelStarted','tunnelStatus','proxyTCPReady','proxyTCPAvailable','proxyConnectionId','originTLSReady','originTLSAvailable','connectionId','connectionReused','failureStage','failureMs'];
  function flush(){
    if(current){for(const f of fields){if(current[f]===undefined)delete data[f];else data[f]=current[f]}data.currentRequestId=current.requestId;data.awaitedStage=phase(current)}
    else data.awaitedStage='IDLE';
    data.observedMs=now();try{onUpdate?.(data)}catch{data.observerFault=true}
  }
  function mark(event,fields={},h=current){
    if(closed)return;
    const ids=h?{requestId:h.requestId,originId:h.originId}:{};
    if(data.events.length<EVENT_CAP)data.events.push({event,ms:now(),...ids,...fields});else data.dropped++;
    if(h){h.awaitedStage=phase(h);h.sync?.()}flush();
  }
  function registerSocket(socket,role,o,h,tunnelStatus){
    let c=sockets.get(socket);if(c)return c;
    if(connections.length>=32)throw new Error('DIAGNOSTIC_CONNECTION_CAP');
    const entry={connectionId:'c'+(connections.length+1),role,...(o?{originId:o.id}:{}),ready:true,
      encrypted:socket.encrypted===true,authorized:socket.authorized===true,uses:0};
    c={socket,role,o,h,tunnelStatus,entry};sockets.set(socket,c);connections.push(c);data.connections.push(entry);
    c.onClose=()=>{entry.ready=false;mark('connection_closed',{role,connectionId:entry.connectionId},null)};
    socket.once('close',c.onClose);return c;
  }
  function available(role,o){return connections.some(c=>c.role===role&&(!o||c.o===o)&&c.entry.ready&&!c.socket.destroyed&&!c.entry.tunnelAssigned&&(role!=='origin'||c.entry.encrypted&&c.entry.authorized))}
  function bind(h,c){
    h.connectionId=c.entry.connectionId;h.connectionReused=c.entry.uses>0;
    h.originTLSReady=c.entry.encrypted&&c.entry.authorized&&c.entry.ready&&!c.socket.destroyed;
    if(c.tunnelStatus!==undefined)h.tunnelStatus=c.tunnelStatus;
    if(c.proxyConnection){h.proxyConnectionId=c.proxyConnection.entry.connectionId;h.proxyTCPReady=c.proxyConnection.entry.ready&&!c.proxyConnection.socket.destroyed}
    c.entry.uses++;
  }
  function subscribe(name,fn){const channel=dc.channel('undici:'+name);const cb=m=>{try{fn(m)}catch{data.observerFault=true;flush()}};channel.subscribe(cb);listeners.push([channel,cb])}
  subscribe('request:create',({request})=>{
    let h=null,role;
    if(String(request.origin)===proxy.origin&&request.method==='CONNECT'){
      const a=attempts.get(new URL('https://'+request.path).origin);h=a?.h;role='proxy-tunnel';
    }else if(current&&String(request.origin)===current.key){h=current;role='origin'}
    if(h){requests.set(request,{h,role});mark('request_created',{role},h)}
  });
  subscribe('client:connected',({socket})=>{
    const c=sockets.get(socket);if(!c)return; // Factory callback owns this exact socket; never guess by hostname.
    if(c.role==='origin'&&c.h){bind(c.h,c);c.entry.uses--;mark('connection_ready',{role:'origin',connectionId:c.entry.connectionId,encrypted:c.entry.encrypted,authorized:c.entry.authorized},c.h)}
    else mark('connection_ready',{role:'proxy',connectionId:c.entry.connectionId},null);
  });
  subscribe('client:sendHeaders',({request,socket})=>{
    const r=requests.get(request);if(!r)return;
    const c=sockets.get(socket);
    if(r.role==='origin'){if(c&&c.role==='origin'&&c.o.key===r.h.key)bind(r.h,c);r.h.originSendStarted=true}
    else if(c?.role==='proxy'){r.h.proxyTCPReady=c.entry.ready}
    mark('send_headers_started',{role:r.role,...(c?{connectionId:c.entry.connectionId}:{})},r.h);
  });
  subscribe('request:bodySent',({request})=>{const r=requests.get(request);if(r){if(r.role==='origin')r.h.originSent=true;mark('request_sent_local',{role:r.role},r.h)}});
  subscribe('request:headers',({request,response})=>{const r=requests.get(request);if(r){if(r.role==='origin'&&response.statusCode>=200)r.h.originHeaders=true;mark('response_headers',{role:r.role,status:response.statusCode},r.h)}});
  subscribe('request:trailers',({request})=>{const r=requests.get(request);if(r)mark('wire_body_complete',{role:r.role},r.h)});
  subscribe('request:error',({request,error})=>{const r=requests.get(request);if(r)mark('request_error',{role:r.role,code:code(error)},r.h)});
  flush();
  return{
    begin(url){
      if(current&&!current.bodyComplete&&!current.failureStage)throw new Error('CONCURRENT_METADATA_REQUEST_DENIED');
      if(data.requests.length>=16)throw new Error('DIAGNOSTIC_REQUEST_CAP');
      const o=origin(new URL(url).origin);
      const h={requestId:'r'+(data.requests.length+1),originId:o.id,key:o.key,originTLSAvailable:available('origin',o),
        proxyTCPAvailable:available('proxy'),originTLSReady:false,proxyTCPReady:false,tunnelStarted:false,
        originSent:false,originHeaders:false,bodyReaderStarted:false,bodyComplete:false,firstDecoded:false};
      const publicHop={};for(const [k,v]of Object.entries(h))if(k!=='key')publicHop[k]=v;
      // Private key stays outside evidence; report object contains only opaque identity IDs.
      h.publicHop=publicHop;data.requests.push(publicHop);current=h;
      function sync(){for(const [k,v]of Object.entries(h))if(!['key','publicHop','sync'].includes(k))publicHop[k]=v}
      h.sync=sync;mark('fetch_begin',{},h);sync();
      if(data.observerFault)throw new Error('DIAGNOSTIC_OBSERVER_FAILED');
      return{
        headers(){h.originHeaders=true;mark('fetch_headers_resolved',{},h);sync()},
        readStart(){h.bodyReaderStarted=true;mark('decoded_body_reader_started',{},h);sync()},
        firstDecoded(){if(!h.firstDecoded){h.firstDecoded=true;mark('first_decoded_body_chunk',{},h);sync()}},
        bodyComplete(bytes){h.bodyComplete=true;mark('decoded_body_complete',{bytes},h);sync()},
        failed(error){if(!h.failureStage){h.failureStage=phase(h);h.failureMs=now()}mark('fetch_or_body_failed',{code:code(error)},h);sync()}
      };
    },
    originFactory(value,options){
      const o=origin(new URL(value).origin),delegate=options.connect;
      return new Pool(value,{...options,connect(params,callback){
        const h=current?.key===o.key?current:null,a={h,o,tunnelStatus:undefined};attempts.set(o.key,a);
        mark('connection_begin',{role:'origin'},h);
        delegate(params,(error,socket)=>{
          if(error)mark('connection_error',{role:'origin',code:code(error)},h);
          else{const c=registerSocket(socket,'origin',o,h,a.tunnelStatus);c.proxyConnection=a.proxyConnection}
          callback(error,socket);
        });
      }});
    },
    clientFactory(value,options){
      const delegate=typeof options.connect==='function'?options.connect:buildConnector(options.connect||{});
      const pool=new Pool(value,{...options,connect(params,callback){
        mark('connection_begin',{role:'proxy'},null);
        delegate(params,(error,socket)=>{
          if(error)mark('connection_error',{role:'proxy',code:code(error)},null);else registerSocket(socket,'proxy',null,null);
          callback(error,socket);
        });
      }}),connect=pool.connect.bind(pool);
      pool.connect=opts=>{
        const a=attempts.get(new URL('https://'+opts.path).origin),h=a?.h;
        if(h){h.tunnelStarted=true;h.proxyTCPAvailable=available('proxy');mark('proxy_connect_begin',{},h);h.sync()}
        return connect(opts).then(result=>{
          const proxyConnection=sockets.get(result.socket);if(proxyConnection)proxyConnection.entry.tunnelAssigned=true;
          if(a)a.proxyConnection=proxyConnection;
          if(a)a.tunnelStatus=result.statusCode;
          if(h){h.tunnelStatus=result.statusCode;mark('proxy_connect_response',{status:result.statusCode},h);h.sync()}
          return result;
        },error=>{mark('proxy_connect_error',{code:code(error)},h);throw error});
      };
      return pool;
    },
    mark,
    close(){mark('observer_close');closed=true;for(const [channel,cb]of listeners)channel.unsubscribe(cb);for(const c of connections)c.socket.off('close',c.onClose)}
  };
}
