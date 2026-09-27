#!/usr/bin/bash
# Runs inside the freshly built image (`just smoke-test`) and fails on the first GameTDP OS
# change that is missing, so a broken image never gets pushed.

set -euo pipefail

ok() { echo "ok: $*"; }

grep -qx 'NAME="GameTDP OS"' /usr/lib/os-release && ok "os-release name"
grep -qx 'ID=bazzite' /usr/lib/os-release && ok "os-release ID left as bazzite"
grep -q '^GameTDP OS release' /etc/system-release && ok "system-release"

INFO=/usr/share/ublue-os/image-info.json
test "$(jq -r '."image-name"' "$INFO")" = gametdp-os
test "$(jq -r '."image-vendor"' "$INFO")" = mircix
test "$(jq -r '."image-ref"' "$INFO")" = "ostree-image-signed:docker://ghcr.io/mircix/gametdp-os"
ok "image-info.json"

WALL=/usr/share/wallpapers/GameTDP/contents/images/3840x2160.jxl
test -s "$WALL"
for f in default.jxl default-dark.jxl; do
    test "$(readlink -f "/usr/share/backgrounds/$f")" = "$WALL"
done
ok "default wallpaper"

LAYOUT=/usr/share/plasma/layout-templates/org.kde.plasma.desktop.defaultPanel/contents/layout.js
grep -q '"gametdp-logo"' "$LAYOUT" && ok "panel script appended"
test -s /usr/share/icons/hicolor/256x256/apps/gametdp-logo.png && ok "logo icon"
grep -q '^Name=GameTDP OS' /etc/xdg/kcm-about-distrorc && ok "KDE About page"
grep -q /usr/share/gametdp/logo.txt /usr/share/ublue-os/bazzite/fastfetch.jsonc && ok "fastfetch logo"
grep -q 'Welcome to GameTDP OS' /usr/share/ublue-os/motd/template.md && ok "terminal greeting"

test -L /etc/systemd/system/multi-user.target.wants/gametdp-apps.service && ok "gametdp-apps.service enabled"
test -x /usr/libexec/gametdp-apps && ok "app installer executable"
just --justfile /usr/share/ublue-os/justfile --summary | tr ' ' '\n' | grep -qx gametdp-apps && ok "ujust gametdp-apps"

jq -e '.transports.docker["ghcr.io/mircix/gametdp-os"][0].keyPath == "/etc/pki/containers/gametdp-os.pub"' \
    /etc/containers/policy.json >/dev/null && ok "signature policy"
grep -q 'BEGIN PUBLIC KEY' /etc/pki/containers/gametdp-os.pub && ok "signing public key"

# Repos switched off in dnf5 overrides must be off in the .repo files too (the ISO builder only reads those)
enabled_in_files=$(awk '/^\[/ { id = substr($0, 2, length($0) - 2) } /^enabled[[:space:]]*=[[:space:]]*(1|true|True)/ { print id }' /etc/yum.repos.d/*.repo | sort -u)
disabled_by_override=$(cat /etc/dnf/repos.override.d/*.repo 2>/dev/null |
    awk '/^\[/ { id = substr($0, 2, length($0) - 2) } /^enabled[[:space:]]*=[[:space:]]*(0|false|False)/ { print id }' | sort -u)
conflicts=$(comm -12 <(echo "$enabled_in_files") <(echo "$disabled_by_override") | grep -v '^$' || true)
if [[ -n "$conflicts" ]]; then
    echo "repos enabled in /etc/yum.repos.d but disabled by dnf5 overrides: $conflicts" >&2
    exit 1
fi
ok "repo files agree with dnf5 overrides (enabled: $(echo "$enabled_in_files" | tr '\n' ' '))"

KVER=$(ls /usr/lib/modules)
lsinitrd -f usr/share/plymouth/themes/spinner/watermark.png "/usr/lib/modules/$KVER/initramfs.img" |
    cmp - /usr/share/plymouth/themes/spinner/watermark.png && ok "boot splash logo in initramfs"

# Every app in the list must exist on Flathub, or the first-boot installer would retry forever
flatpak remote-add --if-not-exists --system flathub /etc/flatpak/remotes.d/flathub.flatpakrepo
while read -r ref; do
    [[ -z "$ref" || "$ref" == \#* ]] && continue
    flatpak remote-info --system flathub "$ref" </dev/null >/dev/null
    ok "on Flathub: $ref"
done </usr/share/gametdp/flatpaks
