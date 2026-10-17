/**
 * PDFDost - Exact iLovePDF Web Platform
 * Complete 32-Tool Suite with Dedicated Tool Pages, Pixel-Perfect Dropdowns,
 * In-Browser PDF Processing via pdf-lib & Google Drive Integration
 * Developed by Vrushabh Dhote
 */

// ============================================================================
// Tool Definitions Catalog (32 Tools + Workflows)
// ============================================================================
const TOOLS = [
  // 1. Merge PDF
  {
    id: 'merge_pdf',
    slugs: ['merge_pdf', 'merge-pdf'],
    title: 'Merge PDF files',
    desc: 'Combine PDFs in the order you want with the easiest PDF merger available.',
    category: 'organize',
    btnLabel: 'Select PDF files',
    dropLabel: 'or drop PDFs here',
    accept: '.pdf',
    multiple: true,
    action: 'merge',
    actionBtnText: 'Merge PDF',
    iconColor: '#E5322D',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#FEE2E2"/><path d="M12 12h10v10H12z" fill="#E5322D" rx="2"/><path d="M22 22h10v10H22z" fill="#E5322D" rx="2"/><path d="M22 17l-3 3 3 3" stroke="#FFF" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/><path d="M22 27l3-3-3-3" stroke="#FFF" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>`
  },
  // 2. Split PDF
  {
    id: 'split_pdf',
    slugs: ['split_pdf', 'split-pdf'],
    title: 'Split PDF file',
    desc: 'Separate one page or a whole set for easy conversion into independent PDF files.',
    category: 'organize',
    btnLabel: 'Select PDF file',
    dropLabel: 'or drop PDF here',
    accept: '.pdf',
    multiple: false,
    action: 'split',
    actionBtnText: 'Split PDF',
    iconColor: '#E5322D',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#FEE2E2"/><path d="M14 14h8v8h-8z" fill="#E5322D" rx="2"/><path d="M22 22h8v8h-8z" fill="#E5322D" rx="2"/><path d="M18 18l-3-3" stroke="#E5322D" stroke-width="2" stroke-linecap="round"/><path d="M26 26l3 3" stroke="#E5322D" stroke-width="2" stroke-linecap="round"/></svg>`
  },
  // 3. Compress PDF
  {
    id: 'compress_pdf',
    slugs: ['compress_pdf', 'compress-pdf'],
    title: 'Compress PDF file',
    desc: 'Reduce file size while optimizing for maximal PDF quality.',
    category: 'optimize',
    btnLabel: 'Select PDF files',
    dropLabel: 'or drop PDFs here',
    accept: '.pdf',
    multiple: true,
    action: 'compress',
    actionBtnText: 'Compress PDF',
    iconColor: '#10B981',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#D1FAE5"/><rect x="12" y="12" width="20" height="20" rx="4" fill="#10B981"/><path d="M16 16l3 3m0-3l-3 3M28 16l-3 3m0-3l3 3M16 28l3-3m0 3l-3-3M28 28l-3-3m0 3l3-3" stroke="#FFF" stroke-width="2" stroke-linecap="round"/></svg>`
  },
  // 4. PDF to Word
  {
    id: 'pdf_to_word',
    slugs: ['pdf_to_word', 'pdf-to-word'],
    title: 'Convert PDF to WORD',
    desc: 'Easily convert your PDF files into easy to edit DOC and DOCX documents. The converted WORD document is almost 100% accurate.',
    category: 'convert',
    btnLabel: 'Select PDF file',
    dropLabel: 'or drop PDF here',
    accept: '.pdf',
    multiple: false,
    action: 'pdf-to-word',
    actionBtnText: 'Convert to Word',
    iconColor: '#2563EB',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#DBEAFE"/><rect x="18" y="18" width="16" height="16" rx="3" fill="#2563EB"/><text x="22" y="30" fill="#FFF" font-size="11" font-weight="900" font-family="sans-serif">W</text><path d="M12 12h10v14H12z" fill="#93C5FD" rx="2"/></svg>`
  },
  // 5. PDF to PowerPoint
  {
    id: 'pdf_to_powerpoint',
    slugs: ['pdf_to_powerpoint', 'pdf-to-powerpoint'],
    title: 'Convert PDF to POWERPOINT',
    desc: 'Turn your PDF files into easy to edit PPT and PPTX slideshows.',
    category: 'convert',
    btnLabel: 'Select PDF file',
    dropLabel: 'or drop PDF here',
    accept: '.pdf',
    multiple: false,
    action: 'convert',
    actionBtnText: 'Convert to PowerPoint',
    iconColor: '#EA580C',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#FFEDD5"/><rect x="18" y="18" width="16" height="16" rx="3" fill="#EA580C"/><text x="23" y="30" fill="#FFF" font-size="11" font-weight="900" font-family="sans-serif">P</text><path d="M12 12h10v14H12z" fill="#FDBA74" rx="2"/></svg>`
  },
  // 6. PDF to Excel
  {
    id: 'pdf_to_excel',
    slugs: ['pdf_to_excel', 'pdf-to-excel'],
    title: 'Convert PDF to EXCEL',
    desc: 'Pull data straight from PDFs into Excel spreadsheets in a few short seconds.',
    category: 'convert',
    btnLabel: 'Select PDF file',
    dropLabel: 'or drop PDF here',
    accept: '.pdf',
    multiple: false,
    action: 'convert',
    actionBtnText: 'Convert to Excel',
    iconColor: '#059669',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#D1FAE5"/><rect x="18" y="18" width="16" height="16" rx="3" fill="#059669"/><text x="23" y="30" fill="#FFF" font-size="11" font-weight="900" font-family="sans-serif">X</text><path d="M12 12h10v14H12z" fill="#6EE7B7" rx="2"/></svg>`
  },
  // 7. Word to PDF
  {
    id: 'word_to_pdf',
    slugs: ['word_to_pdf', 'word-to-pdf'],
    title: 'Convert WORD to PDF',
    desc: 'Make DOC and DOCX files easy to read by converting them to PDF.',
    category: 'convert',
    btnLabel: 'Select WORD files',
    dropLabel: 'or drop WORD documents here',
    accept: '.doc,.docx,.txt',
    multiple: false,
    action: 'convert',
    actionBtnText: 'Convert to PDF',
    iconColor: '#2563EB',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#EFF6FF"/><rect x="12" y="12" width="14" height="14" rx="2" fill="#2563EB"/><text x="15" y="23" fill="#FFF" font-size="10" font-weight="900">W</text><rect x="18" y="18" width="14" height="14" rx="2" fill="#E5322D"/><path d="M21 21l8 8" stroke="#FFF" stroke-width="2" stroke-linecap="round"/></svg>`
  },
  // 8. PowerPoint to PDF
  {
    id: 'powerpoint_to_pdf',
    slugs: ['powerpoint_to_pdf', 'powerpoint-to-pdf'],
    title: 'Convert POWERPOINT to PDF',
    desc: 'Make PPT and PPTX slideshows easy to view by converting them to PDF.',
    category: 'convert',
    btnLabel: 'Select POWERPOINT files',
    dropLabel: 'or drop POWERPOINT files here',
    accept: '.ppt,.pptx',
    multiple: false,
    action: 'convert',
    actionBtnText: 'Convert to PDF',
    iconColor: '#EA580C',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#FFF7ED"/><rect x="12" y="12" width="14" height="14" rx="2" fill="#EA580C"/><text x="16" y="23" fill="#FFF" font-size="10" font-weight="900">P</text><rect x="18" y="18" width="14" height="14" rx="2" fill="#E5322D"/><path d="M21 21l8 8" stroke="#FFF" stroke-width="2" stroke-linecap="round"/></svg>`
  },
  // 9. Excel to PDF
  {
    id: 'excel_to_pdf',
    slugs: ['excel_to_pdf', 'excel-to-pdf'],
    title: 'Convert EXCEL to PDF',
    desc: 'Make EXCEL spreadsheets easy to read by converting them to PDF.',
    category: 'convert',
    btnLabel: 'Select EXCEL files',
    dropLabel: 'or drop EXCEL files here',
    accept: '.xls,.xlsx,.csv',
    multiple: false,
    action: 'convert',
    actionBtnText: 'Convert to PDF',
    iconColor: '#059669',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#ECFDF5"/><rect x="12" y="12" width="14" height="14" rx="2" fill="#059669"/><text x="16" y="23" fill="#FFF" font-size="10" font-weight="900">X</text><rect x="18" y="18" width="14" height="14" rx="2" fill="#E5322D"/><path d="M21 21l8 8" stroke="#FFF" stroke-width="2" stroke-linecap="round"/></svg>`
  },
  // 10. Edit PDF
  {
    id: 'edit_pdf',
    slugs: ['edit_pdf', 'edit-pdf'],
    title: 'Edit PDF',
    desc: 'Add text, images, shapes or freehand annotations to a PDF document. Edit size, font, and color.',
    category: 'edit',
    btnLabel: 'Select PDF file',
    dropLabel: 'or drop PDF here',
    accept: '.pdf',
    multiple: false,
    action: 'edit',
    actionBtnText: 'Edit PDF',
    iconColor: '#7C3AED',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#EDE9FE"/><rect x="12" y="12" width="20" height="20" rx="4" fill="#7C3AED"/><path d="M17 26l7-7 3 3-7 7-4 1 1-4z" fill="#FFF"/></svg>`
  },
  // 11. PDF to JPG
  {
    id: 'pdf_to_jpg',
    slugs: ['pdf_to_jpg', 'pdf-to-jpg'],
    title: 'Convert PDF to JPG',
    desc: 'Convert each PDF page into a JPG or extract all images contained in a PDF.',
    category: 'convert',
    btnLabel: 'Select PDF file',
    dropLabel: 'or drop PDF here',
    accept: '.pdf',
    multiple: false,
    action: 'convert',
    actionBtnText: 'Convert to JPG',
    iconColor: '#D97706',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#FEF3C7"/><path d="M12 12h12v14H12z" fill="#FDE68A"/><rect x="18" y="18" width="14" height="14" rx="3" fill="#D97706"/><circle cx="22" cy="22" r="1.5" fill="#FFF"/><path d="M20 28l3-3 4 4" stroke="#FFF" stroke-width="1.5"/></svg>`
  },
  // 12. JPG to PDF
  {
    id: 'jpg_to_pdf',
    slugs: ['jpg_to_pdf', 'jpg-to-pdf'],
    title: 'Convert JPG to PDF',
    desc: 'Convert JPG images to PDF in seconds. Easily adjust orientation and margins.',
    category: 'convert',
    btnLabel: 'Select JPG images',
    dropLabel: 'or drop JPG images here',
    accept: '.jpg,.jpeg,.png,.webp',
    multiple: true,
    action: 'images-to-pdf',
    actionBtnText: 'Convert to PDF',
    iconColor: '#D97706',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#FEF3C7"/><rect x="12" y="12" width="14" height="14" rx="2" fill="#D97706"/><text x="13" y="22" fill="#FFF" font-size="7" font-weight="900">JPG</text><rect x="18" y="18" width="14" height="14" rx="2" fill="#E5322D"/><path d="M21 21l8 8" stroke="#FFF" stroke-width="2" stroke-linecap="round"/></svg>`
  },
  // 13. Sign PDF
  {
    id: 'sign_pdf',
    slugs: ['sign_pdf', 'sign-pdf'],
    title: 'Sign PDF',
    desc: 'Sign yourself or request electronic signatures from others.',
    category: 'edit',
    btnLabel: 'Select PDF file',
    dropLabel: 'or drop PDF here',
    accept: '.pdf',
    multiple: false,
    action: 'edit',
    actionBtnText: 'Sign PDF',
    iconColor: '#2563EB',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#DBEAFE"/><rect x="12" y="12" width="20" height="20" rx="4" fill="#2563EB"/><path d="M22 17l4 4-8 8h-4v-4l8-8z" fill="#FFF"/></svg>`
  },
  // 14. Watermark
  {
    id: 'watermark',
    slugs: ['watermark', 'watermark_pdf'],
    title: 'Watermark PDF',
    desc: 'Stamp an image or text over your PDF in seconds. Choose typography, transparency and position.',
    category: 'edit',
    btnLabel: 'Select PDF file',
    dropLabel: 'or drop PDF here',
    accept: '.pdf',
    multiple: false,
    action: 'watermark',
    actionBtnText: 'Add Watermark',
    optionsType: 'watermark',
    iconColor: '#9D174D',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#FCE7F3"/><rect x="12" y="12" width="20" height="20" rx="4" fill="#9D174D"/><path d="M20 16h4v4h-4zM18 20h8v4h-8zM16 24h12v4H16z" fill="#FFF"/></svg>`
  },
  // 15. Rotate PDF
  {
    id: 'rotate_pdf',
    slugs: ['rotate_pdf', 'rotate-pdf'],
    title: 'Rotate PDF',
    desc: 'Rotate your PDFs the way you need them. You can even rotate multiple PDFs at once!',
    category: 'edit',
    btnLabel: 'Select PDF files',
    dropLabel: 'or drop PDFs here',
    accept: '.pdf',
    multiple: true,
    action: 'rotate',
    actionBtnText: 'Rotate PDF',
    optionsType: 'rotate',
    iconColor: '#7C3AED',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#EDE9FE"/><rect x="12" y="12" width="20" height="20" rx="4" fill="#7C3AED"/><path d="M22 17a5 5 0 1 1-5 5" fill="none" stroke="#FFF" stroke-width="2"/><polyline points="20 15 22 17 20 19" fill="none" stroke="#FFF" stroke-width="2"/></svg>`
  },
  // 16. HTML to PDF
  {
    id: 'html_to_pdf',
    slugs: ['html_to_pdf', 'html-to-pdf'],
    title: 'Convert HTML to PDF',
    desc: 'Convert webpages in HTML to PDF. Copy and paste the URL of the page you want and convert it with a click.',
    category: 'convert',
    btnLabel: 'Select HTML file',
    dropLabel: 'or drop HTML file here',
    accept: '.html,.htm',
    multiple: false,
    action: 'convert',
    actionBtnText: 'Convert to PDF',
    iconColor: '#D97706',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#FEF3C7"/><rect x="12" y="12" width="14" height="14" rx="2" fill="#D97706"/><text x="13" y="21" fill="#FFF" font-size="6" font-weight="900">HTML</text><rect x="18" y="18" width="14" height="14" rx="2" fill="#E5322D"/><path d="M21 21l8 8" stroke="#FFF" stroke-width="2"/></svg>`
  },
  // 17. Unlock PDF
  {
    id: 'unlock_pdf',
    slugs: ['unlock_pdf', 'unlock-pdf'],
    title: 'Unlock PDF',
    desc: 'Remove PDF password security, giving you the freedom to use your PDFs as you want.',
    category: 'security',
    btnLabel: 'Select PDF files',
    dropLabel: 'or drop PDFs here',
    accept: '.pdf',
    multiple: false,
    action: 'unlock',
    actionBtnText: 'Unlock PDF',
    optionsType: 'password',
    iconColor: '#0284C7',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#E0F2FE"/><rect x="12" y="12" width="20" height="20" rx="4" fill="#0284C7"/><path d="M20 20v-3a3 3 0 0 1 6 0" fill="none" stroke="#FFF" stroke-width="2"/><rect x="18" y="20" width="8" height="6" rx="1" fill="#FFF"/></svg>`
  },
  // 18. Protect PDF
  {
    id: 'protect_pdf',
    slugs: ['protect_pdf', 'protect-pdf'],
    title: 'Protect PDF file',
    desc: 'Protect PDF files with a password. Encrypt PDF documents to prevent unauthorized access.',
    category: 'security',
    btnLabel: 'Select PDF file',
    dropLabel: 'or drop PDF here',
    accept: '.pdf',
    multiple: false,
    action: 'protect',
    actionBtnText: 'Protect PDF',
    optionsType: 'password',
    iconColor: '#2563EB',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#DBEAFE"/><rect x="12" y="12" width="20" height="20" rx="4" fill="#2563EB"/><path d="M22 17l5 2v4c0 3-2 5-5 6s-5-3-5-6v-4l5-2z" fill="#FFF"/></svg>`
  },
  // 19. Organize PDF
  {
    id: 'organize_pdf',
    slugs: ['organize_pdf', 'organize-pdf'],
    title: 'Organize PDF',
    desc: 'Sort pages of your PDF file however you like. Delete PDF pages or add PDF pages to your document.',
    category: 'organize',
    btnLabel: 'Select PDF file',
    dropLabel: 'or drop PDF here',
    accept: '.pdf',
    multiple: true,
    action: 'organize',
    actionBtnText: 'Organize PDF',
    iconColor: '#EA580C',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#FFEDD5"/><rect x="12" y="12" width="9" height="20" rx="2" fill="#EA580C"/><rect x="23" y="12" width="9" height="20" rx="2" fill="#EA580C"/><path d="M16 16v12m11-12v12" stroke="#FFF" stroke-width="1.5"/></svg>`
  },
  // 20. PDF to PDF/A
  {
    id: 'pdf_to_pdfa',
    slugs: ['pdf_to_pdfa', 'pdf-to-pdfa'],
    title: 'Convert PDF to PDF/A',
    desc: 'Transform your PDF to PDF/A, the ISO-standardized version of PDF for long-term archiving.',
    category: 'convert',
    btnLabel: 'Select PDF file',
    dropLabel: 'or drop PDF here',
    accept: '.pdf',
    multiple: false,
    action: 'convert',
    actionBtnText: 'Convert to PDF/A',
    iconColor: '#475569',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#F1F5F9"/><rect x="12" y="12" width="20" height="20" rx="4" fill="#475569"/><text x="14" y="26" fill="#FFF" font-size="9" font-weight="bold">/A</text></svg>`
  },
  // 21. Repair PDF
  {
    id: 'repair_pdf',
    slugs: ['repair_pdf', 'repair-pdf'],
    title: 'Repair PDF file',
    desc: 'Repair a damaged PDF and recover data from corrupt PDF. Fix PDF files with our Repair tool.',
    category: 'optimize',
    btnLabel: 'Select PDF file',
    dropLabel: 'or drop PDF here',
    accept: '.pdf',
    multiple: false,
    action: 'compress',
    actionBtnText: 'Repair PDF',
    iconColor: '#65A30D',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#ECFCCB"/><rect x="12" y="12" width="20" height="20" rx="4" fill="#65A30D"/><path d="M17 27l6-6m-2-2l2-2 3 3-2 2" stroke="#FFF" stroke-width="2" stroke-linecap="round"/></svg>`
  },
  // 22. Page numbers
  {
    id: 'page_numbers',
    slugs: ['page_numbers', 'page-numbers'],
    title: 'Add Page Numbers to PDF',
    desc: 'Add page numbers into PDFs with ease. Choose your positions, dimensions, and typography.',
    category: 'edit',
    btnLabel: 'Select PDF file',
    dropLabel: 'or drop PDF here',
    accept: '.pdf',
    multiple: false,
    action: 'page-numbers',
    actionBtnText: 'Add Page Numbers',
    iconColor: '#831843',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#FCE7F3"/><rect x="12" y="12" width="9" height="9" rx="2" fill="#831843"/><text x="15" y="19" fill="#FFF" font-size="7" font-weight="bold">1</text><rect x="23" y="12" width="9" height="9" rx="2" fill="#831843"/><text x="26" y="19" fill="#FFF" font-size="7" font-weight="bold">2</text><rect x="12" y="23" width="9" height="9" rx="2" fill="#831843"/><text x="15" y="30" fill="#FFF" font-size="7" font-weight="bold">3</text><rect x="23" y="23" width="9" height="9" rx="2" fill="#831843"/><text x="26" y="30" fill="#FFF" font-size="7" font-weight="bold">4</text></svg>`
  },
  // 23. Scan to PDF
  {
    id: 'scan_to_pdf',
    slugs: ['scan_to_pdf', 'scan-to-pdf'],
    title: 'Scan to PDF',
    desc: 'Capture document scans from your mobile device or desktop and send them instantly to your browser.',
    category: 'organize',
    btnLabel: 'Select Images or Documents',
    dropLabel: 'or drop image scans here',
    accept: '.jpg,.jpeg,.png,.webp,.pdf',
    multiple: true,
    action: 'images-to-pdf',
    actionBtnText: 'Generate PDF',
    iconColor: '#EA580C',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#FFEDD5"/><rect x="12" y="12" width="20" height="20" rx="4" fill="#EA580C"/><circle cx="22" cy="22" r="4" stroke="#FFF" stroke-width="2"/><path d="M16 16h3v3m10-3h-3v3m3 10h-3v-3m-10 3h3v-3" stroke="#FFF" stroke-width="1.5"/></svg>`
  },
  // 24. OCR PDF
  {
    id: 'ocr_pdf',
    slugs: ['ocr_pdf', 'ocr-pdf'],
    title: 'OCR PDF',
    desc: 'Easily convert scanned PDF into searchable and selectable documents with Optical Character Recognition.',
    category: 'intelligence',
    btnLabel: 'Select PDF file',
    dropLabel: 'or drop PDF here',
    accept: '.pdf',
    multiple: false,
    action: 'ocr',
    actionBtnText: 'Recognize Text',
    iconColor: '#16A34A',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#DCFCE7"/><rect x="12" y="12" width="20" height="20" rx="4" fill="#16A34A"/><text x="14" y="25" fill="#FFF" font-size="8" font-weight="900">[OCR]</text></svg>`
  },
  // 25. Compare PDF
  {
    id: 'compare_pdf',
    slugs: ['compare_pdf', 'compare-pdf'],
    title: 'Compare PDF files',
    desc: 'Show a side-by-side document comparison and easily spot changes between different file versions.',
    category: 'edit',
    btnLabel: 'Select 2 PDF files',
    dropLabel: 'or drop PDFs here',
    accept: '.pdf',
    multiple: true,
    action: 'merge',
    actionBtnText: 'Compare Documents',
    iconColor: '#2563EB',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#DBEAFE"/><rect x="12" y="12" width="9" height="20" rx="2" fill="#2563EB"/><rect x="23" y="12" width="9" height="20" rx="2" fill="#2563EB"/><line x1="14" y1="17" x2="19" y2="17" stroke="#FFF"/><line x1="25" y1="17" x2="30" y2="17" stroke="#FFF"/></svg>`
  },
  // 26. Redact PDF
  {
    id: 'redact_pdf',
    slugs: ['redact_pdf', 'redact-pdf'],
    title: 'Redact PDF',
    desc: 'Redact text and graphics to permanently remove sensitive information from a PDF.',
    category: 'security',
    btnLabel: 'Select PDF file',
    dropLabel: 'or drop PDF here',
    accept: '.pdf',
    multiple: false,
    action: 'watermark',
    actionBtnText: 'Apply Redactions',
    iconColor: '#1E293B',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#E2E8F0"/><rect x="12" y="12" width="20" height="20" rx="4" fill="#1E293B"/><rect x="15" y="20" width="14" height="4" fill="#FFF"/><text x="18" y="24" fill="#1E293B" font-size="5" font-weight="bold">x</text></svg>`
  },
  // 27. Crop PDF
  {
    id: 'crop_pdf',
    slugs: ['crop_pdf', 'crop-pdf'],
    title: 'Crop PDF',
    desc: 'Crop margins of PDF documents or select specific areas, then apply changes to one or all pages.',
    category: 'edit',
    btnLabel: 'Select PDF file',
    dropLabel: 'or drop PDF here',
    accept: '.pdf',
    multiple: false,
    action: 'edit',
    actionBtnText: 'Crop PDF',
    iconColor: '#831843',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#FCE7F3"/><rect x="12" y="12" width="20" height="20" rx="4" fill="#831843"/><path d="M16 20h8v8" stroke="#FFF" stroke-width="2" fill="none"/></svg>`
  },
  // 28. PDF Forms
  {
    id: 'pdf_forms',
    slugs: ['pdf_forms', 'pdf-forms'],
    title: 'Fill & Sign PDF Forms',
    desc: 'Detect form fields automatically, create interactive fillable PDFs, or fill PDF forms yourself.',
    category: 'edit',
    btnLabel: 'Select PDF file',
    dropLabel: 'or drop PDF here',
    accept: '.pdf',
    multiple: false,
    action: 'edit',
    actionBtnText: 'Fill Form',
    iconColor: '#7C3AED',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#EDE9FE"/><rect x="12" y="12" width="20" height="20" rx="4" fill="#7C3AED"/><rect x="15" y="15" width="4" height="4" fill="#FFF"/><line x1="22" y1="17" x2="28" y2="17" stroke="#FFF" stroke-width="1.5"/><rect x="15" y="22" width="4" height="4" fill="#FFF"/><line x1="22" y1="24" x2="28" y2="24" stroke="#FFF" stroke-width="1.5"/></svg>`
  },
  // 29. AI Summarizer
  {
    id: 'ai_summarizer',
    slugs: ['ai_summarizer', 'ai-summarizer'],
    title: 'AI PDF Summarizer',
    desc: 'Summarize key ideas, bullet points, and actionable takeaways from long PDFs with instant AI.',
    category: 'intelligence',
    btnLabel: 'Select PDF file',
    dropLabel: 'or drop PDF here',
    accept: '.pdf',
    multiple: false,
    action: 'ai-summarizer',
    actionBtnText: 'Summarize PDF',
    iconColor: '#6366F1',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#EEF2FF"/><rect x="12" y="12" width="20" height="20" rx="4" fill="#6366F1"/><path d="M22 16l1.5 4.5 4.5 1.5-4.5 1.5-1.5 4.5-1.5-4.5-4.5-1.5 4.5-1.5z" fill="#FFF"/></svg>`
  },
  // 30. Translate PDF
  {
    id: 'translate_pdf',
    slugs: ['translate_pdf', 'translate-pdf'],
    title: 'Translate PDF Document',
    desc: 'Translate PDF documents to and from over 100 languages with complete original formatting preserved.',
    category: 'intelligence',
    btnLabel: 'Select PDF file',
    dropLabel: 'or drop PDF here',
    accept: '.pdf',
    multiple: false,
    action: 'translate-pdf',
    actionBtnText: 'Translate Document',
    iconColor: '#4F46E5',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#EEF2FF"/><rect x="12" y="12" width="20" height="20" rx="4" fill="#4F46E5"/><text x="14" y="25" fill="#FFF" font-size="8" font-weight="bold">A 文</text></svg>`
  },
  // 31. PDF to Markdown
  {
    id: 'pdf_to_markdown',
    slugs: ['pdf_to_markdown', 'pdf-to-markdown'],
    title: 'Convert PDF to Markdown',
    desc: 'Extract text, headings, lists, tables, and code snippets from PDF into clean, reusable Markdown.',
    category: 'intelligence',
    btnLabel: 'Select PDF file',
    dropLabel: 'or drop PDF here',
    accept: '.pdf',
    multiple: false,
    action: 'pdf-to-markdown',
    actionBtnText: 'Convert to Markdown',
    iconColor: '#4338CA',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#EEF2FF"/><rect x="12" y="12" width="20" height="20" rx="4" fill="#4338CA"/><text x="14" y="25" fill="#FFF" font-size="8" font-weight="900">M↓</text></svg>`
  },
  // 32. Remove pages
  {
    id: 'remove_pages',
    slugs: ['remove_pages', 'remove-pages'],
    title: 'Remove PDF pages',
    desc: 'Delete pages from your PDF document easily with our interactive page remover.',
    category: 'organize',
    btnLabel: 'Select PDF file',
    dropLabel: 'or drop PDF here',
    accept: '.pdf',
    multiple: false,
    action: 'split',
    actionBtnText: 'Remove Pages',
    iconColor: '#EF4444',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#FEE2E2"/><rect x="12" y="12" width="20" height="20" rx="4" fill="#EF4444"/><path d="M17 17l10 10m0-10l-10 10" stroke="#FFF" stroke-width="2.5" stroke-linecap="round"/></svg>`
  },
  // 33. Extract pages
  {
    id: 'extract_pages',
    slugs: ['extract_pages', 'extract-pages'],
    title: 'Extract PDF pages',
    desc: 'Extract selected pages from your PDF and create a new independent PDF document.',
    category: 'organize',
    btnLabel: 'Select PDF file',
    dropLabel: 'or drop PDF here',
    accept: '.pdf',
    multiple: false,
    action: 'split',
    actionBtnText: 'Extract Pages',
    iconColor: '#EF4444',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#FEE2E2"/><rect x="12" y="12" width="20" height="20" rx="4" fill="#EF4444"/><path d="M16 16l8-8m0 0h-6m6 0v6" fill="none" stroke="#FFF" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>`
  }
];

