import json
import os
import re
import threading
import time
from kivy.app import App
from kivy.clock import Clock
from kivy.core.window import Window
from kivy.lang import Builder
from kivy.metrics import dp, sp
from kivy.properties import BooleanProperty, ListProperty, NumericProperty, StringProperty
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.button import Button
from kivy.uix.image import Image
from kivy.uix.label import Label
from kivy.uix.modalview import ModalView
from kivy.uix.scrollview import ScrollView
from kivy.uix.textinput import TextInput
from kivy.uix.widget import Widget
from kivy.utils import platform
from PIL import Image as PILImage, ImageOps

# iLovePDF Modern Light Theme Background
Window.clearcolor = (0.972, 0.976, 0.984, 1)

def merge_pdfs(pdf_paths, output_path):
    """
    Merge two or more PDF files into a single unified PDF document.
    Supports pypdf or PyPDF2.
    """
    if len(pdf_paths) < 2:
        raise ValueError("At least two PDF files are required to perform a merge.")
    try:
        from pypdf import PdfMerger
        merger = PdfMerger()
        for path in pdf_paths:
            merger.append(path)
        merger.write(output_path)
        merger.close()
        return output_path
    except ImportError:
        try:
            from PyPDF2 import PdfMerger
            merger = PdfMerger()
            for path in pdf_paths:
                merger.append(path)
            merger.write(output_path)
            merger.close()
            return output_path
        except ImportError:
            raise ImportError("Please install 'pypdf' (pip install pypdf) to merge PDF files.")

HISTORY_FILE = "pdf_history.json"

