#!/bin/bash
# GameTDP OS build steps. Runs once inside the Bazzite base image (see Containerfile).

set -ouex pipefail

IMAGE_NAME="gametdp-os"
IMAGE_VENDOR="mircix"
PRETTY_NAME="GameTDP OS"
REPO_URL="https://github.com/${IMAGE_VENDOR}/${IMAGE_NAME}"
IMAGE_REPO="ghcr.io/${IMAGE_VENDOR}/${IMAGE_NAME}"

### Files: branding, app list, first-boot service, ujust recipes, signing key
cp -avf "/ctx/system_files"/. /
chmod 0755 /usr/libexec/gametdp-apps

### Identity
# image-info.json is what Bazzite's own tools (updater, rollback helper, motd, fastfetch) read.
# "stable" matches the tag this image is published under.
jq --arg name "$IMAGE_NAME" --arg vendor "$IMAGE_VENDOR" \
    --arg ref "ostree-image-signed:docker://${IMAGE_REPO}" \
    '."image-name" = $name | ."image-vendor" = $vendor | ."image-ref" = $ref | ."image-tag" = "stable"' \
    /usr/share/ublue-os/image-info.json >/tmp/image-info.json
cp /tmp/image-info.json /usr/share/ublue-os/image-info.json

# ID stays "bazzite" (ID_LIKE=fedora) on purpose: Bazzite's scripts and the installer key off it.
sed -i \
    -e "s|^NAME=.*|NAME=\"${PRETTY_NAME}\"|" \
    -e "s|^PRETTY_NAME=.*|PRETTY_NAME=\"${PRETTY_NAME}\"|" \
    -e "s|^HOME_URL=.*|HOME_URL=\"${REPO_URL}\"|" \
    -e "s|^DOCUMENTATION_URL=.*|DOCUMENTATION_URL=\"${REPO_URL}#readme\"|" \
    -e "s|^SUPPORT_URL=.*|SUPPORT_URL=\"${REPO_URL}/issues\"|" \
    -e "s|^BUG_REPORT_URL=.*|BUG_REPORT_URL=\"${REPO_URL}/issues\"|" \
    -e "s|^DEFAULT_HOSTNAME=.*|DEFAULT_HOSTNAME=\"gametdp\"|" \
    -e "s|^LOGO=.*|LOGO=gametdp-logo|" \
    -e "s|^ANSI_COLOR=.*|ANSI_COLOR=\"0;38;2;177;120;211\"|" \
    -e "s|^BOOTLOADER_NAME=\"Bazzite|BOOTLOADER_NAME=\"${PRETTY_NAME}|" \
    -e "s|^IMAGE_ID=.*|IMAGE_ID=\"${IMAGE_NAME}-$(date -u +%Y%m%d%H%M)\"|" \
    /usr/lib/os-release
# grub2-mkconfig takes the boot menu name from here
echo "${PRETTY_NAME} release $(rpm -E %fedora) (Kinoite)" >/etc/system-release

### Look and feel
# Default wallpaper for the desktop, lock screen and login screen (Bazzite points these links at its own)
for f in default.jxl default-dark.jxl; do
    ln -sf /usr/share/wallpapers/GameTDP/contents/images/3840x2160.jxl "/usr/share/backgrounds/$f"
done

# Start-menu logo and taskbar pins, applied when a user's first panel is created
cat /usr/share/gametdp/plasma-panel.js >>/usr/share/plasma/layout-templates/org.kde.plasma.desktop.defaultPanel/contents/layout.js

# fastfetch banner and terminal greeting
FASTFETCH=/usr/share/ublue-os/bazzite/fastfetch.jsonc
sed -i \
    -e 's|/usr/share/ublue-os/bazzite/logo.txt|/usr/share/gametdp/logo.txt|' \
    -e 's|"1": "94"|"1": "38;2;177;120;211"|' \
    -e 's|"2": "47"|"2": "38;2;205;28;12"|' \
    "$FASTFETCH"
grep -q /usr/share/gametdp/logo.txt "$FASTFETCH"

MOTD=/usr/share/ublue-os/motd/template.md
sed -i 's|^# Welcome to Bazzite|# Welcome to GameTDP OS|' "$MOTD"
# shellcheck disable=SC2016 # the backticks are literal Markdown
sed -i '/`ujust --choose`/a | `ujust gametdp-apps` | Install any missing GameTDP apps (Heroic, Bottles...) |' "$MOTD"
grep -q 'GameTDP OS' "$MOTD"

