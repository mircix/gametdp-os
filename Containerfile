# GameTDP OS — a gaming-first Linux desktop for AMD PCs.
# Built on Bazzite (Fedora Atomic + KDE Plasma + Steam/Proton, AMD Mesa drivers).

# Build scripts and files are mounted from this stage, so they don't end up in the image
FROM scratch AS ctx
COPY build_files /
COPY system_files /system_files

# Bazzite desktop edition (AMD/Intel graphics, KDE Plasma). Rebuilt daily, so every
# GameTDP OS build picks up the latest Bazzite stable release.
FROM ghcr.io/ublue-os/bazzite:stable

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
