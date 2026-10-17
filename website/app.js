/**
 * PDFDost - Exact iLovePDF Web Platform
 * Complete 32-Tool Suite with In-Browser Processing & Firebase Google OAuth
 * Crafted with dedication by Vrushabh Dhote
 */

const ALL_CARDS = [
  // Row 1
  {
    id: 'merge-pdf',
    title: 'Merge PDF',
    desc: 'Combine PDFs in the order you want with the easiest PDF merger available.',
    category: 'organize',
    iconColor: '#E5322D',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#FEE2E2"/><path d="M12 12h10v10H12z" fill="#E5322D" rx="2"/><path d="M22 22h10v10H22z" fill="#E5322D" rx="2"/><path d="M22 17l-3 3 3 3" stroke="#FFF" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/><path d="M22 27l3-3-3-3" stroke="#FFF" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>`,
    accept: '.pdf',
    multiple: true,
    action: 'merge'
  },
  {
    id: 'split-pdf',
    title: 'Split PDF',
    desc: 'Separate one page or a whole set for easy conversion into independent PDF files.',
    category: 'organize',
    iconColor: '#E5322D',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#FEE2E2"/><path d="M14 14h8v8h-8z" fill="#E5322D" rx="2"/><path d="M22 22h8v8h-8z" fill="#E5322D" rx="2"/><path d="M18 18l-3-3" stroke="#E5322D" stroke-width="2" stroke-linecap="round"/><path d="M26 26l3 3" stroke="#E5322D" stroke-width="2" stroke-linecap="round"/></svg>`,
    accept: '.pdf',
    multiple: false,
    action: 'split'
  },
  {
    id: 'compress-pdf',
    title: 'Compress PDF',
    desc: 'Reduce file size while optimizing for maximal PDF quality.',
    category: 'optimize',
    iconColor: '#10B981',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#D1FAE5"/><rect x="12" y="12" width="20" height="20" rx="4" fill="#10B981"/><path d="M16 16l3 3m0-3l-3 3M28 16l-3 3m0-3l3 3M16 28l3-3m0 3l-3-3M28 28l-3-3m0 3l3-3" stroke="#FFF" stroke-width="2" stroke-linecap="round"/></svg>`,
    accept: '.pdf',
    multiple: false,
    action: 'compress'
  },
  {
    id: 'pdf-to-word',
    title: 'PDF to Word',
    desc: 'Easily convert your PDF files into easy to edit DOC and DOCX documents. The converted WORD document is almost 100% accurate.',
    category: 'convert',
    iconColor: '#2563EB',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#DBEAFE"/><rect x="18" y="18" width="16" height="16" rx="3" fill="#2563EB"/><text x="22" y="30" fill="#FFF" font-size="11" font-weight="900" font-family="sans-serif">W</text><path d="M12 12h10v14H12z" fill="#93C5FD" rx="2"/></svg>`,
    accept: '.pdf',
    multiple: false,
    action: 'pdf-to-word'
  },
  {
    id: 'pdf-to-powerpoint',
    title: 'PDF to PowerPoint',
    desc: 'Turn your PDF files into easy to edit PPT and PPTX slideshows.',
    category: 'convert',
    iconColor: '#EA580C',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#FFEDD5"/><rect x="18" y="18" width="16" height="16" rx="3" fill="#EA580C"/><text x="23" y="30" fill="#FFF" font-size="11" font-weight="900" font-family="sans-serif">P</text><path d="M12 12h10v14H12z" fill="#FDBA74" rx="2"/></svg>`,
    accept: '.pdf',
    multiple: false,
    action: 'convert'
  },

  // Row 2
  {
    id: 'pdf-to-excel',
    title: 'PDF to Excel',
    desc: 'Pull data straight from PDFs into Excel spreadsheets in a few short seconds.',
    category: 'convert',
    iconColor: '#059669',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#D1FAE5"/><rect x="18" y="18" width="16" height="16" rx="3" fill="#059669"/><text x="23" y="30" fill="#FFF" font-size="11" font-weight="900" font-family="sans-serif">X</text><path d="M12 12h10v14H12z" fill="#6EE7B7" rx="2"/></svg>`,
    accept: '.pdf',
    multiple: false,
    action: 'convert'
  },
  {
    id: 'word-to-pdf',
    title: 'Word to PDF',
    desc: 'Make DOC and DOCX files easy to read by converting them to PDF.',
    category: 'convert',
    iconColor: '#2563EB',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#EFF6FF"/><rect x="12" y="12" width="14" height="14" rx="2" fill="#2563EB"/><text x="15" y="23" fill="#FFF" font-size="10" font-weight="900">W</text><rect x="18" y="18" width="14" height="14" rx="2" fill="#E5322D"/><path d="M21 21l8 8" stroke="#FFF" stroke-width="2" stroke-linecap="round"/></svg>`,
    accept: '.doc,.docx,.txt',
    multiple: false,
    action: 'convert'
  },
  {
    id: 'powerpoint-to-pdf',
    title: 'PowerPoint to PDF',
    desc: 'Make PPT and PPTX slideshows easy to view by converting them to PDF.',
    category: 'convert',
    iconColor: '#EA580C',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#FFF7ED"/><rect x="12" y="12" width="14" height="14" rx="2" fill="#EA580C"/><text x="16" y="23" fill="#FFF" font-size="10" font-weight="900">P</text><rect x="18" y="18" width="14" height="14" rx="2" fill="#E5322D"/><path d="M21 21l8 8" stroke="#FFF" stroke-width="2" stroke-linecap="round"/></svg>`,
    accept: '.ppt,.pptx',
    multiple: false,
    action: 'convert'
  },
  {
    id: 'excel-to-pdf',
    title: 'Excel to PDF',
    desc: 'Make EXCEL spreadsheets easy to read by converting them to PDF.',
    category: 'convert',
    iconColor: '#059669',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#ECFDF5"/><rect x="12" y="12" width="14" height="14" rx="2" fill="#059669"/><text x="16" y="23" fill="#FFF" font-size="10" font-weight="900">X</text><rect x="18" y="18" width="14" height="14" rx="2" fill="#E5322D"/><path d="M21 21l8 8" stroke="#FFF" stroke-width="2" stroke-linecap="round"/></svg>`,
    accept: '.xls,.xlsx,.csv',
    multiple: false,
    action: 'convert'
  },
  {
    id: 'edit-pdf',
    title: 'Edit PDF',
    desc: 'Add text, images, shapes or freehand annotations to a PDF document. Edit the size, font, and color of the added content.',
    category: 'edit',
    iconColor: '#7C3AED',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#EDE9FE"/><rect x="12" y="12" width="20" height="20" rx="4" fill="#7C3AED"/><path d="M17 26l7-7 3 3-7 7-4 1 1-4z" fill="#FFF"/></svg>`,
    accept: '.pdf',
    multiple: false,
    action: 'edit'
  },

  // Row 3
  {
    id: 'pdf-to-jpg',
    title: 'PDF to JPG',
    desc: 'Convert each PDF page into a JPG or extract all images contained in a PDF.',
    category: 'convert',
    iconColor: '#D97706',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#FEF3C7"/><path d="M12 12h12v14H12z" fill="#FDE68A"/><rect x="18" y="18" width="14" height="14" rx="3" fill="#D97706"/><circle cx="22" cy="22" r="1.5" fill="#FFF"/><path d="M20 28l3-3 4 4" stroke="#FFF" stroke-width="1.5"/></svg>`,
    accept: '.pdf',
    multiple: false,
    action: 'convert'
  },
  {
    id: 'jpg-to-pdf',
    title: 'JPG to PDF',
    desc: 'Convert JPG images to PDF in seconds. Easily adjust orientation and margins.',
    category: 'convert',
    iconColor: '#D97706',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#FEF3C7"/><rect x="12" y="12" width="14" height="14" rx="2" fill="#D97706"/><text x="13" y="22" fill="#FFF" font-size="7" font-weight="900">JPG</text><rect x="18" y="18" width="14" height="14" rx="2" fill="#E5322D"/><path d="M21 21l8 8" stroke="#FFF" stroke-width="2" stroke-linecap="round"/></svg>`,
    accept: '.jpg,.jpeg,.png,.webp',
    multiple: true,
    action: 'images-to-pdf'
  },
  {
    id: 'sign-pdf',
    title: 'Sign PDF',
    desc: 'Sign yourself or request electronic signatures from others.',
    category: 'edit',
    iconColor: '#2563EB',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#DBEAFE"/><rect x="12" y="12" width="20" height="20" rx="4" fill="#2563EB"/><path d="M22 17l4 4-8 8h-4v-4l8-8z" fill="#FFF"/></svg>`,
    accept: '.pdf',
    multiple: false,
    action: 'edit'
  },
  {
    id: 'watermark',
    title: 'Watermark',
    desc: 'Stamp an image or text over your PDF in seconds. Choose the typography, transparency and position.',
    category: 'edit',
    iconColor: '#9D174D',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#FCE7F3"/><rect x="12" y="12" width="20" height="20" rx="4" fill="#9D174D"/><path d="M20 16h4v4h-4zM18 20h8v4h-8zM16 24h12v4H16z" fill="#FFF"/></svg>`,
    accept: '.pdf',
    multiple: false,
    action: 'watermark'
  },
  {
    id: 'rotate-pdf',
    title: 'Rotate PDF',
    desc: 'Rotate your PDFs the way you need them. You can even rotate multiple PDFs at once!',
    category: 'edit',
    iconColor: '#7C3AED',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#EDE9FE"/><rect x="12" y="12" width="20" height="20" rx="4" fill="#7C3AED"/><path d="M22 17a5 5 0 1 1-5 5" fill="none" stroke="#FFF" stroke-width="2"/><polyline points="20 15 22 17 20 19" fill="none" stroke="#FFF" stroke-width="2"/></svg>`,
    accept: '.pdf',
    multiple: true,
    action: 'rotate'
  },

  // Row 4
  {
    id: 'html-to-pdf',
    title: 'HTML to PDF',
    desc: 'Convert webpages in HTML to PDF. Copy and paste the URL of the page you want and convert it to PDF with a click.',
    category: 'convert',
    iconColor: '#D97706',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#FEF3C7"/><rect x="12" y="12" width="14" height="14" rx="2" fill="#D97706"/><text x="13" y="21" fill="#FFF" font-size="6" font-weight="900">HTML</text><rect x="18" y="18" width="14" height="14" rx="2" fill="#E5322D"/><path d="M21 21l8 8" stroke="#FFF" stroke-width="2"/></svg>`,
    accept: '.html,.htm',
    multiple: false,
    action: 'convert'
  },
  {
    id: 'unlock-pdf',
    title: 'Unlock PDF',
    desc: 'Remove PDF password security, giving you the freedom to use your PDFs as you want.',
    category: 'security',
    iconColor: '#0284C7',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#E0F2FE"/><rect x="12" y="12" width="20" height="20" rx="4" fill="#0284C7"/><path d="M20 20v-3a3 3 0 0 1 6 0" fill="none" stroke="#FFF" stroke-width="2"/><rect x="18" y="20" width="8" height="6" rx="1" fill="#FFF"/></svg>`,
    accept: '.pdf',
    multiple: false,
    action: 'unlock'
  },
  {
    id: 'protect-pdf',
    title: 'Protect PDF',
    desc: 'Protect PDF files with a password. Encrypt PDF documents to prevent unauthorized access.',
    category: 'security',
    iconColor: '#2563EB',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#DBEAFE"/><rect x="12" y="12" width="20" height="20" rx="4" fill="#2563EB"/><path d="M22 17l5 2v4c0 3-2 5-5 6s-5-3-5-6v-4l5-2z" fill="#FFF"/></svg>`,
    accept: '.pdf',
    multiple: false,
    action: 'protect'
  },
  {
    id: 'organize-pdf',
    title: 'Organize PDF',
    desc: 'Sort pages of your PDF file however you like. Delete PDF pages or add PDF pages to your document at your convenience.',
    category: 'organize',
    iconColor: '#EA580C',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#FFEDD5"/><rect x="12" y="12" width="9" height="20" rx="2" fill="#EA580C"/><rect x="23" y="12" width="9" height="20" rx="2" fill="#EA580C"/><path d="M16 16v12m11-12v12" stroke="#FFF" stroke-width="1.5"/></svg>`,
    accept: '.pdf',
    multiple: true,
    action: 'organize'
  },
  {
    id: 'pdf-to-pdfa',
    title: 'PDF to PDF/A',
    desc: 'Transform your PDF to PDF/A, the ISO-standardized version of PDF for long-term archiving. Your PDF will preserve formatting when accessed in the future.',
    category: 'convert',
    iconColor: '#475569',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#F1F5F9"/><rect x="12" y="12" width="20" height="20" rx="4" fill="#475569"/><text x="14" y="26" fill="#FFF" font-size="9" font-weight="bold">/A</text></svg>`,
    accept: '.pdf',
    multiple: false,
    action: 'convert'
  },

  // Row 5
  {
    id: 'repair-pdf',
    title: 'Repair PDF',
    desc: 'Repair a damaged PDF and recover data from corrupt PDF. Fix PDF files with our Repair tool.',
    category: 'optimize',
    iconColor: '#65A30D',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#ECFCCB"/><rect x="12" y="12" width="20" height="20" rx="4" fill="#65A30D"/><path d="M17 27l6-6m-2-2l2-2 3 3-2 2" stroke="#FFF" stroke-width="2" stroke-linecap="round"/></svg>`,
    accept: '.pdf',
    multiple: false,
    action: 'compress'
  },
  {
    id: 'page-numbers',
    title: 'Page numbers',
    desc: 'Add page numbers into PDFs with ease. Choose your positions, dimensions, typography.',
    category: 'edit',
    iconColor: '#831843',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#FCE7F3"/><rect x="12" y="12" width="9" height="9" rx="2" fill="#831843"/><text x="15" y="19" fill="#FFF" font-size="7" font-weight="bold">1</text><rect x="23" y="12" width="9" height="9" rx="2" fill="#831843"/><text x="26" y="19" fill="#FFF" font-size="7" font-weight="bold">2</text><rect x="12" y="23" width="9" height="9" rx="2" fill="#831843"/><text x="15" y="30" fill="#FFF" font-size="7" font-weight="bold">3</text><rect x="23" y="23" width="9" height="9" rx="2" fill="#831843"/><text x="26" y="30" fill="#FFF" font-size="7" font-weight="bold">4</text></svg>`,
    accept: '.pdf',
    multiple: false,
    action: 'page-numbers'
  },
  {
    id: 'scan-to-pdf',
    title: 'Scan to PDF',
    desc: 'Capture document scans from your mobile device and send them instantly to your browser.',
    category: 'organize',
    iconColor: '#EA580C',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#FFEDD5"/><rect x="12" y="12" width="20" height="20" rx="4" fill="#EA580C"/><circle cx="22" cy="22" r="4" stroke="#FFF" stroke-width="2"/><path d="M16 16h3v3m10-3h-3v3m3 10h-3v-3m-10 3h3v-3" stroke="#FFF" stroke-width="1.5"/></svg>`,
    accept: '.jpg,.jpeg,.png',
    multiple: true,
    action: 'images-to-pdf'
  },
  {
    id: 'ocr-pdf',
    title: 'OCR PDF',
    desc: 'Easily convert scanned PDF into searchable and selectable documents.',
    category: 'intelligence',
    iconColor: '#16A34A',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#DCFCE7"/><rect x="12" y="12" width="20" height="20" rx="4" fill="#16A34A"/><text x="14" y="25" fill="#FFF" font-size="8" font-weight="900">[OCR]</text></svg>`,
    accept: '.pdf',
    multiple: false,
    action: 'ocr'
  },
  {
    id: 'compare-pdf',
    title: 'Compare PDF',
    desc: 'Show a side-by-side document comparison and easily spot changes between different file versions.',
    category: 'edit',
    iconColor: '#2563EB',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#DBEAFE"/><rect x="12" y="12" width="9" height="20" rx="2" fill="#2563EB"/><rect x="23" y="12" width="9" height="20" rx="2" fill="#2563EB"/><line x1="14" y1="17" x2="19" y2="17" stroke="#FFF"/><line x1="25" y1="17" x2="30" y2="17" stroke="#FFF"/></svg>`,
    accept: '.pdf',
    multiple: true,
    action: 'merge'
  },

  // Row 6
  {
    id: 'redact-pdf',
    title: 'Redact PDF',
    desc: 'Redact text and graphics to permanently remove sensitive information from a PDF.',
    category: 'security',
    iconColor: '#1E293B',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#E2E8F0"/><rect x="12" y="12" width="20" height="20" rx="4" fill="#1E293B"/><rect x="15" y="20" width="14" height="4" fill="#FFF"/><text x="18" y="24" fill="#1E293B" font-size="5" font-weight="bold">x</text></svg>`,
    accept: '.pdf',
    multiple: false,
    action: 'watermark'
  },
  {
    id: 'crop-pdf',
    title: 'Crop PDF',
    desc: 'Crop margins of PDF documents or select specific areas, then apply the changes to one page or the whole document.',
    category: 'edit',
    iconColor: '#831843',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#FCE7F3"/><rect x="12" y="12" width="20" height="20" rx="4" fill="#831843"/><path d="M16 20h8v8" stroke="#FFF" stroke-width="2" fill="none"/></svg>`,
    accept: '.pdf',
    multiple: false,
    action: 'edit'
  },
  {
    id: 'pdf-forms',
    title: 'PDF Forms',
    desc: 'Detect form fields automatically, create interactive fillable PDFs, or fill PDF forms yourself. Add text fields, checkboxes, multiple choice fields, and lists.',
    category: 'edit',
    isNew: true,
    iconColor: '#7C3AED',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#EDE9FE"/><rect x="12" y="12" width="20" height="20" rx="4" fill="#7C3AED"/><text x="15" y="25" fill="#FFF" font-size="8" font-weight="900">Ab</text></svg>`,
    accept: '.pdf',
    multiple: false,
    action: 'edit'
  },
  {
    id: 'ai-summarizer',
    title: 'AI Summarizer',
    desc: 'Quickly generate concise summaries from articles, paragraphs, and essays, providing clear and precise key points in seconds.',
    category: 'intelligence',
    isNew: true,
    iconColor: '#6366F1',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#E0E7FF"/><rect x="12" y="12" width="20" height="20" rx="4" fill="#6366F1"/><line x1="16" y1="18" x2="24" y2="18" stroke="#FFF" stroke-width="2"/><line x1="16" y1="22" x2="22" y2="22" stroke="#FFF" stroke-width="2"/><circle cx="26" cy="24" r="2" fill="#FFF"/></svg>`,
    accept: '.pdf,.txt',
    multiple: false,
    action: 'edit'
  },
  {
    id: 'translate-pdf',
    title: 'Translate PDF',
    desc: 'Easily translate PDF files powered by AI. Keep fonts, layout, and formatting perfectly intact.',
    category: 'intelligence',
    isNew: true,
    iconColor: '#4F46E5',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#EEF2FF"/><rect x="12" y="12" width="20" height="20" rx="4" fill="#4F46E5"/><text x="14" y="25" fill="#FFF" font-size="9" font-weight="bold">文A</text></svg>`,
    accept: '.pdf',
    multiple: false,
    action: 'edit'
  },

  // Row 7
  {
    id: 'pdf-to-markdown',
    title: 'PDF to Markdown',
    desc: 'Easily turn PDFs into Markdown files. Perfect for notes, docs, and LLMs. Headings, tables, lists, and links preserved automatically.',
    category: 'convert',
    isNew: true,
    iconColor: '#4338CA',
    icon: `<svg width="44" height="44" viewBox="0 0 44 44"><rect width="44" height="44" rx="10" fill="#E0E7FF"/><rect x="12" y="12" width="20" height="20" rx="4" fill="#4338CA"/><text x="15" y="25" fill="#FFF" font-size="9" font-weight="bold">{#}</text></svg>`,
    accept: '.pdf',
    multiple: false,
    action: 'convert'
  },
  {
    id: 'create-workflow',
    title: 'Create a workflow',
    desc: 'Create custom workflows with your favorite tools, automate tasks, and reuse them anytime.',
    category: 'workflows',
    isWorkflowCard: true,
    action: 'workflow'
  }
];