KV_DESIGN = """
#:import dp kivy.metrics.dp
#:import sp kivy.metrics.sp

<PrimaryButton@Button>:
    background_normal: ''
    background_down: ''
    background_color: (0, 0, 0, 0)
    font_size: '15sp'
    bold: True
    color: (1, 1, 1, 1) if not self.disabled else (0.6, 0.6, 0.6, 1)
    canvas.before:
        Color:
            rgba: (0.75, 0.12, 0.10, 1) if self.state == 'down' else ((0.898, 0.196, 0.176, 1) if not self.disabled else (0.86, 0.86, 0.88, 1))
        RoundedRectangle:
            pos: self.pos
            size: self.size
            radius: [dp(12), dp(12), dp(12), dp(12)]

<OutlineButton@Button>:
    background_normal: ''
    background_down: ''
    background_color: (0, 0, 0, 0)
    font_size: '13sp'
    bold: True
    color: (0.898, 0.196, 0.176, 1) if not self.disabled else (0.6, 0.6, 0.6, 1)
    canvas.before:
        Color:
            rgba: (1, 0.92, 0.92, 1) if self.state == 'down' else (1, 1, 1, 1)
        RoundedRectangle:
            pos: self.pos
            size: self.size
            radius: [dp(10), dp(10), dp(10), dp(10)]
        Color:
            rgba: (0.898, 0.196, 0.176, 1) if not self.disabled else (0.80, 0.80, 0.82, 1)
        Line:
            rounded_rectangle: (self.x, self.y, self.width, self.height, dp(10))
            width: dp(1.3)

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
    padding: [dp(20), dp(24), dp(20), dp(24)]
    spacing: dp(14)
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

<AlertModal>:
    size_hint: (0.88, None)
    height: dp(230)
    auto_dismiss: False
    background_color: (0, 0, 0, 0.5)
    BoxLayout:
        orientation: 'vertical'
        padding: dp(20)
        spacing: dp(12)
        canvas.before:
            Color:
                rgba: (1, 1, 1, 1)
            RoundedRectangle:
                pos: self.pos
                size: self.size
                radius: [dp(18), dp(18), dp(18), dp(18)]

        Label:
            text: "⚠️ " + root.title_text
            bold: True
            font_size: '17sp'
            color: (0.85, 0.18, 0.15, 1)
            size_hint_y: None
            height: dp(24)
            halign: 'center'

        Label:
            text: root.message_text
            font_size: '13sp'
            color: (0.25, 0.28, 0.33, 1)
            halign: 'center'
            valign: 'middle'
            text_size: (self.width - dp(20), None)

        PrimaryButton:
            text: "OK"
            size_hint_y: None
            height: dp(42)
            on_release: root.dismiss()

<RenameModal>:
    size_hint: (0.92, None)
    height: dp(260)
    auto_dismiss: False
    background_color: (0, 0, 0, 0.5)
    BoxLayout:
        orientation: 'vertical'
        padding: dp(20)
        spacing: dp(12)
        canvas.before:
            Color:
                rgba: (1, 1, 1, 1)
            RoundedRectangle:
                pos: self.pos
                size: self.size
                radius: [dp(18), dp(18), dp(18), dp(18)]

        Label:
            text: "Name Your PDF"
            bold: True
            font_size: '18sp'
            color: (0.12, 0.16, 0.22, 1)
            size_hint_y: None
            height: dp(24)
            halign: 'left'
            text_size: self.size

        Label:
            text: "Choose a file name before converting your images:"
            font_size: '12sp'
            color: (0.50, 0.53, 0.58, 1)
            size_hint_y: None
            height: dp(18)
            halign: 'left'
            text_size: self.size

        BoxLayout:
            size_hint_y: None
            height: dp(48)
            padding: [dp(12), dp(4), dp(12), dp(4)]
            canvas.before:
                Color:
                    rgba: (0.96, 0.97, 0.98, 1)
                RoundedRectangle:
                    pos: self.pos
                    size: self.size
                    radius: [dp(10), dp(10), dp(10), dp(10)]
                Color:
                    rgba: (0.85, 0.86, 0.89, 1)
                Line:
                    rounded_rectangle: (self.x, self.y, self.width, self.height, dp(10))
                    width: dp(1.2)

            TextInput:
                id: name_input
                text: root.default_name
                multiline: False
                font_size: '15sp'
                background_color: (0, 0, 0, 0)
                cursor_color: (0.898, 0.196, 0.176, 1)
                foreground_color: (0.12, 0.16, 0.22, 1)
                padding: [0, dp(10), 0, dp(10)]

            Label:
                text: ".pdf"
                bold: True
                font_size: '14sp'
                color: (0.898, 0.196, 0.176, 1)
                size_hint_x: None
                width: dp(36)
                halign: 'right'

        Widget:

        BoxLayout:
            size_hint_y: None
            height: dp(44)
            spacing: dp(10)

            OutlineButton:
                text: "Cancel"
                on_release: root.dismiss()

            PrimaryButton:
                text: "Convert Now"
                on_release: root.on_confirm()

<ExportModal>:
    size_hint: (0.92, None)
    height: dp(390)
    auto_dismiss: False
    background_color: (0, 0, 0, 0.5)
    BoxLayout:
        orientation: 'vertical'
        padding: dp(20)
        spacing: dp(10)
        canvas.before:
            Color:
                rgba: (1, 1, 1, 1)
            RoundedRectangle:
                pos: self.pos
                size: self.size
                radius: [dp(20), dp(20), dp(20), dp(20)]

        BoxLayout:
            size_hint: (None, None)
            size: (dp(48), dp(48))
            pos_hint: {'center_x': 0.5}
            canvas.before:
                Color:
                    rgba: (0.88, 0.97, 0.90, 1)
                Ellipse:
                    pos: self.pos
                    size: self.size
            Label:
                text: "✓"
                bold: True
                font_size: '26sp'
                color: (0.15, 0.65, 0.30, 1)
                halign: 'center'
                valign: 'middle'

        Label:
            text: "PDF Created Successfully!"
            bold: True
            font_size: '17sp'
            color: (0.12, 0.16, 0.22, 1)
            halign: 'center'
            size_hint_y: None
            height: dp(22)

        Label:
            text: root.doc_name
            bold: True
            font_size: '13sp'
            color: (0.898, 0.196, 0.176, 1)
            halign: 'center'
            size_hint_y: None
            height: dp(18)

        Label:
            text: root.doc_info
            font_size: '12sp'
            color: (0.50, 0.53, 0.58, 1)
            halign: 'center'
            size_hint_y: None
            height: dp(16)

        PrimaryButton:
            text: "📤  Share (WhatsApp, Apps...)"
            size_hint_y: None
            height: dp(46)
            on_release: root.on_share()

        OutlineButton:
            id: save_btn
            text: root.save_btn_text
            size_hint_y: None
            height: dp(44)
            on_release: root.on_save()

        OutlineButton:
            text: "👁️  Open / View PDF"
            size_hint_y: None
            height: dp(44)
            on_release: root.on_view()

        Button:
            text: "Done"
            background_normal: ''
            background_color: (0, 0, 0, 0)
            font_size: '14sp'
            color: (0.50, 0.53, 0.58, 1)
            size_hint_y: None
            height: dp(32)
            on_release: root.dismiss()

<MainScreen>:
    orientation: 'vertical'
    spacing: 0

    # 1. Header Bar with Tabs
    HeaderBar:
        BoxLayout:
            size_hint: (None, None)
            size: (dp(34), dp(34))
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
                font_size: '11sp'
                color: (1, 1, 1, 1)

        Label:
            text: "PDFDost"
            bold: True
            font_size: '18sp'
            color: (0.12, 0.16, 0.22, 1)
            size_hint_x: None
            width: dp(85)
            halign: 'left'
            text_size: self.size

        Widget:

        # Navigation Tabs
        BoxLayout:
            size_hint: (None, None)
            size: (dp(180), dp(34))
            pos_hint: {'center_y': 0.5}
            padding: dp(2)
            canvas.before:
                Color:
                    rgba: (0.92, 0.93, 0.95, 1)
                RoundedRectangle:
                    pos: self.pos
                    size: self.size
                    radius: [dp(17), dp(17), dp(17), dp(17)]

            Button:
                text: "Convert"
                font_size: '12sp'
                bold: True
                color: (1, 1, 1, 1) if root.active_tab == 'convert' else (0.45, 0.48, 0.53, 1)
                background_normal: ''
                background_color: (0, 0, 0, 0)
                canvas.before:
                    Color:
                        rgba: (0.898, 0.196, 0.176, 1) if root.active_tab == 'convert' else (0, 0, 0, 0)
                    RoundedRectangle:
                        pos: self.pos
                        size: self.size
                        radius: [dp(15), dp(15), dp(15), dp(15)]
                on_release: root.switch_tab('convert')

            Button:
                text: f"History ({len(root.history_list)})"
                font_size: '12sp'
                bold: True
                color: (1, 1, 1, 1) if root.active_tab == 'history' else (0.45, 0.48, 0.53, 1)
                background_normal: ''
                background_color: (0, 0, 0, 0)
                canvas.before:
                    Color:
                        rgba: (0.898, 0.196, 0.176, 1) if root.active_tab == 'history' else (0, 0, 0, 0)
                    RoundedRectangle:
                        pos: self.pos
                        size: self.size
                        radius: [dp(15), dp(15), dp(15), dp(15)]
                on_release: root.switch_tab('history')

    # 2. Main Content Stack
    BoxLayout:
        orientation: 'vertical'
        padding: [dp(16), dp(14), dp(16), dp(14)]
        spacing: dp(12)

        # TAB A: CONVERT VIEW
        BoxLayout:
            id: convert_view
            orientation: 'vertical'
            spacing: dp(12)
            size_hint_y: 1 if root.active_tab == 'convert' else None
            height: 0 if root.active_tab != 'convert' else self.parent.height
            opacity: 1 if root.active_tab == 'convert' else 0
            disabled: root.active_tab != 'convert'

            # Empty Hero State
            BoxLayout:
                orientation: 'vertical'
                size_hint_y: 1 if not root.has_images else None
                height: 0 if root.has_images else self.parent.height
                opacity: 1 if not root.has_images else 0
                disabled: root.has_images

                Widget:

                HeroUploadCard:
                    size_hint_y: None
                    height: dp(270)
                    pos_hint: {'center_x': 0.5}

                    BoxLayout:
                        size_hint: (None, None)
                        size: (dp(60), dp(60))
                        pos_hint: {'center_x': 0.5}
                        canvas.before:
                            Color:
                                rgba: (1, 0.92, 0.92, 1)
                            Ellipse:
                                pos: self.pos
                                size: self.size
                        Label:
                            text: "📁"
                            font_size: '26sp'

                    Label:
                        text: "Select Images to Convert"
                        bold: True
                        font_size: '18sp'
                        color: (0.12, 0.16, 0.22, 1)
                        halign: 'center'
                        size_hint_y: None
                        height: dp(24)

                    Label:
                        text: "Choose multiple pictures from your gallery\\nto create an optimized PDF"
                        font_size: '13sp'
                        color: (0.45, 0.48, 0.53, 1)
                        halign: 'center'
                        size_hint_y: None
                        height: dp(36)
                        text_size: (self.width - dp(20), None)

                    PrimaryButton:
                        text: "+  SELECT IMAGES"
                        size_hint: (None, None)
                        size: (dp(210), dp(46))
                        pos_hint: {'center_x': 0.5}
                        on_release: root.pick_images()

                    Label:
                        text: "Supports JPG • PNG • WEBP • JPEG"
                        font_size: '11sp'
                        color: (0.6, 0.63, 0.67, 1)
                        halign: 'center'
                        size_hint_y: None
                        height: dp(16)

                Widget:

            # Selected Thumbnails View
            BoxLayout:
                orientation: 'vertical'
                spacing: dp(10)
                size_hint_y: 1 if root.has_images else None
                height: 0 if not root.has_images else self.parent.height
                opacity: 1 if root.has_images else 0
                disabled: not root.has_images

                # Top Bar with count and Add More
                BoxLayout:
                    size_hint_y: None
                    height: dp(34)
                    spacing: dp(8)

                    Label:
                        text: f"{len(root.image_paths)} image(s) selected"
                        bold: True
                        font_size: '15sp'
                        color: (0.12, 0.16, 0.22, 1)
                        halign: 'left'
                        text_size: self.size

                    Widget:

                    OutlineButton:
                        text: "+ Add More"
                        size_hint: (None, None)
                        size: (dp(105), dp(32))
                        on_release: root.pick_images()

                    Button:
                        text: "Clear All"
                        background_normal: ''
                        background_color: (0, 0, 0, 0)
                        font_size: '13sp'
                        bold: True
                        color: (0.85, 0.2, 0.2, 1)
                        size_hint: (None, None)
                        size: (dp(70), dp(32))
                        on_release: root.clear_images()

                # Scrollable Visual Image List
                ScrollView:
                    do_scroll_x: False
                    do_scroll_y: True
                    bar_width: dp(4)

                    BoxLayout:
                        id: thumbs_list
                        orientation: 'vertical'
                        size_hint_y: None
                        height: self.minimum_height
                        spacing: dp(10)
                        padding: [0, dp(4), 0, dp(4)]

                # Bottom Action Convert Button
                PrimaryButton:
                    id: convert_btn
                    size_hint_y: None
                    height: dp(52)
                    text: root.convert_button_text
                    disabled: not root.has_images or root.is_converting
                    on_release: root.open_rename_modal()

        # TAB B: HISTORY VIEW
        BoxLayout:
            id: history_view
            orientation: 'vertical'
            spacing: dp(10)
            size_hint_y: 1 if root.active_tab == 'history' else None
            height: 0 if root.active_tab != 'history' else self.parent.height
            opacity: 1 if root.active_tab == 'history' else 0
            disabled: root.active_tab != 'history'

            # Empty History State
            BoxLayout:
                orientation: 'vertical'
                size_hint_y: 1 if not root.history_list else None
                height: 0 if bool(root.history_list) else self.parent.height
                opacity: 1 if not root.history_list else 0
                disabled: bool(root.history_list)

                Widget:

                BoxLayout:
                    orientation: 'vertical'
                    size_hint_y: None
                    height: dp(220)
                    spacing: dp(12)
                    padding: dp(20)
                    canvas.before:
                        Color:
                            rgba: (1, 1, 1, 1)
                        RoundedRectangle:
                            pos: self.pos
                            size: self.size
                            radius: [dp(18), dp(18), dp(18), dp(18)]

                    Label:
                        text: "🕒"
                        font_size: '32sp'
                        halign: 'center'

                    Label:
                        text: "No Converted PDFs Yet"
                        bold: True
                        font_size: '17sp'
                        color: (0.12, 0.16, 0.22, 1)
                        halign: 'center'

                    Label:
                        text: "Your generated PDF files will appear here so you can view, share, or save them anytime."
                        font_size: '12sp'
                        color: (0.50, 0.53, 0.58, 1)
                        halign: 'center'
                        text_size: (self.width - dp(20), None)

                    PrimaryButton:
                        text: "Convert Images Now"
                        size_hint: (None, None)
                        size: (dp(190), dp(40))
                        pos_hint: {'center_x': 0.5}
                        on_release: root.switch_tab('convert')

                Widget:

            # History Items List
            BoxLayout:
                orientation: 'vertical'
                spacing: dp(8)
                size_hint_y: 1 if bool(root.history_list) else None
                height: 0 if not bool(root.history_list) else self.parent.height
                opacity: 1 if bool(root.history_list) else 0
                disabled: not bool(root.history_list)

                BoxLayout:
                    size_hint_y: None
                    height: dp(28)
                    Label:
                        text: f"Stored Files ({len(root.history_list)})"
                        bold: True
                        font_size: '14sp'
                        color: (0.12, 0.16, 0.22, 1)
                        halign: 'left'
                        text_size: self.size

                    Widget:

                    Button:
                        text: "Clear All"
                        background_normal: ''
                        background_color: (0, 0, 0, 0)
                        font_size: '12sp'
                        bold: True
                        color: (0.85, 0.2, 0.2, 1)
                        size_hint_x: None
                        width: dp(65)
                        on_release: root.clear_history()

                ScrollView:
                    do_scroll_x: False
                    do_scroll_y: True
                    bar_width: dp(4)

                    BoxLayout:
                        id: history_scroll_list
                        orientation: 'vertical'
                        size_hint_y: None
                        height: self.minimum_height
                        spacing: dp(10)
                        padding: [0, dp(2), 0, dp(10)]
"""