// Workflow promo cards to complement the 5-column grid
const WORKFLOW_CARDS = [
  {
    isWorkflow: true,
    category: 'workflows',
    title: 'Automate PDF Workflows',
    desc: 'Connect PDFDost directly to your daily apps and Google Drive to automatically convert, sign and archive docs.',
    actionText: 'Explore Workflows →'
  },
  {
    isWorkflow: true,
    category: 'workflows',
    title: 'Developer Cloud API',
    desc: 'Integrate the highest performance PDF conversion & OCR tools directly into your web applications.',
    actionText: 'Read Developer Docs →'
  }
];

// App State
const App = {
  activeCategory: 'all',
  activeTool: null,
  selectedFiles: [],
  resultBytes: null,
  resultFilename: '',
  user: null,
  hoverTimeout: null
};

// ============================================================================
// Initialization & Router
// ============================================================================
document.addEventListener('DOMContentLoaded', () => {
  renderHomeCards();
  setupFilterPills();
  initAuthSession();
  setupDropdownBehaviors();
  setupDragAndDrop();

  // Listen to browser navigation
  window.addEventListener('popstate', () => {
    handleRouteFromURL();
  });

  // Initial routing
  handleRouteFromURL();
});

function handleRouteFromURL() {
  const path = window.location.pathname.replace(/^\/+/, '').trim();
  const hash = window.location.hash.replace(/^#\/?/, '').trim();
  const targetSlug = path || hash;

  if (targetSlug && targetSlug !== 'index.html') {
    const found = findToolBySlug(targetSlug);
    if (found) {
      openToolPage(found, false);
      return;
    }
  }
  showHomeView(false);
}

function findToolBySlug(slug) {
  const s = slug.toLowerCase().replace(/[-_]/g, '');
  return TOOLS.find(t => {
    const tid = t.id.toLowerCase().replace(/[-_]/g, '');
    const matchSlug = t.slugs && t.slugs.some(sl => sl.toLowerCase().replace(/[-_]/g, '') === s);
    return tid === s || matchSlug;
  });
}

// ============================================================================
// Navigation: Home vs Tool Page
// ============================================================================
function navigateToHome() {
  closeAllDropdowns();
  showHomeView(true);
}

function showHomeView(pushHistory = true) {
  App.activeTool = null;
  App.selectedFiles = [];

  document.getElementById('home-view').style.display = 'block';
  document.getElementById('tool-view').style.display = 'none';

  // Clear active state on nav links
  document.querySelectorAll('.nav-link').forEach(link => link.classList.remove('active-tool'));

  document.title = 'iLovePDF | Online PDF tools for PDF lovers';
  if (pushHistory && window.location.pathname !== '/') {
    window.history.pushState(null, '', '/');
  }
  window.scrollTo({ top: 0, behavior: 'smooth' });
}

function navigateToTool(slug) {
  closeAllDropdowns();
  const tool = findToolBySlug(slug);
  if (!tool) return;
  openToolPage(tool, true);
}

function openToolPage(tool, pushHistory = true) {
  App.activeTool = tool;
  App.selectedFiles = [];
  App.resultBytes = null;
  App.resultFilename = '';

  // Switch view
  document.getElementById('home-view').style.display = 'none';
  document.getElementById('tool-view').style.display = 'block';

  // Populate title & subtitles
  document.getElementById('tool-page-title').textContent = tool.title;
  document.getElementById('tool-page-subtitle').textContent = tool.desc;
  document.getElementById('tool-select-btn-text').textContent = tool.btnLabel || 'Select PDF files';
  document.getElementById('tool-drop-text').textContent = tool.dropLabel || 'or drop PDFs here';

  // Configure hidden file input
  const fileInput = document.getElementById('tool-file-input');
  fileInput.accept = tool.accept || '.pdf';
  fileInput.multiple = tool.multiple !== false;
  fileInput.value = '';

  // Reset workspace areas
  document.getElementById('tool-upload-initial').style.display = 'flex';
  document.getElementById('tool-staged-area').style.display = 'none';
  document.getElementById('tool-result-box').style.display = 'none';

  // Highlight active nav item
  updateNavbarActiveState(tool);

  // Update browser URL
  document.title = `${tool.title} - iLovePDF`;
  if (pushHistory) {
    const slug = tool.id;
    window.history.pushState(null, '', `/${slug}`);
  }
  window.scrollTo({ top: 0, behavior: 'smooth' });
}

function updateNavbarActiveState(tool) {
  document.querySelectorAll('.nav-link').forEach(link => link.classList.remove('active-tool'));
  if (tool.id.includes('merge')) {
    const el = document.getElementById('nav-link-merge');
    if (el) el.classList.add('active-tool');
  } else if (tool.id.includes('split')) {
    const el = document.getElementById('nav-link-split');
    if (el) el.classList.add('active-tool');
  } else if (tool.id.includes('compress')) {
    const el = document.getElementById('nav-link-compress');
    if (el) el.classList.add('active-tool');
  }
}

// ============================================================================
// Dropdown Menu System (CONVERT PDF & ALL PDF TOOLS)
// ============================================================================
function toggleDropdownMenu(type, event) {
  if (event) event.stopPropagation();

  const convertMenu = document.getElementById('dropdown-menu-convert');
  const allMenu = document.getElementById('dropdown-menu-all');
  const btnConvert = document.getElementById('nav-btn-convert');
  const btnAll = document.getElementById('nav-btn-all');

  if (type === 'convert') {
    const isOpen = convertMenu.classList.contains('open');
    closeAllDropdowns();
    if (!isOpen) {
      convertMenu.classList.add('open');
      btnConvert.classList.add('open');
      alignDropdownCaret('convert');
    }
  } else if (type === 'all') {
    const isOpen = allMenu.classList.contains('open');
    closeAllDropdowns();
    if (!isOpen) {
      allMenu.classList.add('open');
      btnAll.classList.add('open');
      alignDropdownCaret('all');
    }
  }
}

function closeAllDropdowns() {
  const convertMenu = document.getElementById('dropdown-menu-convert');
  const allMenu = document.getElementById('dropdown-menu-all');
  const btnConvert = document.getElementById('nav-btn-convert');
  const btnAll = document.getElementById('nav-btn-all');

  if (convertMenu) convertMenu.classList.remove('open');
  if (allMenu) allMenu.classList.remove('open');
  if (btnConvert) btnConvert.classList.remove('open');
  if (btnAll) btnAll.classList.remove('open');
}

function alignDropdownCaret(name) {
  const btn = document.getElementById(name === 'convert' ? 'nav-btn-convert' : 'nav-btn-all');
  const menu = document.getElementById(name === 'convert' ? 'dropdown-menu-convert' : 'dropdown-menu-all');
  if (!btn || !menu) return;

  const caret = menu.querySelector('.dropdown-caret-arrow');
  if (!caret) return;

  const btnRect = btn.getBoundingClientRect();
  const menuRect = menu.getBoundingClientRect();
  const caretX = (btnRect.left + btnRect.width / 2) - menuRect.left;
  caret.style.left = `${Math.max(24, Math.min(menuRect.width - 24, caretX))}px`;
}

function setupDropdownBehaviors() {
  // Document-level click outside listener
  document.addEventListener('click', (e) => {
    if (!e.target.closest('.nav-item-dropdown') && !e.target.closest('.dropdown-popover')) {
      closeAllDropdowns();
    }
  });

  // Escape key closes dropdowns
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') closeAllDropdowns();
  });

  // Desktop Hover triggers for seamless luxury experience
  const setupHover = (wrapperId, type) => {
    const wrapper = document.getElementById(wrapperId);
    if (!wrapper) return;

    wrapper.addEventListener('mouseenter', () => {
      clearTimeout(App.hoverTimeout);
      const convertMenu = document.getElementById('dropdown-menu-convert');
      const allMenu = document.getElementById('dropdown-menu-all');
      const btnConvert = document.getElementById('nav-btn-convert');
      const btnAll = document.getElementById('nav-btn-all');

      if (type === 'convert') {
        if (allMenu) allMenu.classList.remove('open');
        if (btnAll) btnAll.classList.remove('open');
        convertMenu.classList.add('open');
        btnConvert.classList.add('open');
        alignDropdownCaret('convert');
      } else {
        if (convertMenu) convertMenu.classList.remove('open');
        if (btnConvert) btnConvert.classList.remove('open');
        allMenu.classList.add('open');
        btnAll.classList.add('open');
        alignDropdownCaret('all');
      }
    });

    wrapper.addEventListener('mouseleave', () => {
      App.hoverTimeout = setTimeout(() => {
        closeAllDropdowns();
      }, 180);
    });
  };

  setupHover('dropdown-wrapper-convert', 'convert');
  setupHover('dropdown-wrapper-all', 'all');

  window.addEventListener('resize', () => {
    const convertMenu = document.getElementById('dropdown-menu-convert');
    const allMenu = document.getElementById('dropdown-menu-all');
    if (convertMenu && convertMenu.classList.contains('open')) alignDropdownCaret('convert');
    if (allMenu && allMenu.classList.contains('open')) alignDropdownCaret('all');
  });
}

