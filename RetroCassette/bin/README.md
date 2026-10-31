# LÖVE runtime goes here

The launcher runs `bin/love` when it exists. To bundle a runtime, copy these
from a LÖVE app already on your muOS device (for example
`/opt/muos/share/application/2048 Plus/.game/bin/`):

```
bin/love
bin/libs.aarch64/*.so
```

This is optional. These binaries aren't committed to the repo. If `bin/love`
is missing, the launcher uses the runtime muOS ships with 2048 Plus
(`/opt/muos/share/application/2048 Plus/.game/bin`), then a `love` on `PATH`.

muOS refuses archives that contain symlinks, so copy real files (the
packaging script's `zip -r` stores symlink targets as files).