### Apps and commands
systemctl enable gametdp-apps.service
echo 'import "/usr/share/ublue-os/just/96-gametdp.just"' >>/usr/share/ublue-os/justfile

### RemoteMyOS: remote desktop (like AnyDesk) that works on KDE Wayland
# The app goes to /usr/lib/remotemyos; its menu entry and login autostart come from system_files.
# The .desktop file name is the app ID KDE uses to remember the remote-control permission.
# shellcheck disable=SC1091
source /ctx/remotemyos.env
curl -fsSL --retry 3 -o /tmp/remotemyos.tar.gz \
    "${REPO_URL}/releases/download/remotemyos-v${REMOTEMYOS_VERSION}/RemoteMyOS-${REMOTEMYOS_VERSION}-linux-x64.tar.gz"
echo "${REMOTEMYOS_SHA256}  /tmp/remotemyos.tar.gz" | sha256sum -c -
tar -xzf /tmp/remotemyos.tar.gz -C /tmp
mkdir -p /usr/lib/remotemyos
cp -a "/tmp/RemoteMyOS-${REMOTEMYOS_VERSION}-linux-x64/RemoteMyOS/." /usr/lib/remotemyos/
chmod 0755 /usr/lib/remotemyos/remotemyos /usr/lib/remotemyos/resources/bin/remotemyos-agent
ln -sf /usr/lib/remotemyos/remotemyos /usr/bin/remotemyos
rm -rf /tmp/remotemyos.tar.gz "/tmp/RemoteMyOS-${REMOTEMYOS_VERSION}-linux-x64"
# Sharing the screen needs GStreamer's PipeWire source and an H.264 encoder (VA-API on the GPU,
# OpenH264 as the CPU fallback). Installed by file so dnf picks whichever package provides it.
dnf5 -y install --enable-repo=fedora-cisco-openh264 --skip-unavailable \
    /usr/lib64/gstreamer-1.0/libgstpipewire.so \
    /usr/lib64/gstreamer-1.0/libgstva.so \
    /usr/lib64/gstreamer-1.0/libgstopenh264.so \
    /usr/bin/gst-launch-1.0 \
    /usr/bin/wl-paste

### Updates: only accept GameTDP OS images signed with this repo's cosign key
jq --arg repo "$IMAGE_REPO" \
    '.transports.docker[$repo] = [{
        "type": "sigstoreSigned",
        "keyPath": "/etc/pki/containers/gametdp-os.pub",
        "signedIdentity": {"type": "matchRepository"}
    }]' \
    /etc/containers/policy.json >/tmp/policy.json
cp /tmp/policy.json /etc/containers/policy.json

### Package repos
# bootc-image-builder (which makes the installer ISO) reads /etc/yum.repos.d but not dnf5's
# repos.override.d, so repos Bazzite switched off there (terra-mesa) still look enabled to it and
# break the ISO build. Write those "off" settings into the .repo files too; dnf5 already treats
# them as off, so the installed system behaves the same.
for override in /etc/dnf/repos.override.d/*.repo; do
    [[ -e "$override" ]] || continue
    awk '/^\[/ { id = substr($0, 2, length($0) - 2) } /^enabled[[:space:]]*=[[:space:]]*(0|false|False)/ { print id }' "$override"
done | sort -u | while read -r id; do
    for repo in /etc/yum.repos.d/*.repo; do
        sed -i "/^\[${id}\]/,/^\[/ s/^enabled[[:space:]]*=[[:space:]]*\(1\|true\|True\)[[:space:]]*$/enabled=0/" "$repo"
    done
done

### Initramfs
# The boot splash logo and os-release are baked into the initramfs, so rebuild it
# (same dracut options Bazzite uses).
mapfile -t KERNELS < <(ls /usr/lib/modules)
if [[ ${#KERNELS[@]} -ne 1 ]]; then
    echo "Expected exactly one kernel, found: ${KERNELS[*]}" >&2
    exit 1
fi
KVER="${KERNELS[0]}"
/usr/bin/dracut --no-hostonly --kver "$KVER" --reproducible --zstd -v --add ostree --add fido2 \
    -f "/usr/lib/modules/$KVER/initramfs.img"
chmod 0600 "/usr/lib/modules/$KVER/initramfs.img"
