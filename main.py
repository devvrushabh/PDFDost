import os, time
from kivy.app import App
from kivy.clock import Clock
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.button import Button
from kivy.uix.label import Label
from kivy.utils import platform
from PIL import Image, ImageOps


def imgs_to_pdf(paths, out="output.pdf"):
    pages = []
    for p in paths:
        img = ImageOps.exif_transpose(Image.open(p)).convert("RGBA")
        bg = Image.new("RGB", img.size, "white")  # flatten transparency
        bg.paste(img, mask=img)
        pages.append(bg)
    pages[0].save(out, "PDF", save_all=True, append_images=pages[1:],
                  resolution=150.0, quality=95)
    return out


class ImgToPdfApp(App):
    def build(self):
        self.paths = []
        root = BoxLayout(orientation="vertical", padding=24, spacing=16)
        self.status = Label(text="Pick images, then convert.", halign="center")
        self.status.bind(size=lambda w, s: setattr(w, "text_size", s))
        root.add_widget(self.status)
        root.add_widget(Button(text="1. Pick images", size_hint_y=None,
                               height=120, on_release=self.pick))
        root.add_widget(Button(text="2. Convert to PDF", size_hint_y=None,
                               height=120, on_release=self.convert))
        return root

    def say(self, text):
        Clock.schedule_once(lambda dt: setattr(self.status, "text", text))

    def pick(self, *_):
        if platform != "android":
            return self.say("Image picker works on Android only.")
        from androidstorage4kivy import Chooser
        self.chooser = Chooser(self.on_picked)
        self.chooser.choose_content("image/*", multiple=True)

    def on_picked(self, uris):
        from androidstorage4kivy import SharedStorage
        ss = SharedStorage()
        self.paths = [p for p in (ss.copy_from_shared(u) for u in (uris or [])) if p]
        self.say(f"{len(self.paths)} image(s) selected.")

    def convert(self, *_):
        if not self.paths:
            return self.say("Pick images first.")
        try:
            out = os.path.join(self.user_data_dir, f"images_{int(time.time())}.pdf")
            imgs_to_pdf(self.paths, out)
            if platform == "android":
                from androidstorage4kivy import SharedStorage
                SharedStorage().copy_to_shared(out)
                self.say(f"Done: {len(self.paths)} page PDF saved.\nCheck Files > Documents / Downloads.")
            else:
                self.say(f"Saved: {out}")
        except Exception as e:
            self.say(f"Error: {e}")


if __name__ == "__main__":
    ImgToPdfApp().run()
