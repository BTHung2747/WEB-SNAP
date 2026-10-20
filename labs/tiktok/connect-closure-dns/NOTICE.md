# Successor lab: closure barriers and threaded DNS

Uses unmodified aiohappyeyeballs 2.7.1 vendor from labs/tiktok/connect-poc/vendor,
PSF-2.0 LICENSE by J. Nick Koston/contributors retained there. Tag/commit/wheel and
file hashes are in predecessor PROVENANCE and this lab's PROVENANCE/requirements.lock.
No installed package/image/application dependency change.

candidate/test/supervisor/runner glue derives from the predecessor PoC; this lab
owns its edits only. owned_fixture derives from photo-trace fixture; AGPL-3.0
original LICENSE/NOTICE/Cobalt authors remain in photo/core, imported unchanged.
Only public API integration: Popen bounded stdin/stdout, close_fds/start_new_session,
selectors, Event/Condition, socketserver finish/shutdown/close hooks and start_connection.
No private helper calls, race, parser, resolver, HTTP/TLS transport rewrite.

Fixtures are numeric/localhost only under network-none. Child delegates actual
socket.getaddrinfo; process cancellation/containment is measured, not a guarantee
about external OS DNS/kernel D-state or hard realtime. Threaded Popen helper has no
Python fork context/preexec_fn/resource_tracker. A closure barrier is a new tested
contract; it does not prove the cause of historical TLS FAIL (still UNKNOWN).
