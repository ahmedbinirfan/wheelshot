# Wheelshot

Wheelshot is a macOS menu-bar app. Click the scroll wheel and macOS starts a region screenshot, the same action as Control-Shift-Command-4. Left click, right click, and moving the mouse are left alone. Wheelshot does not capture the screen itself. It asks macOS to open the normal screenshot tool.

The app has no Dock icon. After it is running, its mark sits in the menu bar.

## What you need

- A Mac on macOS 13 or later
- A mouse with a clickable scroll wheel
- Xcode Command Line Tools, which include the Swift compiler. If `swiftc` is missing, install them with `xcode-select --install`
- Accessibility permission for Wheelshot. macOS asks for this the first time the app opens

## Download and run

```bash
git clone https://github.com/ahmedbinirfan/wheelshot.git
cd wheelshot
./build.sh
open "$HOME/Applications/Wheelshot.app"
```

`./build.sh` compiles the app and installs it at `~/Applications/Wheelshot.app`.

When macOS asks, turn Accessibility on. Open the menu-bar mark. It should say **Listening**, and the screenshot button is the scroll wheel. Drag to choose the region. macOS saves the picture the same way its own shortcut does.

If a click does nothing, open the menu and choose **Turn on Accessibility…**.
