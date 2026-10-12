[app]
title = PDFDost
package.name = img2pdf
package.domain = org.example
source.dir = .
source.include_exts = py
version = 0.2
icon.filename = %(source.dir)s/PDFDost-icon.png
requirements = python3,kivy,pillow,android,androidstorage4kivy,charset-normalizer==2.1.1
orientation = portrait
fullscreen = 0
android.archs = arm64-v8a
android.api = 33
android.minapi = 24
android.accept_sdk_license = True
android.enable_androidx = True
android.permissions = READ_EXTERNAL_STORAGE,WRITE_EXTERNAL_STORAGE,READ_MEDIA_IMAGES
p4a.branch = develop

[buildozer]
log_level = 2
warn_on_root = 1
