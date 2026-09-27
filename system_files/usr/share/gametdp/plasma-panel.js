
// GameTDP OS: start-menu logo and taskbar pins (appended to the default panel layout,
// so it runs once when a user's first panel is created). Block-scoped so it cannot clash
// with the other scripts in this file.
{
    const gametdpPanels = panels();
    for (let i = 0; i < gametdpPanels.length; ++i) {
        const gametdpWidgets = gametdpPanels[i].widgets();
        for (let j = 0; j < gametdpWidgets.length; ++j) {
            const gametdpWidget = gametdpWidgets[j];
            if (gametdpWidget.type === "org.kde.plasma.kickoff") {
                gametdpWidget.currentConfigGroup = ["General"];
                gametdpWidget.writeConfig("icon", "gametdp-logo");
                gametdpWidget.reloadConfig();
            }
            if (gametdpWidget.type === "org.kde.plasma.icontasks") {
                gametdpWidget.currentConfigGroup = ["General"];
                gametdpWidget.writeConfig("launchers", [
                    "preferred://browser",
                    "applications:steam.desktop",
                    "applications:com.heroicgameslauncher.hgl.desktop",
                    "applications:net.lutris.Lutris.desktop",
                    "applications:com.usebottles.bottles.desktop",
                    "applications:io.github.kolunmi.Bazaar.desktop",
                    "applications:org.kde.konsole.desktop",
                    "preferred://filemanager"
                ]);
                gametdpWidget.reloadConfig();
            }
        }
    }
}