def convert_images_to_pdf(paths, out_path):
    """Compile selected images into an optimized PDF."""
    if not paths:
        raise ValueError("No images provided.")

    pages = []
    max_dimension = 2400

    for p in paths:
        if not os.path.exists(p):
            print(f"File not found: {p}")
            continue

        try:
            with PILImage.open(p) as raw:
                transposed = ImageOps.exif_transpose(raw)

                # Downsample overly massive camera photos to avoid memory exhaustion
                if max(transposed.size) > max_dimension:
                    transposed.thumbnail(
                        (max_dimension, max_dimension),
                        PILImage.Resampling.LANCZOS,
                    )

                # Flatten transparency onto white background
                if transposed.mode in ("RGBA", "LA", "P"):
                    rgba = transposed.convert("RGBA")
                    bg = PILImage.new("RGB", rgba.size, (255, 255, 255))
                    alpha_mask = rgba.split()[-1]
                    bg.paste(rgba, mask=alpha_mask)
                    pages.append(bg)
                else:
                    pages.append(transposed.convert("RGB"))
        except Exception as e:
            print(f"Skipping bad image {p}: {e}")
            continue

    if not pages:
        raise ValueError("Could not read any valid images from selection.")

    # Save all pages to PDF
    pages[0].save(
        out_path,
        "PDF",
        save_all=True,
        append_images=pages[1:],
        resolution=150.0,
    )
    return out_path


