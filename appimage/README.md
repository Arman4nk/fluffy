# Rayka AppImage

Rayka is provided as AppImage too. To Download, visit fluffychat.im.

## Building

- Ensure you install `appimagetool`

```shell
flutter build linux

# copy binaries to appimage dir
cp -r build/linux/{x64,arm64}/release/bundle appimage/Rayka.AppDir
cd appimage

# prepare AppImage files
cp Rayka.desktop Rayka.AppDir/
mkdir -p Rayka.AppDir/usr/share/icons
#cp ../assets/logo.svg Rayka.AppDir/fluffychat.svg
cp AppRun Rayka.AppDir

# build the AppImage
appimagetool Rayka.AppDir
```