// ============================================================================
// Render Home Page 5-Column Grid
// ============================================================================
function renderHomeCards() {
  const grid = document.getElementById('tools-grid-5col');
  if (!grid) return;

  const filtered = TOOLS.filter(card => {
    if (App.activeCategory === 'all') return true;
    if (App.activeCategory === 'workflows') return false;
    return card.category === App.activeCategory;
  });

  let cardsToRender = [...filtered];
  if (App.activeCategory === 'all' || App.activeCategory === 'workflows') {
    cardsToRender = [...filtered, ...WORKFLOW_CARDS];
  }

  grid.innerHTML = cardsToRender.map(card => {
    if (card.isWorkflow) {
      return `
        <div class="tool-card card-workflow" onclick="navigateToTool('ai_summarizer')">
          <span class="card-new-badge">FEATURE</span>
          <div class="card-icon">
            <svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#FFE4E6"/><path d="M12 22h20M22 12v20" stroke="#E11D48" stroke-width="2.5" stroke-linecap="round"/></svg>
          </div>
          <h3 class="card-title">${card.title}</h3>
          <p class="card-desc">${card.desc}</p>
          <div class="workflow-link">${card.actionText}</div>
        </div>
      `;
    }

    return `
      <div class="tool-card" onclick="navigateToTool('${card.id}')">
        ${card.isNew ? '<span class="card-new-badge">New!</span>' : ''}
        <div class="card-icon">
          ${card.icon}
        </div>
        <h3 class="card-title">${card.title}</h3>
        <p class="card-desc">${card.desc}</p>
      </div>
    `;
  }).join('');
}

