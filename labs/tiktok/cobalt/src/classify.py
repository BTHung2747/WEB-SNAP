# AGPL-3.0 lab glue: use pinned yt-dlp HTML helpers; never invoke its challenge solver.
import base64,hashlib,importlib.metadata,json,pathlib,sys
import yt_dlp
from yt_dlp.utils import extract_attributes,find_element,traverse_obj

def classify(html):
    # Same read-only helper pipeline as TikTokBaseIE._solve_challenge_and_set_cookies.
    # No digest search, cookie creation, request, or challenge execution.
    def attr(element_id):
        return traverse_obj(html,({find_element(id=element_id,html=True)},{extract_attributes},'class',{str}))
    data=traverse_obj(html,({find_element(id='cs',html=True)},{extract_attributes},'class',
                          filter,{lambda x:f'{x}==='},{base64.b64decode},{json.loads},{dict}))
    return {'csElement':bool(attr('cs')),'wciElement':bool(attr('wci')),
            'rciElement':bool(attr('rci')),'rsElement':bool(attr('rs')),
            'challengeDataJSON':bool(data),
            'challengeDigestFields':bool(traverse_obj(data,('v','a',{str}))) and bool(traverse_obj(data,('v','c',{str}))),
            'pleaseWaitText':'Please wait...' in html,
            'rehydrationElement':bool(traverse_obj(html,({find_element(id='__UNIVERSAL_DATA_FOR_REHYDRATION__',html=True)})))}

if __name__=='__main__':
    try:
        if yt_dlp.version.__version__!='2026.08.19':raise RuntimeError('VERSION_MISMATCH')
        path=pathlib.Path(importlib.metadata.distribution('yt-dlp').locate_file('yt_dlp/extractor/tiktok.py'))
        if hashlib.sha256(path.read_bytes()).hexdigest()!='3257fdea744811ea2e1bfee665a97d6ab85517339ee672f2e43e238e6b997c9e':raise RuntimeError('SOURCE_HASH_MISMATCH')
        raw=sys.stdin.buffer.read(8*1024*1024+1)
        if len(raw)>8*1024*1024:raise RuntimeError('LIMIT_EXCEEDED')
        print(json.dumps(classify(raw.decode('utf8'))))
    except Exception:
        # Never expose HTML/class/token or library exception payload.
        print(json.dumps({'classifier':'FAIL'}));sys.exit(30)
