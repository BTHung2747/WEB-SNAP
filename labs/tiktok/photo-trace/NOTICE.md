# License, API and wiring provenance

This lab is AGPL-3.0 integration code, WED SNAP, 2026-10-10. LICENSE is an unchanged copy of labs/tiktok/photo/LICENSE. Cobalt authors are imput and the Cobalt contributors; their existing photo resolver/helpers remain at labs/tiktok/photo/vendor, commit a636575b09de1fc55d9b8cd98cac88f5f2f16b42. Original NOTICE/PROVENANCE/LICENSE/lock stay unchanged.

No new extractor, DNS resolver, HTTP/TLS stack, solver, dependency, installation, build or private-library monkeypatch. The unchanged photo worker/parent/picker and core GuardedYDL/Budget/Requests/FFmpeg are imported/mounted. The unchanged setup-trace proxy and TraceSink are extended only for bounded receipt/ownership lifecycle; signal shutdown uses documented socketserver.shutdown from a different thread, with unchanged handler behavior and socket limits. New worker glue gates the owned stdin prepare command on proxy trace health; the existing worker has no callback at that boundary.

API sources checked: Python3.11 documentation plus exact v3.11.2 socket/socketserver source; Requests v2.34.2 HTTPAdapter.send; urllib3-2.8.0 documented connection/pool extensions. Installed API source hashes and actual Python3.11.2 at proxy96MiB are in the preflight runtime. Cached media image31742091...dfa417e is used for both roles; the old egress3.12 image is not assumed equivalent.

Offline fixture_origin uses http.server/ssl/socketserver and the existing photo sitecustomize generator in an isolated provider to serve its metadata/JPEG through real Requests and the proxy. Only the proxy-owned public socket dependency is a fixture facade, not the installed library's private methods. Source mode never loads it. Ephemeral fixture CA augments the original cache bundle only offline; verify=True remains enforced. Two offline networks are internal. Live uses one internal worker network and one own outbound proxy network, no fixture CA/control.

The first network fixture failed because runpy.run_path temporarily changes sys.argv[0], preventing the existing worker-only fixture guard. A network-none proof on Python3.11.2 verified no FakeSession with runpy and the expected class with the documented importlib source-file loader. The fixture now uses importlib.util.spec_from_file_location/module_from_spec/loader.exec_module, restoring Requests.Session and argv/environment afterward; no live transport override.

Sources:
- https://raw.githubusercontent.com/python/cpython/v3.11.2/Lib/socket.py
- https://github.com/python/cpython/blob/v3.11.2/Lib/socketserver.py
- https://docs.python.org/3.11/library/socketserver.html
- https://docs.python.org/3.11/library/signal.html
- https://github.com/psf/requests/blob/v2.34.2/src/requests/adapters.py
- https://urllib3.readthedocs.io/en/2.8.0/reference/urllib3.connection.html
- https://docs.python.org/3.11/library/runpy.html
- https://docs.python.org/3.11/library/importlib.html#importing-a-source-file-directly