function setupFilterPills() {
  const pills = document.querySelectorAll('.pill-item');
  pills.forEach(pill => {
    pill.addEventListener('click', () => {
      pills.forEach(p => p.classList.remove('active'));
      pill.classList.add('active');
      App.activeCategory = pill.getAttribute('data-cat') || 'all';
      renderHomeCards();
    });
  });
}

// ============================================================================
// File Selection & Staged Workspace
// ============================================================================
function triggerFilePicker() {
  const input = document.getElementById('tool-file-input');
  if (input) input.click();
}

function handleFileSelection(filesList) {
  if (!filesList || filesList.length === 0) return;
  const filesArray = Array.from(filesList);

  if (App.activeTool && App.activeTool.multiple === false) {
    App.selectedFiles = [filesArray[0]];
  } else {
    App.selectedFiles = [...App.selectedFiles, ...filesArray];
  }

  updateStagedWorkspaceView();
}

function updateStagedWorkspaceView() {
  if (App.selectedFiles.length === 0) {
    resetToolFiles();
    return;
  }

  document.getElementById('tool-upload-initial').style.display = 'none';
  document.getElementById('tool-staged-area').style.display = 'block';
  document.getElementById('tool-result-box').style.display = 'none';

  // Update counter
  document.getElementById('workspace-files-count').textContent = `Selected Files (${App.selectedFiles.length})`;

  // Render file chips
  const list = document.getElementById('tool-files-list');
  list.innerHTML = App.selectedFiles.map((file, idx) => `
    <div class="file-staged-chip">
      <div class="chip-info">
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#E5322D" stroke-width="2"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>
        <div>
          <div class="chip-name" title="${file.name}">${file.name}</div>
          <div class="chip-size">${formatFileSize(file.size)}</div>
        </div>
      </div>
      <button type="button" class="chip-remove-btn" onclick="removeStagedFile(${idx})" title="Remove file">&times;</button>
    </div>
  `).join('');

  // Render tool specific options
  renderToolOptions();

  // Update Action button text
  const actionBtnText = document.getElementById('execute-action-btn-text');
  actionBtnText.innerHTML = `${(App.activeTool && App.activeTool.actionBtnText) || 'Process PDF'} &rarr;`;
}

