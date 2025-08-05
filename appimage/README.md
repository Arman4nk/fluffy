# Chatsi AppImage

Chatsi is provided as AppImage too. To Download, visit fluffychat.im.

## Building

- Ensure you install `appimagetool`

```shell
flutter build linux

# copy binaries to appimage dir
cp -r build/linux/{x64,arm64}/release/bundle appimage/Chatsi.AppDir
cd appimage

# prepare AppImage files
cp Chatsi.desktop Chatsi.AppDir/
mkdir -p Chatsi.AppDir/usr/share/icons
#cp ../assets/logo.svg Chatsi.AppDir/fluffychat.svg
cp AppRun Chatsi.AppDir

# build the AppImage
appimagetool Chatsi.AppDir
```
