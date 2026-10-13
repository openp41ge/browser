# The disk image's contents and Finder window, for dmgbuild (scripts/make-dmg
# passes app and background with -D). The window has no toolbar or sidebar:
# just the app, the Applications folder to drag it onto, and the background
# drawn by app/mac/dmg/background.swift, whose layout this matches. (Finder
# shows its tab bar if the viewer has turned it on for every window.)
import os.path

app = defines["app"]  # noqa: F821 (dmgbuild provides defines)
name = os.path.basename(app)

format = "ULFO"
filesystem = "APFS"
files = [app]
symlinks = {"Applications": "/Applications"}

background = defines["background"]  # noqa: F821
# The background's 640×400, plus the title bar (the size is the window's).
window_rect = ((200, 200), (640, 428))
icon_size = 128
text_size = 13
icon_locations = {
    name: (180, 200),
    "Applications": (460, 200),
}
