import sys
sys.path[:0]=['/lab','/offline','/app/apps/media/src']
import media_site
from media import main
try:code=main(offline_allowed=True)
except BaseException:print('{"error":"CONTENT_UNAVAILABLE"}');code=26
sys.exit(code)
