"""Exact mounted-source gate and version capture before fixtures; offline only."""
import hashlib
import importlib.metadata as md
import inspect
import json
import pathlib
import subprocess
import sys

ROOT = pathlib.Path('/app/apps/media/src/tiktok')
OUT = pathlib.Path('/out')
expected = json.loads((OUT/'expected-source.json').read_text())
for row in expected:
    assert hashlib.sha256((ROOT/row['path']).read_bytes()).hexdigest() == row['sha256']
from tiktok.core import versions
from tiktok.photo_core import analyze_album, prepare_photo
import requests
import urllib3
import yt_dlp
api = dict(image='sha256:31742091e95df2cc62669a6c6a9e0892dc09a34341eaeefc16959dcd4dfa417e',
           versions=versions(), python=sys.version,
           extractInfo=str(inspect.signature(yt_dlp.YoutubeDL.extract_info)),
           adapterSend=str(inspect.signature(requests.adapters.HTTPAdapter.send)),
           rawRead=str(inspect.signature(urllib3.HTTPResponse.read)),
           ffmpeg=subprocess.check_output(['ffmpeg','-version']).decode().splitlines()[0],
           node=subprocess.check_output(['node','--version']).decode().strip(),
           verifiedSourceFiles=len(expected), sourceCalls=0)
(OUT/'runtime.json').write_text(json.dumps(api, indent=2))
from check import suite
code=suite()
for row in expected:
    assert hashlib.sha256((ROOT/row['path']).read_bytes()).hexdigest() == row['sha256']
sys.exit(code)