def format_bytes(size_bytes):
    """Human-readable file size string."""
    if size_bytes < 1024:
        return f"{size_bytes} B"
    elif size_bytes < 1024 * 1024:
        return f"{size_bytes / 1024:.1f} KB"
    else:
        return f"{size_bytes / (1024 * 1024):.1f} MB"


class AlertModal(ModalView):
    """Alert dialog for warnings and error feedback."""

    title_text = StringProperty("Notice")
    message_text = StringProperty("")

    def __init__(self, title, message, **kwargs):
        self.title_text = title
        self.message_text = message
        super().__init__(**kwargs)


class RenameModal(ModalView):
    """Popup modal requesting custom filename before conversion."""

    default_name = StringProperty("Document")

    def __init__(self, default_name, on_confirm_callback, **kwargs):
        super().__init__(**kwargs)
        self.default_name = default_name
        self.on_confirm_callback = on_confirm_callback
        if hasattr(self, "ids") and "name_input" in self.ids:
            self.ids.name_input.text = default_name

    def on_confirm(self):
        entered = self.ids.name_input.text.strip()
        if not entered:
            entered = self.default_name
        if entered.lower().endswith(".pdf"):
            entered = entered[:-4]
        # Sanitize filename
        clean_name = re.sub(r'[\\/*?:"<>|]', "_", entered).strip()
        if not clean_name:
            clean_name = self.default_name
        self.dismiss()
        self.on_confirm_callback(clean_name)


