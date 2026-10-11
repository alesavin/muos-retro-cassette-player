# LÖVE runtime goes here

The launcher runs `bin/love` when it exists. To bundle the runtime, copy these
from a LÖVE app already on your muOS device (for example the built-in
Bluetooth app):

```
bin/love
bin/libs.aarch64/*.so
```

These binaries aren't committed to the repo. If `bin/love` is missing, the
launcher falls back to a `love` on `PATH`.