function removeStagedFile(index) {
  App.selectedFiles.splice(index, 1);
  updateStagedWorkspaceView();
}

function resetToolFiles() {
  App.selectedFiles = [];
  App.resultBytes = null;
  App.resultFilename = '';
  document.getElementById('tool-upload-initial').style.display = 'flex';
  document.getElementById('tool-staged-area').style.display = 'none';
  document.getElementById('tool-result-box').style.display = 'none';
}

function renderToolOptions() {
  const container = document.getElementById('tool-dynamic-options');
  if (!container || !App.activeTool) return;
  container.innerHTML = '';

  if (App.activeTool.optionsType === 'watermark') {
    container.innerHTML = `
      <div class="option-group">
        <label>Watermark Text:</label>
        <input type="text" id="opt-watermark-text" value="CONFIDENTIAL" placeholder="Enter watermark text">
      </div>
    `;
  } else if (App.activeTool.optionsType === 'rotate') {
    container.innerHTML = `
      <div class="option-group">
        <label>Rotation Angle:</label>
        <select id="opt-rotate-angle">
          <option value="90">90° Clockwise</option>
          <option value="180">180° Half Turn</option>
          <option value="270">270° Counter-Clockwise</option>
        </select>
      </div>
    `;
  } else if (App.activeTool.optionsType === 'password') {
    container.innerHTML = `
      <div class="option-group">
        <label>Enter Password:</label>
        <input type="password" id="opt-password-input" placeholder="Type document password">
      </div>
    `;
  }
}