class ExportModal(ModalView):
    """Modal displaying options: Share, Save to Device, View."""

    doc_name = StringProperty("")
    doc_info = StringProperty("")
    save_btn_text = StringProperty("💾  Save to Device (Downloads)")

    def __init__(
        self,
        local_path,
        doc_name,
        doc_info,
        on_share_cb,
        on_save_cb,
        on_view_cb,
        **kwargs,
    ):
        super().__init__(**kwargs)
        self.local_path = local_path
        self.doc_name = doc_name
        self.doc_info = doc_info
        self.on_share_cb = on_share_cb
        self.on_save_cb = on_save_cb
        self.on_view_cb = on_view_cb

    def on_share(self):
        self.on_share_cb(self.local_path)

    def on_save(self):
        success = self.on_save_cb(self.local_path)
        if success:
            self.save_btn_text = "✓  Saved to Downloads!"

    def on_view(self):
        self.on_view_cb(self.local_path)


class VisualThumbCard(BoxLayout):
    """A card showing the image thumbnail, size, page number, and remove button."""

    def __init__(self, index, path, on_remove_callback, **kwargs):
        super().__init__(**kwargs)
        self.size_hint_y = None
        self.height = dp(88)
        self.padding = [dp(10), dp(8), dp(12), dp(8)]
        self.spacing = dp(12)

        # Rounded card canvas
        with self.canvas.before:
            from kivy.graphics import Color, Line, RoundedRectangle

            Color(1, 1, 1, 1)
            self.bg_rect = RoundedRectangle(
                pos=self.pos, size=self.size, radius=[dp(14), dp(14), dp(14), dp(14)]
            )
            Color(0.90, 0.91, 0.93, 1)
            self.border_line = Line(
                rounded_rectangle=(self.x, self.y, self.width, self.height, dp(14)),
                width=dp(1.2),
            )
        self.bind(pos=self._update_canvas, size=self._update_canvas)

        # 1. Image Thumbnail Preview
        thumb = Image(
            source=path,
            size_hint=(None, 1),
            width=dp(72),
            allow_stretch=True,
            keep_ratio=True,
            nocache=True,
        )
        self.add_widget(thumb)

        # 2. Page Number & File Details
        info = BoxLayout(orientation="vertical", spacing=dp(2))
        fname = os.path.basename(path)
        if len(fname) > 26:
            fname = fname[:23] + "..."

        try:
            fsize = format_bytes(os.path.getsize(path))
        except Exception:
            fsize = ""

        page_lbl = Label(
            text=f"Page {index + 1}",
            bold=True,
            font_size="14sp",
            color=(0.898, 0.196, 0.176, 1),
            halign="left",
            size_hint_y=None,
            height=dp(20),
        )
        page_lbl.bind(size=lambda w, s: setattr(w, "text_size", s))

        name_lbl = Label(
            text=fname,
            font_size="12sp",
            color=(0.15, 0.20, 0.25, 1),
            halign="left",
            size_hint_y=None,
            height=dp(18),
        )
        name_lbl.bind(size=lambda w, s: setattr(w, "text_size", s))

        size_lbl = Label(
            text=fsize,
            font_size="11sp",
            color=(0.55, 0.58, 0.63, 1),
            halign="left",
            size_hint_y=None,
            height=dp(16),
        )
        size_lbl.bind(size=lambda w, s: setattr(w, "text_size", s))

        info.add_widget(page_lbl)
        info.add_widget(name_lbl)
        if fsize:
            info.add_widget(size_lbl)
        self.add_widget(info)

        # 3. Individual Delete Button (✕)
        del_btn = Button(
            text="✕",
            font_size="15sp",
            bold=True,
            color=(0.65, 0.68, 0.72, 1),
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
            dp(14),
        )


