# Successor authority mount — prepared offline, no source permission

Original candidate stays in photo-album-execution-namespace. This copy changes only
host mount wiring and successor paths. Runtime Python/Cobalt/photo/vendor bytes,
readers, canonical claim/latch binds, API and quota remain unchanged. authority_mount
copies the validated release to a new owned mount tree, verifies copy SHA and creates
empty targets before mounting parent RO plus canonical children RO. No release,
claim or latch history is changed. No real release or source grant is provided.

Docker official bind mount API: https://docs.docker.com/engine/storage/bind-mounts/.
Use --mount type=bind,source=...,target=...,readonly; no bind-create-src, mount
propagation change, RW parent, host/security change or dependency installation.
