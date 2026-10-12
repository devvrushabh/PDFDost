[app]
title = Img2PDF
package.name = img2pdf
package.domain = org.example
source.dir = .
source.include_exts = py
version = 0.1
requirements = python3,kivy,pillow,android,androidstorage4kivy
orientation = portrait
fullscreen = 0
android.archs = arm64-v8a
android.api = 33
android.minapi = 24
android.accept_sdk_license = True
android.enable_androidx = True

[buildozer]
log_level = 2
warn_on_root = 1