class HistoryCard(BoxLayout):
    """Card item in the local History tab."""

    def __init__(
        self,
        item,
        on_share_cb,
        on_save_cb,
        on_view_cb,
        on_delete_cb,
        **kwargs,
    ):
        super().__init__(**kwargs)
        self.item = item
        self.size_hint_y = None
        self.height = dp(110)
        self.padding = [dp(14), dp(10), dp(14), dp(10)]
        self.spacing = dp(8)
        self.orientation = "vertical"

        with self.canvas.before:
            from kivy.graphics import Color, Line, RoundedRectangle

            Color(1, 1, 1, 1)
            self.bg_rect = RoundedRectangle(
                pos=self.pos, size=self.size, radius=[dp(14), dp(14), dp(14), dp(14)]
            )
            Color(0.90, 0.91, 0.93, 1)
            self.border_line = Line(
                rounded_rectangle=(self.x, self.y, self.width, self.height, dp(14)),
                width=dp(1.2),
            )
        self.bind(pos=self._update_canvas, size=self._update_canvas)

        # Top row: Icon + Name + Date + Delete
        top_row = BoxLayout(size_hint_y=None, height=dp(38), spacing=dp(8))

        icon_lbl = Label(
            text="📄",
            font_size="20sp",
            size_hint_x=None,
            width=dp(28),
        )
        top_row.add_widget(icon_lbl)

        meta_box = BoxLayout(orientation="vertical", spacing=dp(1))
        title_lbl = Label(
            text=item.get("name", "Document.pdf"),
            bold=True,
            font_size="13sp",
            color=(0.12, 0.16, 0.22, 1),
            halign="left",
        )
        title_lbl.bind(size=lambda w, s: setattr(w, "text_size", s))

        date_lbl = Label(
            text=f"{item.get('date', '')}  •  {item.get('pages', 1)} pages  •  {item.get('size', '')}",
            font_size="11sp",
            color=(0.50, 0.53, 0.58, 1),
            halign="left",
        )
        date_lbl.bind(size=lambda w, s: setattr(w, "text_size", s))

        meta_box.add_widget(title_lbl)
        meta_box.add_widget(date_lbl)
        top_row.add_widget(meta_box)

        del_btn = Button(
            text="🗑️",
            font_size="14sp",
            background_normal="",
            background_color=(0, 0, 0, 0),
            size_hint=(None, None),
            size=(dp(32), dp(32)),
        )
        del_btn.bind(on_release=lambda _: on_delete_cb(item))
        top_row.add_widget(del_btn)
        self.add_widget(top_row)

        # Bottom row: Quick action buttons
        actions_row = BoxLayout(size_hint_y=None, height=dp(32), spacing=dp(8))

        share_btn = Button(
            text="📤 Share",
            font_size="12sp",
            bold=True,
            color=(0.898, 0.196, 0.176, 1),
            background_normal="",
            background_color=(1, 0.94, 0.94, 1),
        )
        share_btn.bind(on_release=lambda _: on_share_cb(item["path"]))
        actions_row.add_widget(share_btn)

        save_btn = Button(
            text="💾 Save to Device",
            font_size="12sp",
            bold=True,
            color=(0.2, 0.3, 0.4, 1),
            background_normal="",
            background_color=(0.94, 0.95, 0.97, 1),
        )
        save_btn.bind(on_release=lambda btn: self._handle_save(btn, on_save_cb))
        actions_row.add_widget(save_btn)

        view_btn = Button(
            text="👁️ Open",
            font_size="12sp",
            bold=True,
            color=(0.2, 0.3, 0.4, 1),
            background_normal="",
            background_color=(0.94, 0.95, 0.97, 1),
        )
        view_btn.bind(on_release=lambda _: on_view_cb(item["path"]))
        actions_row.add_widget(view_btn)

        self.add_widget(actions_row)

    def _handle_save(self, btn, cb):
        if cb(self.item["path"]):
            btn.text = "✓ Saved"

    def _update_canvas(self, *args):
        self.bg_rect.pos = self.pos
        self.bg_rect.size = self.size
        self.border_line.rounded_rectangle = (
            self.x,
            self.y,
            self.width,
            self.height,
            dp(14),
        )


