#!/usr/bin/env bash
# Build the Velocity ISO from any Linux/macOS host that has Docker or Podman.
# On a real Arch box you can skip Docker: sudo scripts/build-iso.sh
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

if [[ -f /etc/arch-release && ${NO_DOCKER:-0} -eq 1 ]]; then
  exec sudo scripts/build-iso.sh "$@"
fi

if command -v docker >/dev/null 2>&1; then RUNTIME=docker
elif command -v podman >/dev/null 2>&1; then RUNTIME=podman
else
  echo "Need docker or podman. On Arch: NO_DOCKER=1 ./build.sh" >&2; exit 1
fi

IMAGE=velocity-builder
${RUNTIME} build -t "${IMAGE}" .
mkdir -p out
# --privileged: mkarchiso needs loop devices and mount.
${RUNTIME} run --rm -it --privileged \
  -v "$(pwd)":/src \
  -v velocity-pacman-cache:/var/cache/pacman/pkg \
  "${IMAGE}" "$@"
