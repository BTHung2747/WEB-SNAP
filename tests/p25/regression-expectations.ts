// P24 controls inherited without modifying frozen history. Delta measured in P25
// HTTP before source edit: malformed JSON400/INTERNAL_ERROR at every target,
// malformed URI400 at parameter routes. No blanket HttpException status invention.
import {expected as history} from '../p24/expectations';
export {states,jobKeys,sessionKeys,sourceRefs} from '../p24/expectations';
export const expected=history.map(([name,method,path,status,errors,auth])=>[
  name,method,path,status,{...errors,400:[...('400' in errors?errors[400]:[]),'INTERNAL_ERROR']},auth,
] as const);
