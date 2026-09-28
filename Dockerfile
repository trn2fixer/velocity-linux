# Velocity Linux build environment.
# Usage: ./build.sh (Linux/macOS) or .\build.ps1 (Windows). Both wrap this image.
FROM archlinux:base-devel

RUN pacman -Syu --noconfirm --needed \
      archiso git python python-pillow sudo squashfs-tools libisoburn dosfstools mtools \
    && pacman -Scc --noconfirm \
    && sed -i 's/^#\(ParallelDownloads\)/\1/' /etc/pacman.conf

WORKDIR /src
ENTRYPOINT ["/bin/bash", "scripts/build-iso.sh"]
