#!/bin/bash
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

flutter build linux --release

APP=build/AppDir
rm -rf $APP
mkdir -p $APP/usr/bin $APP/usr/share/icons/hicolor/256x256/apps $APP/usr/share/applications

cp -r build/linux/x64/release/bundle/* $APP/usr/bin/
cp assets/icon/app_icon.png $APP/usr/share/icons/hicolor/256x256/apps/gitopen.png
cp assets/icon/app_icon.png $APP/gitopen.png

cat > $APP/gitopen.desktop <<EOF
[Desktop Entry]
Name=GitOpen
Comment=Cross-platform desktop git client
Exec=gitopen
Icon=gitopen
Type=Application
Categories=Development;RevisionControl;
EOF

cp $APP/gitopen.desktop $APP/usr/share/applications/

cat > $APP/AppRun <<'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f "${0}")")"
exec "${HERE}/usr/bin/gitopen" "$@"
EOF
chmod +x $APP/AppRun

appimagetool $APP build/GitOpen-x86_64.AppImage
