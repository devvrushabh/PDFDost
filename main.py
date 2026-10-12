import os
import threading
import time
from kivy.app import App
from kivy.clock import Clock
from kivy.core.window import Window
from kivy.lang import Builder
from kivy.metrics import dp, sp
from kivy.properties import BooleanProperty, ListProperty, NumericProperty, StringProperty
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.image import Image
from kivy.uix.label import Label
from kivy.uix.widget import Widget
from kivy.utils import platform
from PIL import Image as PILImage, ImageOps

# iLovePDF Modern Light Theme Background
Window.clearcolor = (0.972, 0.976, 0.984, 1)

KV_DESIGN = """
#:import dp kivy.metrics.dp
#:import sp kivy.metrics.sp

<PrimaryButton@Button>:
    background_normal: ''
    background_down: ''
    background_color: (0, 0, 0, 0)
    font_size: '16sp'
    bold: True
    color: (1, 1, 1, 1) if not self.disabled else (0.6, 0.6, 0.6, 1)
    canvas.before:
        Color:
            rgba: (0.75, 0.12, 0.10, 1) if self.state == 'down' else ((0.898, 0.196, 0.176, 1) if not self.disabled else (0.86, 0.86, 0.88, 1))
        RoundedRectangle:
            pos: self.pos
            size: self.size
            radius: [dp(14), dp(14), dp(14), dp(14)]

<OutlineButton@Button>:
    background_normal: ''
    background_down: ''
    background_color: (0, 0, 0, 0)
    font_size: '14sp'
    bold: True
    color: (0.898, 0.196, 0.176, 1) if not self.disabled else (0.6, 0.6, 0.6, 1)
    canvas.before:
        Color:
            rgba: (1, 0.92, 0.92, 1) if self.state == 'down' else (1, 1, 1, 1)
        RoundedRectangle:
            pos: self.pos
            size: self.size
            radius: [dp(12), dp(12), dp(12), dp(12)]
        Color:
            rgba: (0.898, 0.196, 0.176, 1) if not self.disabled else (0.80, 0.80, 0.82, 1)
        Line:
            rounded_rectangle: (self.x, self.y, self.width, self.height, dp(12))
            width: dp(1.5)

<DangerTextButton@Button>:
    background_normal: ''
    background_down: ''
    background_color: (0, 0, 0, 0)
    font_size: '13sp'
    bold: True
    color: (0.898, 0.196, 0.176, 1) if self.state != 'down' else (0.65, 0.1, 0.1, 1)

<HeaderBar@BoxLayout>:
    size_hint_y: None
    height: dp(60)
    padding: [dp(16), dp(8), dp(16), dp(8)]
    spacing: dp(10)
    canvas.before:
        Color:
            rgba: (1, 1, 1, 1)
        Rectangle:
            pos: self.pos
            size: self.size
        Color:
            rgba: (0.90, 0.91, 0.93, 1)
        Line:
            points: [self.x, self.y, self.right, self.y]
            width: dp(1)

<HeroUploadCard@BoxLayout>:
    orientation: 'vertical'
    padding: [dp(24), dp(28), dp(24), dp(28)]
    spacing: dp(16)
    canvas.before:
        Color:
            rgba: (1, 1, 1, 1)
        RoundedRectangle:
            pos: self.pos
            size: self.size
            radius: [dp(20), dp(20), dp(20), dp(20)]
        Color:
            rgba: (0.898, 0.196, 0.176, 0.4)
        Line:
            rounded_rectangle: (self.x, self.y, self.width, self.height, dp(20))
            width: dp(1.8)

<StatusBanner@BoxLayout>:
    size_hint_y: None
    height: dp(54)
    padding: [dp(16), dp(8), dp(16), dp(8)]
    bg_color: (0.94, 0.98, 0.95, 1)
    border_color: (0.3, 0.75, 0.45, 1)
    canvas.before:
        Color:
            rgba: self.bg_color
        RoundedRectangle:
            pos: self.pos
            size: self.size
            radius: [dp(12), dp(12), dp(12), dp(12)]
        Color:
            rgba: self.border_color
        Line:
            rounded_rectangle: (self.x, self.y, self.width, self.height, dp(12))
            width: dp(1.2)

<MainScreen>:
    orientation: 'vertical'
    spacing: 0

    # 1. Top App Header Bar
    HeaderBar:
        # iLovePDF Brand badge
        BoxLayout:
            size_hint: (None, None)
            size: (dp(36), dp(36))
            pos_hint: {'center_y': 0.5}
            canvas.before:
                Color:
                    rgba: (0.898, 0.196, 0.176, 1)
                RoundedRectangle:
                    pos: self.pos
                    size: self.size
                    radius: [dp(8), dp(8), dp(8), dp(8)]
            Label:
                text: "PDF"
                bold: True
                font_size: '12sp'
                color: (1, 1, 1, 1)
                halign: 'center'
                valign: 'middle'

        BoxLayout:
            orientation: 'vertical'
            spacing: dp(2)
            pos_hint: {'center_y': 0.5}
            Label:
                text: "Img2PDF"
                bold: True
                font_size: '18sp'
                color: (0.12, 0.16, 0.22, 1)
                halign: 'left'
                text_size: self.size
            Label:
                text: "Convert images to PDF"
                font_size: '12sp'
                color: (0.45, 0.48, 0.53, 1)
                halign: 'left'
                text_size: self.size

        Widget:

        DangerTextButton:
            text: "Clear All"
            size_hint: (None, None)
            size: (dp(74), dp(36))
            pos_hint: {'center_y': 0.5}
            opacity: 1 if root.has_images else 0
            disabled: not root.has_images
            on_release: root.clear_images()

    # 2. Body Content Container
    BoxLayout:
        orientation: 'vertical'
        padding: [dp(16), dp(16), dp(16), dp(12)]
        spacing: dp(14)

        # Empty Hero State (When no images selected)
        BoxLayout:
            id: hero_container
            orientation: 'vertical'
            size_hint_y: 1 if not root.has_images else None
            height: 0 if root.has_images else self.parent.height
            opacity: 1 if not root.has_images else 0
            disabled: root.has_images

            Widget:

            HeroUploadCard:
                size_hint_y: None
                height: dp(280)
                pos_hint: {'center_x': 0.5}

                # Red Icon Circle
                BoxLayout:
                    size_hint: (None, None)
                    size: (dp(64), dp(64))
                    pos_hint: {'center_x': 0.5}
                    canvas.before:
                        Color:
                            rgba: (1, 0.92, 0.92, 1)
                        Ellipse:
                            pos: self.pos
                            size: self.size
                    Label:
                        text: "📁"
                        font_size: '28sp'
                        halign: 'center'
                        valign: 'middle'

                Label:
                    text: "Select Images to Convert"
                    bold: True
                    font_size: '18sp'
                    color: (0.12, 0.16, 0.22, 1)
                    halign: 'center'
                    size_hint_y: None
                    height: dp(24)

                Label:
                    text: "Pick pictures from gallery to create a clean, high-quality PDF document"
                    font_size: '13sp'
                    color: (0.45, 0.48, 0.53, 1)
                    halign: 'center'
                    valign: 'middle'
                    size_hint_y: None
                    height: dp(36)
                    text_size: (self.width - dp(20), None)

                PrimaryButton:
                    text: "+  SELECT IMAGES"
                    size_hint: (None, None)
                    size: (dp(220), dp(48))
                    pos_hint: {'center_x': 0.5}
                    on_release: root.pick_images()

                Label:
                    text: "Supports JPG • PNG • WEBP • JPEG"
                    font_size: '11sp'
                    color: (0.6, 0.63, 0.67, 1)
                    halign: 'center'
                    size_hint_y: None
                    height: dp(18)

            Widget:

        # Selected Images List State (When images are picked)
        BoxLayout:
            id: list_container
            orientation: 'vertical'
            spacing: dp(10)
            size_hint_y: 1 if root.has_images else None
            height: 0 if not root.has_images else self.parent.height
            opacity: 1 if root.has_images else 0
            disabled: not root.has_images

            # Summary Bar
            BoxLayout:
                size_hint_y: None
                height: dp(36)
                spacing: dp(8)

                Label:
                    text: f"  {len(root.image_paths)} image(s) ready"
                    bold: True
                    font_size: '15sp'
                    color: (0.12, 0.16, 0.22, 1)
                    halign: 'left'
                    text_size: self.size

                Widget:

                OutlineButton:
                    text: "+ Add More"
                    size_hint: (None, None)
                    size: (dp(110), dp(34))
                    on_release: root.pick_images()

            # Scrollable Thumbnails List
            ScrollView:
                id: scroll_view
                do_scroll_x: False
                do_scroll_y: True
                bar_width: dp(4)

                BoxLayout:
                    id: thumbs_list
                    orientation: 'vertical'
                    size_hint_y: None
                    height: self.minimum_height
                    spacing: dp(8)
                    padding: [0, dp(4), 0, dp(4)]

        # Status & Message Banner (Shown on success / error / progress)
        StatusBanner:
            id: status_banner
            opacity: 1 if root.status_msg else 0
            disabled: not root.status_msg
            bg_color: root.status_bg
            border_color: root.status_border

            Label:
                text: root.status_msg
                color: root.status_color
                bold: True
                font_size: '13sp'
                halign: 'center'
                valign: 'middle'
                text_size: (self.width - dp(16), None)

        # 3. Sticky Bottom Convert Button
        PrimaryButton:
            id: convert_btn
            size_hint_y: None
            height: dp(54)
            text: root.convert_button_text
            disabled: not root.has_images or root.is_converting
            on_release: root.convert_to_pdf()
"""