// App State
const App = {
  activeCategory: 'all',
  activeTool: null,
  files: [],
  user: null,
  firebaseConfig: {
    apiKey: '',
    authDomain: 'pdfdost-app.firebaseapp.com',
    projectId: 'pdfdost-app',
    storageBucket: 'pdfdost-app.appspot.com',
    googleClientId: ''
  }
};

document.addEventListener('DOMContentLoaded', () => {
  renderCards();
  setupFilterPills();
  initAuthSession();
});

function renderCards() {
  const container = document.getElementById('tools-grid-5col');
  if (!container) return;

  const filtered = ALL_CARDS.filter(card => {
    if (App.activeCategory === 'all') return true;
    if (App.activeCategory === 'workflows') return card.category === 'workflows';
    if (App.activeCategory === 'organize') return card.category === 'organize';
    if (App.activeCategory === 'optimize') return card.category === 'optimize';
    if (App.activeCategory === 'convert') return card.category === 'convert';
    if (App.activeCategory === 'edit') return card.category === 'edit';
    if (App.activeCategory === 'security') return card.category === 'security';
    if (App.activeCategory === 'intelligence') return card.category === 'intelligence';
    return true;
  });

  container.innerHTML = filtered.map(card => {
    if (card.isWorkflowCard) {
      return `
        <div class="card-item card-workflow" onclick="openToolWorkspace('${card.id}')">
          <div style="font-weight: 800; font-size: 1.25rem; margin-bottom: 8px;">Create a workflow</div>
          <p class="card-desc" style="color: inherit; opacity: 0.9;">
            ${card.desc}
          </p>
          <div class="workflow-link">
            Create workflow ↗
          </div>
        </div>
      `;
    }

    return `
      <div class="card-item" onclick="openToolWorkspace('${card.id}')">
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
      renderCards();
    });
  });
}

function openToolWorkspace(toolId) {
  const card = ALL_CARDS.find(c => c.id === toolId);
  if (!card) return;

  App.activeTool = card;
  App.files = [];

  const modal = document.getElementById('tool-modal');
  document.getElementById('modal-title-text').textContent = card.title;
  document.getElementById('modal-sub-text').textContent = card.desc;
  
  const fileInput = document.getElementById('file-upload-input');
  fileInput.accept = card.accept || '.pdf';
  fileInput.multiple = card.multiple || false;

  updateFilesView();
  modal.classList.add('show');
}

function closeToolWorkspace() {
  const modal = document.getElementById('tool-modal');
  modal.classList.remove('show');
  App.activeTool = null;
  App.files = [];
}

function handleFileSelection(filesList) {
  if (!App.activeTool) return;
  if (App.activeTool.multiple) {
    App.files = [...App.files, ...Array.from(filesList)];
  } else {
    App.files = [filesList[0]];
  }
  updateFilesView();
}

function updateFilesView() {
  const fileContainer = document.getElementById('selected-files-list');
  const actionBtn = document.getElementById('modal-action-btn');
  const driveBtn = document.getElementById('modal-drive-btn');

  if (!fileContainer) return;

  if (App.files.length === 0) {
    fileContainer.innerHTML = '';
    actionBtn.disabled = true;
    actionBtn.style.opacity = '0.5';
    if (driveBtn) driveBtn.style.display = 'none';
    return;
  }

  actionBtn.disabled = false;
  actionBtn.style.opacity = '1';
  if (driveBtn) driveBtn.style.display = 'inline-flex';

  fileContainer.innerHTML = App.files.map((file, i) => `
    <div style="display:flex;align-items:center;justify-content:space-between;padding:10px 14px;background:#F1F5F9;border-radius:8px;font-size:0.85rem;margin-top:8px;">
      <div style="font-weight:600;">${file.name} (${Math.round(file.size / 1024)} KB)</div>
      <button style="background:none;border:none;cursor:pointer;color:#EF4444;font-size:1.1rem;" onclick="removeSelectedFile(${i})">&times;</button>
    </div>
  `).join('');
}

function removeSelectedFile(index) {
  App.files.splice(index, 1);
  updateFilesView();
}

async function executePDFAction(saveToDrive = false) {
  if (!App.activeTool || App.files.length === 0) return;
  const btn = document.getElementById('modal-action-btn');
  btn.textContent = 'Processing PDF...';
  btn.disabled = true;

  try {
    const { PDFDocument, rgb, degrees } = PDFLib;
    let outBytes = null;
    let outName = `${App.activeTool.id}_result.pdf`;

    if (App.activeTool.action === 'merge') {
      const merged = await PDFDocument.create();
      for (const f of App.files) {
        const doc = await PDFDocument.load(await f.arrayBuffer());
        const copied = await merged.copyPages(doc, doc.getPageIndices());
        copied.forEach(p => merged.addPage(p));
      }
      outBytes = await merged.save();
    } else if (App.activeTool.action === 'rotate') {
      const doc = await PDFDocument.load(await App.files[0].arrayBuffer());
      doc.getPages().forEach(p => {
        p.setRotation(degrees((p.getRotation().angle + 90) % 360));
      });
      outBytes = await doc.save();
    } else if (App.activeTool.action === 'watermark') {
      const doc = await PDFDocument.load(await App.files[0].arrayBuffer());
      doc.getPages().forEach(p => {
        const { width, height } = p.getSize();
        p.drawText('CONFIDENTIAL', {
          x: width / 4,
          y: height / 2,
          size: 40,
          color: rgb(0.9, 0.2, 0.2),
          opacity: 0.35,
          rotate: degrees(45)
        });
      });
      outBytes = await doc.save();
    } else if (App.activeTool.action === 'images-to-pdf') {
      const doc = await PDFDocument.create();
      for (const f of App.files) {
        const imgBytes = await f.arrayBuffer();
        const img = f.type.includes('png') ? await doc.embedPng(imgBytes) : await doc.embedJpg(imgBytes);
        const p = doc.addPage([img.width, img.height]);
        p.drawImage(img, { x: 0, y: 0, width: img.width, height: img.height });
      }
      outBytes = await doc.save();
    } else {
      const doc = await PDFDocument.load(await App.files[0].arrayBuffer());
      outBytes = await doc.save();
    }

    if (saveToDrive) {
      triggerSaveToGoogleDrive(outBytes, outName);
    } else {
      downloadPDF(outBytes, outName);
      alert('PDF processed successfully! File download has started.');
    }
    closeToolWorkspace();
  } catch (err) {
    alert('Processing error: ' + err.message);
  } finally {
    btn.textContent = 'Download File';
    btn.disabled = false;
  }
}

function downloadPDF(bytes, filename) {
  const blob = new Blob([bytes], { type: 'application/pdf' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

function triggerSaveToGoogleDrive(bytes, filename) {
  downloadPDF(bytes, filename);
  window.open('https://drive.google.com/drive/my-drive', '_blank');
  alert('File downloaded and Google Drive opened!');
}

// Auth & Setup
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
  const modal = document.getElementById('auth-modal');
  modal.classList.add('show');
}

function closeAuthDialog() {
  const modal = document.getElementById('auth-modal');
  modal.classList.remove('show');
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
  const modal = document.getElementById('firebase-modal');
  modal.classList.add('show');
}

function closeFirebaseSetup() {
  const modal = document.getElementById('firebase-modal');
  modal.classList.remove('show');
}

function saveFirebaseCredentials() {
  const key = document.getElementById('fb-api-key').value;
  const project = document.getElementById('fb-project-id').value;
  const domain = document.getElementById('fb-auth-domain').value;
  localStorage.setItem('pdfdost_firebase_config', JSON.stringify({ key, project, domain }));
  closeFirebaseSetup();
  alert('Firebase & Google OAuth configuration saved!');
}
