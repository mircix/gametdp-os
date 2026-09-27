# vim: set ft=make :

# Install any GameTDP OS apps that are missing (Heroic, Bottles, ProtonPlus, Firefox...)
[group("gametdp")]
gametdp-apps:
    sudo /usr/libexec/gametdp-apps

# Reinstall the whole GameTDP OS app set, including apps you removed
[group("gametdp")]
gametdp-apps-reset:
    sudo rm -f /var/lib/gametdp/flatpaks-installed
    sudo /usr/libexec/gametdp-apps
