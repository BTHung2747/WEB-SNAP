import assert from 'node:assert/strict';
// Deliberately limited contract keyword checker, not a universal OpenAPI validator or business verdict.
export const canonical=(v:any):any=>Array.isArray(v)?v.map(canonical):v&&typeof v==='object'?Object.fromEntries(Object.keys(v).sort().map(k=>[k,canonical(v[k])])):v;
export function checkSchema(document:any,schema:any,value:any){
  assert(schema,'schema required');const s=schema.$ref?document.components.schemas[schema.$ref.split('/').at(-1)]:schema;assert(s,'ref resolved');
  if(value===null){assert(s.nullable,'nullable required');return;}
  if(s.allOf)s.allOf.forEach((v:any)=>checkSchema(document,v,value));if(s.enum)assert(s.enum.includes(value),'enum');
  if(s.type==='object'){assert(value&&typeof value==='object'&&!Array.isArray(value),'object');for(const k of s.required||[])assert(k in value,'required '+k);for(const [k,v]of Object.entries(value)){if(s.additionalProperties===false)assert(k in s.properties,'unknown '+k);if(s.properties?.[k])checkSchema(document,s.properties[k],v);}}
  if(s.type==='array'){assert(Array.isArray(value),'array');if(s.maxItems!==undefined)assert(value.length<=s.maxItems,'maxItems');value.forEach((v:any)=>checkSchema(document,s.items,v));}
  if(s.type==='string'){assert(typeof value==='string','string');if(s.minLength!==undefined)assert(value.length>=s.minLength,'minLength');if(s.maxLength!==undefined)assert(value.length<=s.maxLength,'maxLength');if(s.pattern)assert(new RegExp(s.pattern).test(value),'pattern');if(s.format==='uuid')assert(/^[a-f\d]{8}-(?:[a-f\d]{4}-){3}[a-f\d]{12}$/i.test(value),'uuid');if(s.format==='date-time')assert(Number.isFinite(Date.parse(value))&&value.includes('T'),'date-time');if(s.format==='uri')assert.doesNotThrow(()=>new URL(value),'uri');}
  if(s.type==='integer'||s.type==='number'){assert(typeof value==='number'&&Number.isFinite(value),'number');if(s.type==='integer')assert(Number.isInteger(value),'integer');if(s.minimum!==undefined)assert(value>=s.minimum,'minimum');if(s.maximum!==undefined)assert(value<=s.maximum,'maximum');}
  if(s.type==='boolean')assert(typeof value==='boolean','boolean');
}