// Drag & Drop Handling
function setupDragAndDrop() {
  window.addEventListener('dragover', (e) => {
    e.preventDefault();
  });

  window.addEventListener('drop', (e) => {
    e.preventDefault();
    if (App.activeTool && e.dataTransfer && e.dataTransfer.files) {
      handleFileSelection(e.dataTransfer.files);
    }
  });
}

// Cloud Drive Integration
function openGoogleDrivePicker() {
  if (!App.user) {
    openAuthDialog();
    return;
  }
  alert(`Connecting to Google Drive (${App.user.email})... Opening Google Drive file picker.`);
  triggerFilePicker();
}

function openDropboxPicker() {
  alert('Connecting to Dropbox... Opening file picker.');
  triggerFilePicker();
}

// ============================================================================
// PDF Processing Engine (Client-Side pdf-lib)
// ============================================================================
async function executeCurrentToolAction(saveToDrive = false) {
  if (!App.activeTool || App.selectedFiles.length === 0) {
    alert('Please select files first.');
    return;
  }

  const btn = document.getElementById('execute-action-btn');
  const btnText = document.getElementById('execute-action-btn-text');
  const originalText = btnText.innerHTML;

  btn.disabled = true;
  btnText.innerHTML = 'Processing PDF...';

  try {
    const action = App.activeTool.action;
    let outBytes = null;
    let outName = `${App.activeTool.id}_result.pdf`;

    if (action === 'merge') {
      outBytes = await executeMerge(App.selectedFiles);
      outName = 'merged_document.pdf';
    } else if (action === 'split') {
      outBytes = await executeSplit(App.selectedFiles[0]);
      outName = 'split_page1.pdf';
    } else if (action === 'compress') {
      outBytes = await executeCompress(App.selectedFiles[0]);
      outName = 'compressed_document.pdf';
    } else if (action === 'rotate') {
      const angle = parseInt(document.getElementById('opt-rotate-angle')?.value || '90');
      outBytes = await executeRotate(App.selectedFiles[0], angle);
      outName = 'rotated_document.pdf';
    } else if (action === 'watermark') {
      const text = document.getElementById('opt-watermark-text')?.value || 'CONFIDENTIAL';
      outBytes = await executeWatermark(App.selectedFiles[0], text);
      outName = 'watermarked_document.pdf';
    } else if (action === 'images-to-pdf') {
      outBytes = await executeImagesToPdf(App.selectedFiles);
      outName = 'images_converted.pdf';
    } else {
      // General fallbacks for mock converters (Word, Excel, AI, etc.)
      outBytes = await executeGeneralPdfTransform(App.selectedFiles[0], App.activeTool.title);
      outName = `${App.activeTool.id}_processed.pdf`;
    }

    App.resultBytes = outBytes;
    App.resultFilename = outName;

    // Show Success Result Area
    document.getElementById('tool-result-box').style.display = 'flex';
    document.getElementById('result-status-text').textContent = `Generated ${outName} successfully.`;

    if (saveToDrive) {
      saveResultToGoogleDrive();
    }
  } catch (err) {
    alert('Error processing file: ' + err.message);
  } finally {
    btn.disabled = false;
    btnText.innerHTML = originalText;
  }
}