def convert_images_to_pdf(paths, out_path):
    """Robust image-to-PDF conversion with transparency flattening and EXIF correction."""
    if not paths:
        return None
    pages = []
    for p in paths:
        try:
            raw = PILImage.open(p)
            transposed = ImageOps.exif_transpose(raw)
            img = transposed.convert("RGBA")
            bg = PILImage.new("RGB", img.size, "white")
            bg.paste(img, mask=img)
            pages.append(bg)
        except Exception as e:
            print(f"Skipping bad image {p}: {e}")
            continue

    if not pages:
        raise ValueError("Could not load any valid images from selection.")

    pages[0].save(
        out_path,
        "PDF",
        save_all=True,
        append_images=pages[1:],
        resolution=150.0,
        quality=92,
    )
    return out_path


class ThumbCard(BoxLayout):
    """Card item displaying thumbnail, page label, and remove button."""

    def __init__(self, index, path, on_remove_callback, **kwargs):
        super().__init__(**kwargs)
        self.size_hint_y = None
        self.height = dp(76)
        self.padding = [dp(12), dp(6), dp(12), dp(6)]
        self.spacing = dp(12)

        # Background rounded card
        with self.canvas.before:
            from kivy.graphics import Color, Line, RoundedRectangle

            Color(1, 1, 1, 1)
            self.bg_rect = RoundedRectangle(
                pos=self.pos, size=self.size, radius=[dp(12), dp(12), dp(12), dp(12)]
            )
            Color(0.91, 0.92, 0.94, 1)
            self.border_line = Line(
                rounded_rectangle=(self.x, self.y, self.width, self.height, dp(12)),
                width=dp(1),
            )
        self.bind(pos=self._update_canvas, size=self._update_canvas)

        # 1. Thumbnail Image
        thumb = Image(
            source=path,
            size_hint=(None, 1),
            width=dp(64),
            allow_stretch=True,
            keep_ratio=True,
        )
        self.add_widget(thumb)

        # 2. Page & File Name Info
        info_box = BoxLayout(orientation="vertical", spacing=dp(2))
        fname = os.path.basename(path)
        if len(fname) > 28:
            fname = fname[:25] + "..."

        page_lbl = Label(
            text=f"Page {index + 1}",
            bold=True,
            font_size="14sp",
            color=(0.12, 0.16, 0.22, 1),
            halign="left",
            size_hint_y=None,
            height=dp(20),
        )
        page_lbl.bind(size=lambda w, s: setattr(w, "text_size", s))

        name_lbl = Label(
            text=fname,
            font_size="11sp",
            color=(0.50, 0.53, 0.58, 1),
            halign="left",
            size_hint_y=None,
            height=dp(18),
        )
        name_lbl.bind(size=lambda w, s: setattr(w, "text_size", s))

        info_box.add_widget(page_lbl)
        info_box.add_widget(name_lbl)
        self.add_widget(info_box)

        # 3. Remove Button (✕)
        from kivy.uix.button import Button

        del_btn = Button(
            text="✕",
            font_size="16sp",
            bold=True,
            color=(0.7, 0.7, 0.7, 1),
            background_normal="",
            background_color=(0, 0, 0, 0),
            size_hint=(None, None),
            size=(dp(36), dp(36)),
            pos_hint={"center_y": 0.5},
        )
        del_btn.bind(on_release=lambda _: on_remove_callback(path))
        self.add_widget(del_btn)

    def _update_canvas(self, *args):
        self.bg_rect.pos = self.pos
        self.bg_rect.size = self.size
        self.border_line.rounded_rectangle = (
            self.x,
            self.y,
            self.width,
            self.height,
            dp(12),
        )


