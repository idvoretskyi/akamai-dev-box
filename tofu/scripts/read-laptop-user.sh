#!/usr/bin/env bash
# Emit the local username as JSON for the `external` data source.
# Precedence: $DEVBOX_USER (explicit override) -> $USER -> id -un.
set -euo pipefail

user="${DEVBOX_USER:-${USER:-$(id -un)}}"
printf '{"username":"%s"}\n' "$user"
