"""AGPL-3.0 CLI glue; each invocation owns one fresh photo core call."""
import json
import os
from .photo_contract import PhotoError


def main(args):
    try:
        if (os.environ.get('TIKTOK_ADAPTER_ENABLED') != '1'
                or os.environ.get('TIKTOK_PHOTO_ENABLED') != '1'
                or 'tiktok' not in os.environ.get('VERIFIED_PLATFORMS', '').split(',')):
            print(json.dumps({'error': 'UNSUPPORTED_PLATFORM'}))
            return 1
        if len(args) not in (3, 4) or args[0] not in ('analyze', 'prepare') or len(args) != (3 if args[0] == 'analyze' else 4):
            print(json.dumps({'error': 'UNSUPPORTED_CONTENT'}))
            return 1
        from .photo_proxy import phase_credentials
        phase_credentials()
        from .photo_core import analyze_album, prepare_photo
        result = analyze_album(args[1], args[2]) if args[0] == 'analyze' else prepare_photo(args[1], args[2], args[3])
        print(json.dumps(result, ensure_ascii=False, allow_nan=False))
        return 0
    except Exception as error:
        print(json.dumps({'error': error.code if isinstance(error, PhotoError) else 'CONTENT_UNAVAILABLE'}))
        return 1