class MainScreen(BoxLayout):
    image_paths = ListProperty([])
    has_images = BooleanProperty(False)
    is_converting = BooleanProperty(False)
    convert_button_text = StringProperty("CONVERT TO PDF")

    status_msg = StringProperty("")
    status_color = ListProperty([0.15, 0.55, 0.25, 1])
    status_bg = ListProperty([0.94, 0.98, 0.95, 1])
    status_border = ListProperty([0.3, 0.75, 0.45, 1])

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.chooser = None
        Clock.schedule_once(self._request_android_permissions, 0.5)

    def _request_android_permissions(self, *args):
        if platform == "android":
            try:
                from android.permissions import Permission, request_permissions

                request_permissions(
                    [
                        Permission.READ_EXTERNAL_STORAGE,
                        Permission.WRITE_EXTERNAL_STORAGE,
                        Permission.READ_MEDIA_IMAGES,
                    ]
                )
            except Exception as e:
                print(f"Android permission request error: {e}")

    def pick_images(self, *_):
        """Open gallery picker via androidstorage4kivy or fallback on desktop."""
        self.status_msg = ""
        if platform == "android":
            from androidstorage4kivy import Chooser

            self.chooser = Chooser(self.on_picked)
            self.chooser.choose_content("image/*", multiple=True)
        else:
            # Desktop fallback for development testing
            try:
                import tkinter as tk
                from tkinter import filedialog

                root = tk.Tk()
                root.withdraw()
                files = filedialog.askopenfilenames(
                    title="Select Images to Convert",
                    filetypes=[
                        (
                            "Image files",
                            "*.jpg;*.jpeg;*.png;*.webp;*.bmp;*.JPG;*.JPEG;*.PNG",
                        )
                    ],
                )
                if files:
                    self.on_picked(list(files))
            except Exception:
                self.show_info("Image picker runs natively on Android devices.")

    def on_picked(self, uris):
        """Callback when images are selected."""
        new_paths = []
        if platform == "android":
            from androidstorage4kivy import SharedStorage

            ss = SharedStorage()
            for u in uris or []:
                p = ss.copy_from_shared(u)
                if p:
                    new_paths.append(p)
        else:
            new_paths = uris or []

        # Avoid duplicates while preserving user order
        for p in new_paths:
            if p not in self.image_paths:
                self.image_paths.append(p)

        self._refresh_gallery()

    def remove_image(self, path):
        """Remove a single image from the list."""
        if path in self.image_paths:
            self.image_paths.remove(path)
            self._refresh_gallery()

    def clear_images(self, *_):
        """Clear all selected images."""
        self.image_paths = []
        self._refresh_gallery()
        self.status_msg = ""

    def _refresh_gallery(self):
        """Sync thumbnail list widgets with current image_paths."""
        self.has_images = bool(self.image_paths)
        thumbs_box = self.ids.thumbs_list
        thumbs_box.clear_widgets()

        for idx, path in enumerate(self.image_paths):
            card = ThumbCard(
                index=idx, path=path, on_remove_callback=self.remove_image
            )
            thumbs_box.add_widget(card)

        if self.has_images:
            self.convert_button_text = f"CONVERT {len(self.image_paths)} IMAGE{'S' if len(self.image_paths) > 1 else ''} TO PDF"
        else:
            self.convert_button_text = "CONVERT TO PDF"

    def convert_to_pdf(self, *_):
        """Trigger background conversion to keep the UI smooth."""
        if not self.image_paths:
            return

        self.is_converting = True
        self.convert_button_text = "CONVERTING... PLEASE WAIT"
        self.show_info("Converting images into high-quality PDF...")

        threading.Thread(target=self._run_conversion, daemon=True).start()

    def _run_conversion(self):
        """Worker thread for PIL PDF creation and Android SharedStorage export."""
        try:
            app = App.get_running_app()
            timestamp = int(time.time())
            out_filename = f"Img2PDF_{timestamp}.pdf"
            local_out = os.path.join(app.user_data_dir, out_filename)

            # 1. Convert via PIL
            convert_images_to_pdf(self.image_paths, local_out)

            # 2. Export to shared storage on Android
            if platform == "android":
                from androidstorage4kivy import SharedStorage

                SharedStorage().copy_to_shared(local_out)
                result_msg = (
                    f"✓ PDF Saved successfully! ({len(self.image_paths)} pages)\n"
                    "Found in Files > Documents / Downloads"
                )
            else:
                result_msg = f"✓ PDF Saved: {local_out}"

            Clock.schedule_once(
                lambda dt: self._on_conversion_success(result_msg), 0
            )
        except Exception as e:
            Clock.schedule_once(lambda dt: self._on_conversion_error(str(e)), 0)

    def _on_conversion_success(self, msg):
        self.is_converting = False
        self._refresh_gallery()
        self.show_success(msg)

    def _on_conversion_error(self, err_msg):
        self.is_converting = False
        self._refresh_gallery()
        self.show_error(f"Error creating PDF: {err_msg}")

    def show_success(self, text):
        self.status_msg = text
        self.status_color = [0.10, 0.52, 0.22, 1]
        self.status_bg = [0.92, 0.98, 0.94, 1]
        self.status_border = [0.35, 0.78, 0.45, 1]

    def show_error(self, text):
        self.status_msg = text
        self.status_color = [0.85, 0.18, 0.15, 1]
        self.status_bg = [1.0, 0.93, 0.93, 1]
        self.status_border = [0.92, 0.45, 0.45, 1]

    def show_info(self, text):
        self.status_msg = text
        self.status_color = [0.20, 0.35, 0.65, 1]
        self.status_bg = [0.93, 0.95, 1.0, 1]
        self.status_border = [0.45, 0.60, 0.90, 1]


class Img2PdfApp(App):
    def build(self):
        Builder.load_string(KV_DESIGN)
        return MainScreen()


if __name__ == "__main__":
    Img2PdfApp().run()
