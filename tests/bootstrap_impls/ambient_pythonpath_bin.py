"""Import a declared namespace package before unrelated ambient packages."""

import os

from python.runfiles import runfiles

if os.environ.get("VERIFY_AMBIENT_FALLBACK") == "1":
    import ambient_only

    assert ambient_only.IDENTITY == "ambient-only"
    print("AMBIENT_FALLBACK_OK")

print("DECLARED_RUNFILES:", runfiles.__file__)