class MainScreen(BoxLayout):
    image_paths = ListProperty([])
    has_images = BooleanProperty(False)
    is_converting = BooleanProperty(False)
    active_tab = StringProperty("convert")
    convert_button_text = StringProperty("CONVERT TO PDF")
    history_list = ListProperty([])

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.chooser = None
        self.user_dir = None
        Clock.schedule_once(self._init_app, 0.3)

    def _init_app(self, *args):
        try:
            app = App.get_running_app()
            self.user_dir = app.user_data_dir
            os.makedirs(self.user_dir, exist_ok=True)
        except Exception as e:
            print(f"Error initializing user dir: {e}")
            self.user_dir = "."
        self._request_permissions()
        self._load_history_from_disk()

    def _request_permissions(self):
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
                print(f"Permission error: {e}")

    def switch_tab(self, tab_name):
        self.active_tab = tab_name
        if tab_name == "history":
            self._render_history_tab()

    def pick_images(self, *_):
        """Pick multiple images from Android gallery or desktop dialog."""
        if platform == "android":
            try:
                from androidstorage4kivy import Chooser

                self.chooser = Chooser(self.on_picked)
                self.chooser.multiple = True
                self.chooser.choose_content("image/*")
            except Exception as e:
                self.show_alert("Picker Error", f"Unable to open gallery: {e}")
        else:
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
            except Exception as e:
                self.show_alert("Desktop Picker", f"File dialog error: {e}")

    def on_picked(self, uris):
        """Callback from Chooser (scheduled to run safely on Kivy main thread)."""
        Clock.schedule_once(lambda dt: self._handle_picked_uris(uris), 0)

    def _handle_picked_uris(self, uris):
        """Process URIs and populate image_paths safely on the main thread."""
        new_paths = []
        if platform == "android":
            try:
                from androidstorage4kivy import SharedStorage

                ss = SharedStorage()
                for u in uris or []:
                    try:
                        p = ss.copy_from_shared(u)
                        if p and os.path.exists(p):
                            new_paths.append(p)
                    except Exception as e:
                        print(f"Error copying {u}: {e}")
            except Exception as e:
                print(f"SharedStorage error: {e}")
        else:
            new_paths = [u for u in (uris or []) if os.path.exists(u)]

        current = list(self.image_paths)
        for p in new_paths:
            if p not in current:
                current.append(p)

        self.image_paths = current
        self._refresh_gallery()

    def remove_image(self, path):
        """Remove a single image."""
        current = list(self.image_paths)
        if path in current:
            current.remove(path)
            self.image_paths = current
            self._refresh_gallery()

    def clear_images(self, *_):
        """Clear all selected images."""
        self.image_paths = []
        self._refresh_gallery()

    def _refresh_gallery(self):
        """Update the visual thumbnail list and button state."""
        self.has_images = bool(self.image_paths)
        thumbs_box = self.ids.thumbs_list
        thumbs_box.clear_widgets()

        for idx, path in enumerate(self.image_paths):
            card = VisualThumbCard(
                index=idx, path=path, on_remove_callback=self.remove_image
            )
            thumbs_box.add_widget(card)

        if self.has_images:
            count = len(self.image_paths)
            self.convert_button_text = f"CONVERT {count} IMAGE{'S' if count > 1 else ''} TO PDF"
        else:
            self.convert_button_text = "CONVERT TO PDF"

    def open_rename_modal(self, *_):
        """Open the Rename Modal before converting."""
        if not self.image_paths:
            return
        default_name = f"Document_{time.strftime('%Y%m%d_%H%M')}"
        modal = RenameModal(
            default_name=default_name,
            on_confirm_callback=self.start_conversion,
        )
        modal.open()

    def start_conversion(self, custom_name):
        """Initiate background thread to build PDF."""
        self.is_converting = True
        self.convert_button_text = "CONVERTING... PLEASE WAIT"

        # Pass a snapshot of image_paths to avoid thread mutation
        paths_snapshot = list(self.image_paths)
        threading.Thread(
            target=self._conversion_worker,
            args=(custom_name, paths_snapshot),
            daemon=True,
        ).start()

    def _conversion_worker(self, custom_name, paths_to_convert):
        """Background worker for PIL PDF compilation."""
        try:
            target_dir = self.user_dir or "."
            os.makedirs(target_dir, exist_ok=True)
            out_filename = f"{custom_name}.pdf"
            local_out = os.path.join(target_dir, out_filename)

            # Compile into app's private sandbox
            convert_images_to_pdf(paths_to_convert, local_out)

            file_size_str = format_bytes(os.path.getsize(local_out))
            doc_info = f"{len(paths_to_convert)} Pages  •  {file_size_str}"

            history_entry = {
                "id": str(int(time.time())),
                "name": out_filename,
                "path": local_out,
                "pages": len(paths_to_convert),
                "size": file_size_str,
                "date": time.strftime("%d %b %Y, %I:%M %p"),
            }

            Clock.schedule_once(
                lambda dt: self._on_conversion_finished(
                    local_out, out_filename, doc_info, history_entry
                ),
                0,
            )
        except Exception as e:
            err_msg = str(e)
            Clock.schedule_once(lambda dt: self._on_conversion_error(err_msg), 0)

    def _on_conversion_finished(self, local_path, doc_name, doc_info, history_entry):
        """Called on main UI thread upon successful PDF generation."""
        self.is_converting = False
        self._add_to_history(history_entry)
        self._refresh_gallery()

        # Open the Success & Export Sheet
        modal = ExportModal(
            local_path=local_path,
            doc_name=doc_name,
            doc_info=doc_info,
            on_share_cb=self.share_pdf,
            on_save_cb=self.save_pdf_to_device,
            on_view_cb=self.view_pdf,
        )
        modal.open()

    def _on_conversion_error(self, err_msg):
        """Called on main UI thread if PDF generation failed."""
        self.is_converting = False
        self._refresh_gallery()
        self.show_alert("Conversion Error", f"Failed to create PDF:\n{err_msg}")

    def show_alert(self, title, message):
        """Display alert modal."""
        AlertModal(title=title, message=message).open()

    # --- Sharing & Device Actions ---
    def share_pdf(self, local_path):
        """Native share sheet (WhatsApp, Social Media, Email, etc.)."""
        if platform == "android":
            try:
                from androidstorage4kivy import SharedStorage, ShareSheet

                ss = SharedStorage()
                shared_uri = ss.copy_to_shared(local_path)
                ShareSheet().share_file(shared_uri)
            except Exception as e:
                self.show_alert("Share Error", f"Unable to open ShareSheet: {e}")
        else:
            import webbrowser

            webbrowser.open(local_path)

    def save_pdf_to_device(self, local_path):
        """Explicitly save the PDF to Android shared storage (Downloads / Documents)."""
        if platform == "android":
            try:
                from androidstorage4kivy import SharedStorage

                SharedStorage().copy_to_shared(local_path)
                return True
            except Exception as e:
                self.show_alert("Save Error", f"Could not save file: {e}")
                return False
        return True

    def view_pdf(self, local_path):
        """Open PDF in default PDF reader."""
        if platform == "android":
            try:
                from androidstorage4kivy import SharedStorage, ShareSheet

                ss = SharedStorage()
                shared_uri = ss.copy_to_shared(local_path)
                ShareSheet().view_file(shared_uri)
            except Exception as e:
                self.show_alert("View Error", f"Unable to open PDF viewer: {e}")
        else:
            import webbrowser

            webbrowser.open(local_path)

    # --- History Management ---
    def _get_history_file_path(self):
        target_dir = self.user_dir or "."
        return os.path.join(target_dir, HISTORY_FILE)

    def _load_history_from_disk(self):
        hpath = self._get_history_file_path()
        if os.path.exists(hpath):
            try:
                with open(hpath, "r", encoding="utf-8") as f:
                    self.history_list = json.load(f)
            except Exception:
                self.history_list = []
        else:
            self.history_list = []

    def _save_history_to_disk(self):
        hpath = self._get_history_file_path()
        try:
            with open(hpath, "w", encoding="utf-8") as f:
                json.dump(self.history_list, f, indent=2)
        except Exception as e:
            print(f"Error saving history: {e}")

    def _add_to_history(self, entry):
        updated = [entry] + [h for h in self.history_list if h.get("path") != entry["path"]]
        self.history_list = updated
        self._save_history_to_disk()

    def delete_history_item(self, item):
        path = item.get("path")
        if path and os.path.exists(path):
            try:
                os.remove(path)
            except Exception:
                pass
        self.history_list = [h for h in self.history_list if h.get("id") != item.get("id")]
        self._save_history_to_disk()
        self._render_history_tab()

    def clear_history(self, *_):
        for item in self.history_list:
            path = item.get("path")
            if path and os.path.exists(path):
                try:
                    os.remove(path)
                except Exception:
                    pass
        self.history_list = []
        self._save_history_to_disk()
        self._render_history_tab()

    def _render_history_tab(self):
        scroll_box = self.ids.history_scroll_list
        scroll_box.clear_widgets()
        for item in self.history_list:
            card = HistoryCard(
                item=item,
                on_share_cb=self.share_pdf,
                on_save_cb=self.save_pdf_to_device,
                on_view_cb=self.view_pdf,
                on_delete_cb=self.delete_history_item,
            )
            scroll_box.add_widget(card)


class Img2PdfApp(App):
    def build(self):
        Builder.load_string(KV_DESIGN)
        return MainScreen()


if __name__ == "__main__":
    Img2PdfApp().run()