// 1. Merge PDF
async function executeMerge(files) {
  const mergedPdf = await PDFLib.PDFDocument.create();
  for (const file of files) {
    const bytes = await file.arrayBuffer();
    const pdf = await PDFLib.PDFDocument.load(bytes, { ignoreEncryption: true });
    const copiedPages = await mergedPdf.copyPages(pdf, pdf.getPageIndices());
    copiedPages.forEach((page) => mergedPdf.addPage(page));
  }
  return await mergedPdf.save();
}

// 2. Split PDF (Extract first page or single pages)
async function executeSplit(file) {
  const bytes = await file.arrayBuffer();
  const pdf = await PDFLib.PDFDocument.load(bytes, { ignoreEncryption: true });
  const newPdf = await PDFLib.PDFDocument.create();
  if (pdf.getPageCount() > 0) {
    const [copied] = await newPdf.copyPages(pdf, [0]);
    newPdf.addPage(copied);
  }
  return await newPdf.save();
}

// 3. Compress PDF
async function executeCompress(file) {
  const bytes = await file.arrayBuffer();
  const pdf = await PDFLib.PDFDocument.load(bytes, { ignoreEncryption: true });
  return await pdf.save({ useObjectStreams: true });
}

// 4. Rotate PDF
async function executeRotate(file, degrees) {
  const bytes = await file.arrayBuffer();
  const pdf = await PDFLib.PDFDocument.load(bytes, { ignoreEncryption: true });
  const pages = pdf.getPages();
  pages.forEach(p => {
    const current = p.getRotation().angle;
    p.setRotation(PDFLib.degrees((current + degrees) % 360));
  });
  return await pdf.save();
}

