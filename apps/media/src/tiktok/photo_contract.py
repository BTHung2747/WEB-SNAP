"""AGPL-3.0 WED SNAP glue, derived from the tested album_contract.py.

Fingerprints bind public structure, NOT image pixels or an upstream image ID.
No transport, credentials, authority records or multi-file ledger lives here.
"""
import hashlib
import json
import re

VERSION = 'tt-photo-album-v1'
ID = re.compile(r'[0-9]{15,22}')
FORMAT = re.compile(r'ttp1_([0-9]{2})_([a-f0-9]{64})')
CODES = frozenset({
    'PHOTO_METADATA', 'PHOTO_INDEX', 'PHOTO_DIMENSIONS', 'PHOTO_SELECTION',
    'PHOTO_SNAPSHOT', 'PHOTO_METADATA_UNAVAILABLE', 'INVALID_URL',
    'INVALID_ASSET_PATH', 'PREEXISTING_OUTPUT', 'OUTPUT_COLLISION',
    'JPEG_REQUIRED', 'STATIC_IMAGE_REQUIRED', 'DIMENSION_MISMATCH',
    'LIMIT_EXCEEDED', 'SOURCE_TIMEOUT', 'CONTENT_UNAVAILABLE', 'CANCELLED',
    'CLEANUP_FAILED',
})


class PhotoError(Exception):
    """Only fixed, public codes; never retain a library message in arguments."""
    def __init__(self, code):
        self.code = code if code in CODES else 'CONTENT_UNAVAILABLE'
        super().__init__(self.code)


def require(ok, code):
    if not ok:
        raise PhotoError(code)


def integer(value, lo, hi):
    return type(value) is int and lo <= value <= hi


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False).encode()


def key(value):
    return hashlib.sha256(canonical(value)).hexdigest()


def summary(private, expected):
    require(type(expected) is str and ID.fullmatch(expected), 'PHOTO_METADATA')
    require(type(private) is dict and set(private) == {'id', 'type', 'images'}
            and private['id'] == expected and private['type'] == 'photo', 'PHOTO_METADATA')
    images = private['images']
    require(type(images) is list and 1 <= len(images) <= 50, 'PHOTO_METADATA')
    rows = []
    for index, image in enumerate(images, 1):
        require(type(image) is dict and set(image) == {'index', 'url', 'width', 'height'}, 'PHOTO_METADATA')
        require(integer(image['index'], index, index), 'PHOTO_INDEX')
        w, h = image['width'], image['height']
        require(integer(w, 1, 8192) and integer(h, 1, 8192) and w * h <= 16000000, 'PHOTO_DIMENSIONS')
        require(type(image['url']) is str, 'PHOTO_METADATA')  # URL policy belongs to the pinned bridge/transport.
        rows.append(dict(index=index, width=w, height=h, itemKey=key([expected, 'photo', index, w, h])))
    public = dict(version=VERSION, id=expected, type='photo', imageCount=len(rows), images=rows)
    public['snapshotKey'] = key(public)
    return public


def validate_summary(value, expected):
    require(type(value) is dict and set(value) == {'version', 'id', 'type', 'imageCount', 'images', 'snapshotKey'}, 'PHOTO_METADATA')
    require(type(expected) is str and ID.fullmatch(expected) and value['version'] == VERSION
            and value['id'] == expected and value['type'] == 'photo', 'PHOTO_METADATA')
    count = value['imageCount']
    require(integer(count, 1, 50) and type(value['images']) is list and len(value['images']) == count, 'PHOTO_METADATA')
    for index, row in enumerate(value['images'], 1):
        require(type(row) is dict and set(row) == {'index', 'width', 'height', 'itemKey'}, 'PHOTO_METADATA')
        require(integer(row['index'], index, index), 'PHOTO_INDEX')
        w, h = row['width'], row['height']
        require(integer(w, 1, 8192) and integer(h, 1, 8192) and w * h <= 16000000, 'PHOTO_DIMENSIONS')
        require(type(row['itemKey']) is str and row['itemKey'] == key([expected, 'photo', index, w, h]), 'PHOTO_SNAPSHOT')
    require(type(value['snapshotKey']) is str
            and value['snapshotKey'] == key({k: v for k, v in value.items() if k != 'snapshotKey'}), 'PHOTO_SNAPSHOT')
    return value


def format_id(meta, index):
    validate_summary(meta, meta.get('id') if type(meta) is dict else None)
    require(integer(index, 1, meta['imageCount']), 'PHOTO_INDEX')
    return f"ttp1_{index:02d}_{meta['snapshotKey']}"


def select(meta, selected):
    validate_summary(meta, meta.get('id') if type(meta) is dict else None)
    match = FORMAT.fullmatch(selected) if type(selected) is str else None
    require(match is not None, 'PHOTO_SELECTION')
    index = int(match[1])
    require(integer(index, 1, meta['imageCount']), 'PHOTO_INDEX')
    require(match[2] == meta['snapshotKey'], 'PHOTO_SNAPSHOT')
    return dict(meta['images'][index - 1])


def public_metadata(meta):
    validate_summary(meta, meta.get('id') if type(meta) is dict else None)
    formats = [dict(id=format_id(meta, row['index']), label=f"Ảnh {row['index']}/{meta['imageCount']}",
                    size=None, kind='photo', contentId=meta['id'], imageCount=meta['imageCount'],
                    mime='image/jpeg', snapshotKey=meta['snapshotKey'], **row) for row in meta['images']]
    return dict(kind='photo', title='Album TikTok', duration=None, summary=meta, formats=formats)
