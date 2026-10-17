# PDFDost 📄✨

<p align="center">
  <img src="PDFDost-icon.png" alt="PDFDost Logo" width="120" style="border-radius: 24px;" />
</p>

<p align="center">
  <b>100% Free Forever • Privacy-First • Offline-First Document & PDF Utility</b><br>
  <i>Crafted with dedication by <b>Vrushabh Dhote</b></i>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20Web-green.svg?style=flat-square" alt="Platform" />
  <img src="https://img.shields.io/badge/Flutter-3.x-blue.svg?style=flat-square" alt="Flutter" />
  <img src="https://img.shields.io/badge/Release-v1.1.1-purple.svg?style=flat-square" alt="Release" />
  <img src="https://img.shields.io/badge/License-Open%20Source-orange.svg?style=flat-square" alt="License" />
  <img src="https://img.shields.io/badge/Build-GitHub%20Actions-brightgreen.svg?style=flat-square" alt="CI/CD" />
  <img src="https://img.shields.io/badge/Processing-100%25%20On--Device-red.svg?style=flat-square" alt="Offline" />
</p>

<p align="center">
  <a href="https://pdfdost-app.netlify.app"><b>🚀 Live Web App (Netlify)</b></a> •
  <a href="https://devvrushabh.github.io/PDFDost/privacy.html"><b>🛡️ Live Privacy Policy</b></a> •
  <a href="https://devvrushabh.github.io/PDFDost/"><b>🌐 Official Website</b></a> •
  <a href="https://github.com/devvrushabh/PDFDost/releases/latest"><b>⬇️ Download Latest APK (v1.1.1)</b></a>
</p>

---

## 📖 Table of Contents