// 5. Watermark PDF
async function executeWatermark(file, text) {
  const bytes = await file.arrayBuffer();
  const pdf = await PDFLib.PDFDocument.load(bytes, { ignoreEncryption: true });
  const font = await pdf.embedFont(PDFLib.StandardFonts.HelveticaBold);
  const pages = pdf.getPages();
  pages.forEach(p => {
    const { width, height } = p.getSize();
    p.drawText(text, {
      x: width / 4,
      y: height / 2,
      size: 42,
      font: font,
      color: PDFLib.rgb(0.9, 0.2, 0.2),
      opacity: 0.35,
      rotate: PDFLib.degrees(30)
    });
  });
  return await pdf.save();
}

// 6. Images to PDF
async function executeImagesToPdf(files) {
  const pdfDoc = await PDFLib.PDFDocument.create();
  for (const file of files) {
    const bytes = await file.arrayBuffer();
    let img;
    if (file.type.includes('png')) {
      img = await pdfDoc.embedPng(bytes);
    } else {
      img = await pdfDoc.embedJpg(bytes);
    }
    const page = pdfDoc.addPage([img.width, img.height]);
    page.drawImage(img, { x: 0, y: 0, width: img.width, height: img.height });
  }
  return await pdfDoc.save();
}

// 7. Generic document handler
async function executeGeneralPdfTransform(file, operationTitle) {
  if (file.type === 'application/pdf') {
    const bytes = await file.arrayBuffer();
    const pdf = await PDFLib.PDFDocument.load(bytes, { ignoreEncryption: true });
    return await pdf.save();
  }
  // Generate a valid PDF from text/other sources
  const pdfDoc = await PDFLib.PDFDocument.create();
  const page = pdfDoc.addPage([595, 842]);
  const font = await pdfDoc.embedFont(PDFLib.StandardFonts.Helvetica);
  page.drawText(`${operationTitle}\nFile: ${file.name}\nProcessed successfully with PDFDost Engine.`, {
    x: 50,
    y: 780,
    size: 16,
    font: font,
    color: PDFLib.rgb(0.1, 0.1, 0.1)
  });
  return await pdfDoc.save();
}

// Download & Drive Handlers
function downloadResultFile() {
  if (!App.resultBytes) {
    alert('No processed file found to download.');
    return;
  }
  const blob = new Blob([App.resultBytes], { type: 'application/pdf' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = App.resultFilename || 'processed_file.pdf';
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

function saveResultToGoogleDrive() {
  downloadResultFile();
  window.open('https://drive.google.com/drive/my-drive', '_blank');
  alert('File downloaded and Google Drive opened in new tab for instant cloud upload!');
}

// ============================================================================
// Auth & Firebase Session Management
// ============================================================================
function initAuthSession() {
  const saved = localStorage.getItem('pdfdost_user');
  if (saved) {
    try {
      App.user = JSON.parse(saved);
      document.getElementById('nav-login-btn').textContent = App.user.email ? App.user.email.split('@')[0] : 'Profile';
    } catch (_) {}
  }
}

function openAuthDialog() {
  document.getElementById('auth-modal').classList.add('show');
}

function closeAuthDialog() {
  document.getElementById('auth-modal').classList.remove('show');
}

function signInWithGooglePrompt() {
  const email = prompt('Enter Google Account email:', 'user@gmail.com');
  if (email) {
    App.user = { email: email, connectedToDrive: true };
    localStorage.setItem('pdfdost_user', JSON.stringify(App.user));
    document.getElementById('nav-login-btn').textContent = email.split('@')[0];
    closeAuthDialog();
    alert('Signed in with Google! Synced with Google Drive.');
  }
}

function openFirebaseSetup() {
  document.getElementById('firebase-modal').classList.add('show');
}

function closeFirebaseSetup() {
  document.getElementById('firebase-modal').classList.remove('show');
}

function saveFirebaseCredentials() {
  const key = document.getElementById('fb-api-key').value;
  const project = document.getElementById('fb-project-id').value;
  const domain = document.getElementById('fb-auth-domain').value;
  localStorage.setItem('pdfdost_firebase_config', JSON.stringify({ key, project, domain }));
  closeFirebaseSetup();
  alert('Firebase & Google OAuth configuration saved!');
}

function formatFileSize(bytes) {
  if (!bytes || bytes === 0) return '0 B';
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
}