- [Overview](#-overview)
- [Key Highlights](#-key-highlights)
- [How the App Works](#-how-the-app-works)
  - [1. Home Screen (Document Sets, Folders & File Management)](#1-home-screen-document-sets-folders--file-management)
  - [2. Document Scanner & Signature Studio](#2-document-scanner--signature-studio)
  - [3. Tools Screen (Complete 12-Tool PDF & Office Suite)](#3-tools-screen-complete-12-tool-pdf--office-suite)
  - [4. Settings Screen (Customization & Trash Retention)](#4-settings-screen-customization--trash-retention)
- [All Features & Functional Details](#-all-features--functional-details)
  - [PDF Creation & Conversion Tools](#pdf-creation--conversion-tools)
  - [PDF Editing & Manipulation Tools](#pdf-editing--manipulation-tools)
  - [Document Organization & Sets](#document-organization--sets)
  - [Trash & 30-Day Auto-Retention](#trash--30-day-auto-retention)
- [Supported Formats](#-supported-formats)
- [Privacy & Security](#-privacy--security)
- [Project Architecture](#-project-architecture)
- [Getting Started & Installation](#-getting-started--installation)
  - [Download Pre-built APK](#option-1-download-pre-built-release-apk)
  - [Build for Android](#option-2-build-for-android)
  - [Build for Web](#option-3-build-for-web)
- [Support the Project](#-support-the-project)
- [Author & Credits](#-author--credits)

---

## 🌟 Overview

**PDFDost** is a comprehensive, modern, and privacy-conscious document and PDF utility application engineered for **Android** and **Web**. Designed as an ad-free, open alternative to subscription-locked document scanner tools, PDFDost offers enterprise-grade document scanning, PDF conversion, editing, splitting, merging, watermarking, password encryption, and multi-folder organization—completely **free**, without watermarks, and entirely **offline**.

---

## 🚀 Key Highlights

- **🔒 100% Private & Offline**: No cloud uploads. Every scan, conversion, and password lock takes place locally in device sandbox memory.
- **🏠 Unified Home Dashboard**: Centralized hub managing multi-page Document Sets, custom color-coded folders, and converted PDFs.
- **📷 Pro Camera Scanner Studio**: Real-time laser sweep animation, flashlight, corner reticle guides, and interactive 4-corner perspective crop with 2.5x magnification loupe.
- **✍️ Signature Scanner Studio**: Extract clean digital signatures with transparent background cutout, thresholding, and vector pen color options.
- **🎨 Pro Color Filter Engine**: Magic Color, B&W, Grayscale, Sharp, Warm, Cool, and High Contrast presets with fine-grain brightness and contrast sliders.
- **🔄 Drag-and-Drop Reordering**: Hold and drag pages or files to set the exact sequence before converting.
- **🗑️ 30-Day Trash Auto-Retention**: Deleted files are kept safely in the Trash bin for 30 days before permanent deletion, with instant 1-tap restore.
- **🎨 Modern Material 3 Design**: Soft coral/salmon accent palette, smooth transitions, and dynamic Dark/Light theme support.
- **💸 Truly Free & Ad-Free**: No paywalls, no subscriptions, no forced account signups.

---

## 📱 How the App Works

PDFDost is organized into three streamlined tabs accessible via the bottom navigation bar:

```
[ 🏠 Home ]              [ 🛠️ Tools ]              [ ⚙️ Settings ]
```

### 1. Home Screen (Document Sets, Folders & File Management)

The Home screen is your primary workspace for document collection and management:

- **Document Sets View**: Scanned documents appear as organized card sets displaying real-time page count badges (`N`), completion badges, and high-resolution cover thumbnails.
- **Folder Filtering & Creation**:
  - Tap the **`📁+`** icon to create custom folders with personalized names and accent colors.
  - Filter documents by folders, **All**, **Recent**, or **Favourites** using quick chips.
- **Multi-Selection Batch Actions**:
  - Select multiple document sets or PDF files at once.
  - Batch-move to custom folders, batch-export as PDFs, or batch-delete to the 30-day Trash.
- **Document Actions (Three-Dot Menu `⋮`)**:
  - **Open & View**: Preview all pages in the set.
  - **Add Pages**: Import additional images or capture more pages with the camera.
  - **Move to Folder**: Assign or reassign documents to any folder.
  - **Export as PDF**: Instantly generate and export the document set into a PDF.
  - **Rename & Delete**: Rename document titles or safely move them to the 30-day Trash bin.
- **Dual Floating Action Button (FAB)**:
  - **Camera (`📷`)**: Instantly launches the Camera Scanner Studio for multi-page captures.
  - **Action Menu (`+`)**: Opens the *Create or Import* bottom sheet to create new folders, import gallery images, or start scanning.

---

### 2. Document Scanner & Signature Studio

PDFDost includes an on-device document imaging engine:

- **Camera Scanner**:
  - Viewfinder with reticle corner guides, Spirit Level indicator, and holographic laser sweep.
  - Support for multi-page batch scanning.
  - Dedicated scan modes: **Documents**, **ID Cards** (Front & Back composite), **Book Spreads** (dual-page split), and **Photos**.
- **Interactive 4-Corner Quad Crop**:
  - Drag 4 corners independently to fix perspective skew.
  - 2.5x magnification loupe provides pixel-perfect corner alignment.
- **Filter & Enhancement Presets**:
  - **Magic Color**: Automatically brightens document backgrounds while sharpening text.
  - **B&W / Grayscale**: High-contrast document mode optimal for forms and contracts.
  - **Sharp, Warm, Cool, Vivid**: Specialized photo presets.
  - Real-time brightness & contrast adjustment sliders.
- **Signature Studio**:
  - Capture physical signatures on paper.
  - Automatic background removal with transparent PNG export.
  - Real-time threshold adjustment and pen ink color selector (Black, Navy, Blue, Red).

---

### 3. Tools Screen (Complete 12-Tool PDF & Office Suite)

The Tools screen contains a complete suite of specialized document conversion and editing utilities:

| Tool | Icon | Description |
| :--- | :---: | :--- |
| **Images to PDF** | 🖼️ | Convert single or multiple images (JPG, PNG, WebP) into PDF with custom margins, orientations, and page sizes. |
| **Word to PDF** | 📝 | Convert `.docx`, `.doc`, `.xlsx`, `.csv`, `.txt`, and other office documents into PDF. |
| **Merge PDF** | 📑 | Combine two or more PDF files into a single consolidated PDF document with hold-and-drag reordering. |
| **Split PDF** | ✂️ | Extract specific pages or split multi-page PDFs by custom page ranges (e.g., `1-3, 5, 8-10`). |
| **PDF to Word** | 📄 | Convert PDF documents into editable Microsoft Word (`.docx`) files. |
| **PDF to PowerPoint**| 📊 | Convert PDF presentation slides into editable PowerPoint (`.pptx`) decks. |
| **PDF to Excel** | 📈 | Extract tabular data and text from PDF documents into Excel spreadsheets (`.xlsx`). |
| **PDF to JPG** | 🌄 | Extract high-resolution JPEG image files for every page of a PDF. |
| **Page Numbers** | 🔢 | Stamp customized page numbers on PDF headers/footers with alignment and custom prefix options. |
| **Watermark PDF** | 🏷️ | Add custom text watermarks across PDF pages with adjustable opacity, angle, and font size. |
| **Rotate PDF** | 🔄 | Rotate all pages of a PDF by 90°, 180°, or 270° to fix orientation. |
| **Lock PDF** | 🔒 | Secure PDF documents with strong password protection and encryption. |

---

### 4. Settings Screen (Customization & Trash Retention)

- **Developer Showcase**: Features the **Free App By Vrushabh Dhote** recognition badge.
- **Support & UPI Donations**: Direct donation via UPI (`8830638458-2@ybl`) with an interactive QR code modal for scanning and contributing to open-source development.
- **Preferences**:
  - **Dark Mode**: Switch between sleek Dark Theme (`#141518`) and clean Light Theme (`#F8FAFC`).
  - **Data Usage Controls**: Toggle mobile data confirmation alerts.
  - **OCR Language Selection**: Choose optical character recognition language models.
- **Google Account & Cloud Backup**:
  - **Google Account Sign-In & Sign-Up**: Quick one-tap authentication and configurable account management.
  - **Google Drive Storage**: Safely back up documents, Document Sets, scans, and PDFs to your personal Google Drive folder.
  - **Firebase Database Credentials**: Configurable Firebase Database credentials store & metadata backup.
  - **Auto-Sync & Manual Sync**: Toggle automatic background synchronization or trigger instant cloud backups anytime.
- **Trash & Auto-Retention Hub**:
  - View all deleted documents and sets along with their countdown of remaining days (out of 30 days).
  - 1-click **Restore** returns items directly back to Home.
  - **Delete Permanently** and **Empty Trash** for permanent on-device storage cleanup.

---

## 🛠️ All Features & Functional Details

### PDF Creation & Conversion Tools
- **Hold-and-Drag Reordering**: All converter tools support long-pressing and dragging file items up/down to arrange the exact page sequence prior to conversion.
- **Multi-File Batch Selection**: Pick multiple photos or documents simultaneously using Android's native file picker.
- **Quality & Compression**: Optimized PDF generation ensures high visual fidelity while maintaining compact file sizes.

### PDF Editing & Manipulation Tools
- **Visual Split Selector**: Interactively choose split ranges or specific single pages to extract.
- **Custom Watermarking**: Set text, opacity (0.1 to 1.0), rotation angle (diagonal or horizontal), and custom font colors to safeguard sensitive documents.
- **Password Locking**: Encrypt PDF files with user-defined passwords with confirmation dialogs and individual completed document delete controls.

### Document Organization & Sets
- **Document Grouping**: Multiple imported photos or scanned pages are neatly grouped into single document sets rather than cluttering storage with isolated files.
- **Visual Cover Mockups**: Sets automatically render vector covers or thumbnails representing the first scanned page.

### Trash & 30-Day Auto-Retention
- Deleted items are moved to an isolated Trash cache (`StorageEngine.moveToTrash`).
- Items record a precise deletion timestamp.
- Upon app launch and Trash viewing, files older than 30 days are automatically pruned permanently.
- Users can restore any document within the 30-day window without losing file contents or metadata.

---

## 📁 Supported Formats

| Category | Supported File Extensions |
| :--- | :--- |
| **Images** | `.jpg`, `.jpeg`, `.png`, `.webp`, `.bmp`, `.heic` |
| **Word Documents** | `.doc`, `.docx` |
| **Spreadsheets** | `.xlsx`, `.xlsm`, `.xlsb`, `.xls`, `.xlw`, `.xltx`, `.xltm`, `.xlt`, `.csv`, `.ods` |
| **Text & Data** | `.txt`, `.xml`, `.prn` |
| **PDF Documents** | `.pdf` |

---

## 🔐 Privacy & Security

PDFDost is engineered from the ground up with a **zero-cloud, privacy-first** philosophy:

1. **No External Server Calls**: All image compression, document grouping, encryption, and conversions occur directly in the local sandbox of your device.
2. **No Data Tracking**: PDFDost has no telemetry, tracking SDKs, analytics, or third-party advertising modules.
3. **No Account Required**: The application does not require registration, email addresses, or phone numbers to unlock any feature.

---

## 🏗️ Project Architecture

```
PDFDost/
├── .github/workflows/
│   └── build.yml               # Automated Android release APK CI/CD pipeline
├── android/                    # Android native project files & Gradle configuration
├── android_custom/             # Custom native shell, icons & MediaStore scripts
├── assets/                     # App logo, UPI QR, and graphic resources
├── docs/                       # Privacy policy and web documentation pages
├── lib/
│   ├── main.dart               # App entrypoint, theme controller, navigation stack
│   ├── models/
│   │   └── models.dart         # DocumentSet, HistoryItem, TrashItem data models
│   ├── screens/
│   │   ├── files_tab.dart      # Home screen: Document sets, folders, PDF list, multi-select
│   │   ├── tools_tab.dart      # Suite of 12 PDF creation, conversion, and editing tools
│   │   ├── settings_tab.dart   # Preferences, theme switch, UPI donate, and trash hub
│   │   ├── scanner_camera_screen.dart # Full camera scanner with guides & level indicator
│   │   ├── document_crop_screen.dart  # Interactive 4-corner perspective distortion crop
│   │   ├── document_filter_screen.dart # Color filters, contrast/brightness tuning
│   │   ├── scanner_batch_editor_screen.dart # Multi-page review, rotate & batch filter
│   │   ├── signature_scanner_screen.dart # Signature extraction with transparent cutout
│   │   ├── document_set_screen.dart   # Single document set page viewer & editor
│   │   ├── image_to_pdf_screen.dart   # Image to PDF converter with reordering
│   │   ├── merge_pdf_screen.dart      # Reorderable multi-PDF merger
│   │   ├── split_pdf_screen.dart      # Custom page range PDF splitter
│   │   ├── word_to_pdf_screen.dart    # Office documents to PDF converter
│   │   ├── compress_pdf_screen.dart   # PDF compression utility
│   │   └── trash_screen.dart          # 30-day Trash retention manager
│   ├── services/
│   │   ├── pdf_engine.dart     # Core PDF processing, merging, splitting & rendering
│   │   ├── scanner_engine.dart # Image processing, corner quad transform, color filters
│   │   ├── storage_engine.dart # Local file persistence, history, and trash retention
│   │   └── word_engine.dart    # Word/Excel/Document parsing and PDF compilation
│   └── widgets/
│       ├── app_logo.dart       # Unified branded PDFDost header logo
│       ├── export_modal.dart   # Interactive PDF export, share, and preview sheet
│       ├── login_modal.dart    # Profile and account details modal sheet
│       └── space_empty_illustration.dart # Custom vector empty-state illustration
├── web/                        # PWA & Web application shell, manifest, and icons
├── pubspec.yaml                # Flutter project dependencies and assets configuration
├── analysis_options.yaml       # Code quality and linting configuration
└── README.md                   # Comprehensive project documentation
```

---

## 📥 Getting Started & Installation

### Option 1: Download Pre-built Release APK
1. Go to the [GitHub Releases](https://github.com/devvrushabh/PDFDost/releases/latest).
2. Download the latest **`PDFDost-v1.1.1.apk`**.
3. Install the APK on any Android device running Android 7.0 (API 24) or higher.

### Option 2: Build for Android

#### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.24.x or newer)
- [Java Development Kit](https://adoptium.net/) (JDK 17 or JDK 21)
- Android SDK (API 34/36)

#### Build Instructions
```bash
# 1. Clone the repository
git clone https://github.com/devvrushabh/PDFDost.git
cd PDFDost

# 2. Install Flutter dependencies
flutter pub get

# 3. Build release APK
flutter build apk --release --android-skip-build-dependency-validation

# The compiled APK will be generated at:
# build/app/outputs/flutter-apk/app-release.apk
```

### Option 3: Build for Web

```bash
# Build the optimized Web application bundle
flutter build web

# The web output will be located in build/web/
```

---

## 💖 Support the Project

PDFDost is completely free, open-source, and maintained independently. If you enjoy using the app and want to support its continuous development, you can contribute via UPI:

<p align="center">
  <b>UPI ID:</b> <code>8830638458-2@ybl</code><br>
  <b>Payee:</b> Vrushabh Dhote
</p>

You can also donate directly from within the app by opening **Settings ➔ Support PDFDost** and scanning the QR code or tapping **Donate and Pay**.

---

## 👨‍💻 Author & Credits

- **Developer**: [Vrushabh Dhote](https://github.com/devvrushabh)
- **Email**: `vrushabhdhote29@gmail.com`
- **Project**: [devvrushabh/PDFDost](https://github.com/devvrushabh/PDFDost)

---

<p align="center">
  <i>Developed with ❤️ for seamless, privacy-respecting document workflows.</i>
</p>
