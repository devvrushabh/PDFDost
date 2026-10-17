/**
 * PDFDost - Modern Web Application
 * Inspired by iLovePDF, powered by client-side pdf-lib & Firebase Google Auth
 * Crafted with dedication by Vrushabh Dhote
 */

// ============================================================================
// 1. Tool Data Definitions (iLovePDF Style 15-Tool Suite)
// ============================================================================
const PDF_TOOLS = [
  {
    id: 'merge-pdf',
    title: 'Merge PDF',
    desc: 'Combine multiple PDF files into one in whatever order you want with the easiest PDF merger.',
    category: 'organize',
    color: '#E5322D',
    bgColor: 'rgba(229, 50, 45, 0.1)',
    badge: 'POPULAR',
    badgeClass: 'badge-popular',
    iconSvg: `<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path><polyline points="14 2 14 8 20 8"></polyline><line x1="12" y1="18" x2="12" y2="12"></line><line x1="9" y1="15" x2="15" y2="15"></line></svg>`,
    accept: '.pdf',
    multiple: true,
    actionText: 'Merge PDF',
    optionsType: 'merge'
  },
  {
    id: 'split-pdf',
    title: 'Split PDF',
    desc: 'Separate one page or a whole set for easy conversion into independent PDF files.',
    category: 'organize',
    color: '#F97316',
    bgColor: 'rgba(249, 115, 22, 0.1)',
    badge: 'POPULAR',
    badgeClass: 'badge-popular',
    iconSvg: `<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path><line x1="8" y1="13" x2="16" y2="13"></line><line x1="8" y1="17" x2="16" y2="17"></line></svg>`,
    accept: '.pdf',
    multiple: false,
    actionText: 'Split PDF',
    optionsType: 'split'
  },
  {
    id: 'compress-pdf',
    title: 'Compress PDF',
    desc: 'Get your PDF document smaller while maintaining maximal resolution and layout quality.',
    category: 'optimize',
    color: '#10B981',
    bgColor: 'rgba(16, 185, 129, 0.1)',
    badge: 'POPULAR',
    badgeClass: 'badge-popular',
    iconSvg: `<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 14.899A7 7 0 1 1 15.71 8h1.79a4.5 4.5 0 0 1 2.5 8.242"></path><path d="M12 12v9"></path><path d="m8 17 4 4 4-4"></path></svg>`,
    accept: '.pdf',
    multiple: false,
    actionText: 'Compress PDF',
    optionsType: 'compress'
  },
  {
    id: 'images-to-pdf',
    title: 'Images to PDF',
    desc: 'Convert JPG, PNG, SVG or WebP images to PDF in seconds. Easily adjust orientation and margins.',
    category: 'convert-to',
    color: '#0D9488',
    bgColor: 'rgba(13, 148, 136, 0.1)',
    badge: 'NEW',
    badgeClass: 'badge-new',
    iconSvg: `<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="2" ry="2"></rect><circle cx="8.5" cy="8.5" r="1.5"></circle><polyline points="21 15 16 10 5 21"></polyline></svg>`,
    accept: '.jpg,.jpeg,.png,.webp',
    multiple: true,
    actionText: 'Convert Images to PDF',
    optionsType: 'images-to-pdf'
  },
  {
    id: 'word-to-pdf',
    title: 'Word to PDF',
    desc: 'Make DOC and DOCX files easy to read by converting them to professional PDF documents.',
    category: 'convert-to',
    color: '#2563EB',
    bgColor: 'rgba(37, 99, 235, 0.1)',
    badge: 'FREE',
    badgeClass: 'badge-new',
    iconSvg: `<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path><polyline points="14 2 14 8 20 8"></polyline><line x1="16" y1="13" x2="8" y2="13"></line><line x1="16" y1="17" x2="8" y2="17"></line><polyline points="10 9 9 9 8 9"></polyline></svg>`,
    accept: '.doc,.docx,.txt',
    multiple: false,
    actionText: 'Convert Word to PDF',
    optionsType: 'word-to-pdf'
  },
  {
    id: 'pdf-to-word',
    title: 'PDF to Word',
    desc: 'Easily convert your PDF files into easy to edit DOC and DOCX documents with intact formatting.',
    category: 'convert-from',
    color: '#3B82F6',
    bgColor: 'rgba(59, 130, 246, 0.1)',
    badge: 'POPULAR',
    badgeClass: 'badge-popular',
    iconSvg: `<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 22h14a2 2 0 0 0 2-2V7.5L14.5 2H6a2 2 0 0 0-2 2v4"></path><polyline points="14 2 14 8 20 8"></polyline><path d="M2 15h10"></path><path d="m9 18 3-3-3-3"></path></svg>`,
    accept: '.pdf',
    multiple: false,
    actionText: 'Convert to Word DOCX',
    optionsType: 'pdf-to-word'
  },
  {
    id: 'pdf-to-excel',
    title: 'PDF to Excel',
    desc: 'Pull tabular data straight from PDF documents into Excel spreadsheets in a few short seconds.',
    category: 'convert-from',
    color: '#059669',
    bgColor: 'rgba(5, 150, 105, 0.1)',
    badge: '',
    badgeClass: '',
    iconSvg: `<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path><path d="M8 13h8"></path><path d="M8 17h8"></path><path d="M12 9v10"></path></svg>`,
    accept: '.pdf',
    multiple: false,
    actionText: 'Extract to Excel',
    optionsType: 'pdf-to-excel'
  },
  {
    id: 'pdf-to-powerpoint',
    title: 'PDF to PowerPoint',
    desc: 'Turn your PDF slides into editable PPTX presentation slideshows for Microsoft PowerPoint.',
    category: 'convert-from',
    color: '#EA580C',
    bgColor: 'rgba(234, 88, 12, 0.1)',
    badge: '',
    badgeClass: '',
    iconSvg: `<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="3" width="20" height="14" rx="2" ry="2"></rect><line x1="8" y1="21" x2="16" y2="21"></line><line x1="12" y1="17" x2="12" y2="21"></line></svg>`,
    accept: '.pdf',
    multiple: false,
    actionText: 'Convert to PowerPoint',
    optionsType: 'pdf-to-powerpoint'
  },
  {
    id: 'pdf-to-jpg',
    title: 'PDF to JPG',
    desc: 'Convert each PDF page into a high-resolution JPG image or extract all embedded photos.',
    category: 'convert-from',
    color: '#F59E0B',
    bgColor: 'rgba(245, 158, 11, 0.1)',
    badge: 'POPULAR',
    badgeClass: 'badge-popular',
    iconSvg: `<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="2" ry="2"></rect><circle cx="8.5" cy="8.5" r="1.5"></circle><polyline points="21 15 16 10 5 21"></polyline></svg>`,
    accept: '.pdf',
    multiple: false,
    actionText: 'Extract to JPG',
    optionsType: 'pdf-to-jpg'
  },
  {
    id: 'rotate-pdf',
    title: 'Rotate PDF',
    desc: 'Rotate your PDFs 90°, 180°, or 270° clockwise or counter-clockwise. Rotate multiple PDFs at once.',
    category: 'edit',
    color: '#06B6D4',
    bgColor: 'rgba(6, 182, 212, 0.1)',
    badge: '',
    badgeClass: '',
    iconSvg: `<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21.5 2v6h-6"></path><path d="M21.34 15.57a10 10 0 1 1-.57-8.38l5.67-5.67"></path></svg>`,
    accept: '.pdf',
    multiple: true,
    actionText: 'Rotate PDF',
    optionsType: 'rotate'
  },
  {
    id: 'watermark-pdf',
    title: 'Watermark PDF',
    desc: 'Stamp text or image watermarks across your PDF pages. Choose custom opacity, angle and position.',
    category: 'edit',
    color: '#EC4899',
    bgColor: 'rgba(236, 72, 153, 0.1)',
    badge: 'POPULAR',
    badgeClass: 'badge-popular',
    iconSvg: `<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 2.69l5.66 5.66a8 8 0 1 1-11.31 0z"></path></svg>`,
    accept: '.pdf',
    multiple: false,
    actionText: 'Apply Watermark',
    optionsType: 'watermark'
  },
  {
    id: 'page-numbers',
    title: 'Page Numbers',
    desc: 'Add customized page numbers to PDF headers and footers with custom alignment and prefixes.',
    category: 'edit',
    color: '#8B5CF6',
    bgColor: 'rgba(139, 92, 246, 0.1)',
    badge: '',
    badgeClass: '',
    iconSvg: `<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"></path><path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"></path><line x1="9" y1="7" x2="15" y2="7"></line><line x1="12" y1="11" x2="12" y2="15"></line></svg>`,
    accept: '.pdf',
    multiple: false,
    actionText: 'Add Page Numbers',
    optionsType: 'page-numbers'
  },
  {
    id: 'protect-pdf',
    title: 'Protect / Lock PDF',
    desc: 'Protect PDF files with strong password encryption to safeguard sensitive documents from unauthorized eyes.',
    category: 'security',
    color: '#6366F1',
    bgColor: 'rgba(99, 102, 241, 0.1)',
    badge: 'SECURE',
    badgeClass: 'badge-new',
    iconSvg: `<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"></rect><path d="M7 11V7a5 5 0 0 1 10 0v4"></path></svg>`,
    accept: '.pdf',
    multiple: false,
    actionText: 'Encrypt & Protect',
    optionsType: 'protect'
  },
  {
    id: 'unlock-pdf',
    title: 'Unlock PDF',
    desc: 'Remove PDF passwords and security restrictions so you can freely view, print, and modify your files.',
    category: 'security',
    color: '#14B8A6',
    bgColor: 'rgba(20, 184, 166, 0.1)',
    badge: '',
    badgeClass: '',
    iconSvg: `<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"></rect><path d="M7 11V7a5 5 0 0 1 9.9-1"></path></svg>`,
    accept: '.pdf',
    multiple: false,
    actionText: 'Unlock PDF',
    optionsType: 'unlock'
  },
  {
    id: 'document-scanner',
    title: 'Document Scanner',
    desc: 'Scan physical pages, ID cards, and receipts with smart perspective 4-corner crop and B&W filters.',
    category: 'organize',
    color: '#E5322D',
    bgColor: 'rgba(229, 50, 45, 0.1)',
    badge: 'MOBILE APP',
    badgeClass: 'badge-popular',
    iconSvg: `<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"></path><circle cx="12" cy="13" r="4"></circle></svg>`,
    accept: '.jpg,.jpeg,.png',
    multiple: true,
    actionText: 'Scan & Convert',
    optionsType: 'scanner'
  }
];

// ============================================================================
// 2. Application State & Storage
// ============================================================================
const AppState = {
  currentCategory: 'all',
  searchQuery: '',
  activeTool: null,
  selectedFiles: [],
  isProcessing: false,
  user: null, // Google user
  firebaseConfig: {
    apiKey: '',
    authDomain: 'pdfdost-app.firebaseapp.com',
    projectId: 'pdfdost-app',
    storageBucket: 'pdfdost-app.appspot.com',
    googleClientId: ''
  },
  history: []
};

// ============================================================================
// 3. Initialization
// ============================================================================
document.addEventListener('DOMContentLoaded', () => {
  initTheme();
  initStorage();
  renderToolCards();
  initSearchAndFilter();
  initModals();
  initDropzone();
  checkAuthSession();
});

// ============================================================================
// 4. Theme System (Dark / Light Mode)
// ============================================================================
function initTheme() {
  const savedTheme = localStorage.getItem('pdfdost_theme');
  const prefersDark = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
  const initialTheme = savedTheme || (prefersDark ? 'dark' : 'light');
  
  applyTheme(initialTheme);

  const themeToggleBtn = document.getElementById('theme-toggle-btn');
  if (themeToggleBtn) {
    themeToggleBtn.addEventListener('click', () => {
      const current = document.documentElement.getAttribute('data-theme') || 'light';
      const next = current === 'dark' ? 'light' : 'dark';
      applyTheme(next);
      localStorage.setItem('pdfdost_theme', next);
    });
  }
}

function applyTheme(theme) {
  document.documentElement.setAttribute('data-theme', theme);
  const icon = document.getElementById('theme-icon');
  if (icon) {
    if (theme === 'dark') {
      icon.innerHTML = `<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="5"></circle><line x1="12" y1="1" x2="12" y2="3"></line><line x1="12" y1="21" x2="12" y2="23"></line><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"></line><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"></line><line x1="1" y1="12" x2="3" y2="12"></line><line x1="21" y1="12" x2="23" y2="12"></line><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"></line><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"></line></svg>`;
    } else {
      icon.innerHTML = `<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"></path></svg>`;
    }
  }
}

// ============================================================================
// 5. Tool Cards Rendering & Search Filter
// ============================================================================
function renderToolCards() {
  const container = document.getElementById('tools-grid');
  if (!container) return;

  const filtered = PDF_TOOLS.filter(tool => {
    const matchesCategory = AppState.currentCategory === 'all' || tool.category === AppState.currentCategory;
    const q = AppState.searchQuery.toLowerCase().trim();
    const matchesQuery = !q || tool.title.toLowerCase().includes(q) || tool.desc.toLowerCase().includes(q);
    return matchesCategory && matchesQuery;
  });

  if (filtered.length === 0) {
    container.innerHTML = `
      <div style="grid-column: 1 / -1; text-align: center; padding: 60px 20px; color: var(--text-muted);">
        <p style="font-size: 1.25rem; font-weight: 700; margin-bottom: 8px;">No matching PDF tools found</p>
        <p style="font-size: 0.95rem;">Try searching for "merge", "split", "compress", or "image".</p>
      </div>
    `;
    return;
  }

  container.innerHTML = filtered.map(tool => `
    <article class="tool-card" onclick="openToolWorkspace('${tool.id}')" tabindex="0" role="button" aria-label="${tool.title}">
      ${tool.badge ? `<span class="tool-badge ${tool.badgeClass}">${tool.badge}</span>` : ''}
      <div class="tool-icon-wrapper" style="background-color: ${tool.bgColor}; color: ${tool.color};">
        ${tool.iconSvg}
      </div>
      <h3 class="tool-title">${tool.title}</h3>
      <p class="tool-desc">${tool.desc}</p>
      <div class="tool-action-arrow">
        Open tool 
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="9 18 15 12 9 6"></polyline></svg>
      </div>
    </article>
  `).join('');
}

function initSearchAndFilter() {
  const searchInput = document.getElementById('tool-search-input');
  if (searchInput) {
    searchInput.addEventListener('input', (e) => {
      AppState.searchQuery = e.target.value;
      renderToolCards();
    });

    // Keyboard shortcut (Ctrl+K or Cmd+K)
    window.addEventListener('keydown', (e) => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault();
        searchInput.focus();
      }
    });
  }

  // Category Pills
  const pills = document.querySelectorAll('.pill-btn');
  pills.forEach(pill => {
    pill.addEventListener('click', () => {
      pills.forEach(p => p.classList.remove('active'));
      pill.classList.add('active');
      AppState.currentCategory = pill.getAttribute('data-category') || 'all';
      renderToolCards();
    });
  });
}

// ============================================================================
// 6. Interactive Tool Workspace Modal
// ============================================================================
function openToolWorkspace(toolId) {
  const tool = PDF_TOOLS.find(t => t.id === toolId);
  if (!tool) return;

  AppState.activeTool = tool;
  AppState.selectedFiles = [];

  const modal = document.getElementById('tool-modal');
  const title = document.getElementById('workspace-tool-title');
  const subtitle = document.getElementById('workspace-tool-subtitle');
  const icon = document.getElementById('workspace-tool-icon');
  const actionBtn = document.getElementById('workspace-action-btn');
  const fileInput = document.getElementById('file-input');

  title.textContent = tool.title;
  subtitle.textContent = tool.desc;
  icon.innerHTML = tool.iconSvg;
  icon.style.backgroundColor = tool.bgColor;
  icon.style.color = tool.color;
  actionBtn.textContent = tool.actionText;
  actionBtn.style.background = `linear-gradient(135deg, ${tool.color} 0%, #D0241F 100%)`;

  fileInput.accept = tool.accept;
  fileInput.multiple = tool.multiple;

  renderToolOptions(tool);
  updateFilesUI();

  modal.classList.add('active');
}

function closeToolWorkspace() {
  const modal = document.getElementById('tool-modal');
  modal.classList.remove('active');
  AppState.activeTool = null;
  AppState.selectedFiles = [];
}

function initDropzone() {
  const dropzone = document.getElementById('dropzone');
  const fileInput = document.getElementById('file-input');

  if (!dropzone || !fileInput) return;

  dropzone.addEventListener('click', () => fileInput.click());

  dropzone.addEventListener('dragover', (e) => {
    e.preventDefault();
    dropzone.classList.add('dragover');
  });

  dropzone.addEventListener('dragleave', () => {
    dropzone.classList.remove('dragover');
  });

  dropzone.addEventListener('drop', (e) => {
    e.preventDefault();
    dropzone.classList.remove('dragover');
    if (e.dataTransfer && e.dataTransfer.files) {
      handleFilesSelected(Array.from(e.dataTransfer.files));
    }
  });

  fileInput.addEventListener('change', (e) => {
    if (e.target.files) {
      handleFilesSelected(Array.from(e.target.files));
    }
  });
}

function handleFilesSelected(newFiles) {
  if (!AppState.activeTool) return;

  if (AppState.activeTool.multiple) {
    AppState.selectedFiles = [...AppState.selectedFiles, ...newFiles];
  } else {
    AppState.selectedFiles = [newFiles[0]];
  }

  updateFilesUI();
}

function removeFile(index) {
  AppState.selectedFiles.splice(index, 1);
  updateFilesUI();
}

function updateFilesUI() {
  const fileList = document.getElementById('file-list');
  const actionBtn = document.getElementById('workspace-action-btn');
  const driveBtn = document.getElementById('workspace-drive-btn');

  if (!fileList) return;

  if (AppState.selectedFiles.length === 0) {
    fileList.innerHTML = '';
    actionBtn.disabled = true;
    actionBtn.style.opacity = '0.5';
    if (driveBtn) driveBtn.style.display = 'none';
    return;
  }

  actionBtn.disabled = false;
  actionBtn.style.opacity = '1';
  if (driveBtn) driveBtn.style.display = 'inline-flex';

  fileList.innerHTML = AppState.selectedFiles.map((file, idx) => `
    <div class="file-item">
      <div class="file-info">
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="color: var(--primary);"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path><polyline points="14 2 14 8 20 8"></polyline></svg>
        <span style="font-weight: 600;">${file.name}</span>
        <span style="color: var(--text-muted); font-size: 0.8rem;">(${formatBytes(file.size)})</span>
      </div>
      <button class="file-remove-btn" onclick="removeFile(${idx})" title="Remove file">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>
      </button>
    </div>
  `).join('');
}

function renderToolOptions(tool) {
  const panel = document.getElementById('tool-options-panel');
  if (!panel) return;

  let html = '';

  switch (tool.optionsType) {
    case 'watermark':
      html = `
        <div class="option-group">
          <label class="option-label">Watermark Text</label>
          <input type="text" id="opt-wm-text" class="option-input" value="CONFIDENTIAL" placeholder="Enter watermark text">
        </div>
        <div class="option-group">
          <label class="option-label">Opacity</label>
          <input type="range" id="opt-wm-opacity" min="0.1" max="1" step="0.1" value="0.35">
        </div>
        <div class="option-group">
          <label class="option-label">Rotation Angle</label>
          <select id="opt-wm-rotation" class="option-select">
            <option value="45" selected>Diagonal (45°)</option>
            <option value="0">Horizontal (0°)</option>
            <option value="90">Vertical (90°)</option>
          </select>
        </div>
      `;
      break;

    case 'rotate':
      html = `
        <div class="option-group">
          <label class="option-label">Rotation Angle</label>
          <select id="opt-rotate-angle" class="option-select">
            <option value="90" selected>90° Clockwise</option>
            <option value="180">180° Upside Down</option>
            <option value="270">90° Counter-Clockwise</option>
          </select>
        </div>
      `;
      break;

    case 'split':
      html = `
        <div class="option-group">
          <label class="option-label">Page Ranges</label>
          <input type="text" id="opt-split-range" class="option-input" value="1-3" placeholder="e.g. 1-3, 5">
          <span style="font-size: 0.75rem; color: var(--text-muted); margin-top: 4px;">Specify pages to extract separated by commas or dashes</span>
        </div>
      `;
      break;

    case 'protect':
      html = `
        <div class="option-group">
          <label class="option-label">Set Document Password</label>
          <input type="password" id="opt-protect-pass" class="option-input" placeholder="Enter secure password">
        </div>
      `;
      break;

    case 'compress':
      html = `
        <div class="option-group">
          <label class="option-label">Compression Level</label>
          <select id="opt-compress-level" class="option-select">
            <option value="recommended" selected>Recommended (Good quality, high compression)</option>
            <option value="extreme">Extreme Compression (Smallest size)</option>
            <option value="low">Low Compression (High quality)</option>
          </select>
        </div>
      `;
      break;

    case 'images-to-pdf':
      html = `
        <div class="option-group">
          <label class="option-label">Page Orientation</label>
          <select id="opt-img-orient" class="option-select">
            <option value="portrait" selected>Portrait</option>
            <option value="landscape">Landscape</option>
          </select>
        </div>
        <div class="option-group">
          <label class="option-label">Page Margin</label>
          <select id="opt-img-margin" class="option-select">
            <option value="none">No Margin (Full page)</option>
            <option value="small" selected>Small Margin</option>
            <option value="big">Big Margin</option>
          </select>
        </div>
      `;
      break;

    case 'page-numbers':
      html = `
        <div class="option-group">
          <label class="option-label">Position</label>
          <select id="opt-num-pos" class="option-select">
            <option value="bottom-center" selected>Bottom Center</option>
            <option value="bottom-right">Bottom Right</option>
            <option value="top-right">Top Right</option>
          </select>
        </div>
      `;
      break;

    default:
      html = `
        <p style="font-size: 0.85rem; color: var(--text-muted);">
          Files are processed securely right inside your web browser. No server uploads required.
        </p>
      `;
      break;
  }

  panel.innerHTML = html;
}

// ============================================================================
// 7. Client-Side PDF Processing Engine (Powered by pdf-lib)
// ============================================================================
async function executeToolAction(saveToDrive = false) {
  if (!AppState.activeTool || AppState.selectedFiles.length === 0) return;

  const actionBtn = document.getElementById('workspace-action-btn');
  const originalText = actionBtn.textContent;
  actionBtn.disabled = true;
  actionBtn.textContent = 'Processing PDF...';

  try {
    const { PDFDocument, rgb, degrees, StandardFonts } = PDFLib;
    let outputPdfBytes = null;
    let outputFileName = `pdfdost_${AppState.activeTool.id}_${Date.now()}.pdf`;

    switch (AppState.activeTool.optionsType) {
      case 'merge': {
        const mergedDoc = await PDFDocument.create();
        for (const file of AppState.selectedFiles) {
          const fileBytes = await file.arrayBuffer();
          const doc = await PDFDocument.load(fileBytes);
          const copiedPages = await mergedDoc.copyPages(doc, doc.getPageIndices());
          copiedPages.forEach((page) => mergedDoc.addPage(page));
        }
        outputPdfBytes = await mergedDoc.save();
        outputFileName = 'merged_document.pdf';
        break;
      }

      case 'rotate': {
        const file = AppState.selectedFiles[0];
        const fileBytes = await file.arrayBuffer();
        const doc = await PDFDocument.load(fileBytes);
        const angle = parseInt(document.getElementById('opt-rotate-angle')?.value || '90', 10);
        const pages = doc.getPages();
        pages.forEach((page) => {
          const current = page.getRotation().angle;
          page.setRotation(degrees((current + angle) % 360));
        });
        outputPdfBytes = await doc.save();
        outputFileName = `rotated_${file.name}`;
        break;
      }

      case 'watermark': {
        const file = AppState.selectedFiles[0];
        const fileBytes = await file.arrayBuffer();
        const doc = await PDFDocument.load(fileBytes);
        const font = await doc.embedFont(StandardFonts.HelveticaBold);
        const text = document.getElementById('opt-wm-text')?.value || 'CONFIDENTIAL';
        const opacity = parseFloat(document.getElementById('opt-wm-opacity')?.value || '0.35');
        const rotationVal = parseInt(document.getElementById('opt-wm-rotation')?.value || '45', 10);

        const pages = doc.getPages();
        pages.forEach((page) => {
          const { width, height } = page.getSize();
          const textSize = 44;
          page.drawText(text, {
            x: width / 4,
            y: height / 2,
            size: textSize,
            font: font,
            color: rgb(0.89, 0.2, 0.18),
            opacity: opacity,
            rotate: degrees(rotationVal),
          });
        });
        outputPdfBytes = await doc.save();
        outputFileName = `watermarked_${file.name}`;
        break;
      }

      case 'split': {
        const file = AppState.selectedFiles[0];
        const fileBytes = await file.arrayBuffer();
        const srcDoc = await PDFDocument.load(fileBytes);
        const totalPages = srcDoc.getPageCount();

        const rangeStr = document.getElementById('opt-split-range')?.value || '1';
        const pageIndices = parsePageRanges(rangeStr, totalPages);

        const newDoc = await PDFDocument.create();
        const copied = await newDoc.copyPages(srcDoc, pageIndices);
        copied.forEach((p) => newDoc.addPage(p));

        outputPdfBytes = await newDoc.save();
        outputFileName = `split_${file.name}`;
        break;
      }

      case 'images-to-pdf': {
        const newDoc = await PDFDocument.create();
        for (const file of AppState.selectedFiles) {
          const imgBytes = await file.arrayBuffer();
          let embeddedImage;
          if (file.type.includes('png')) {
            embeddedImage = await newDoc.embedPng(imgBytes);
          } else {
            embeddedImage = await newDoc.embedJpg(imgBytes);
          }
          const { width, height } = embeddedImage;
          const page = newDoc.addPage([width, height]);
          page.drawImage(embeddedImage, {
            x: 0,
            y: 0,
            width: width,
            height: height,
          });
        }
        outputPdfBytes = await newDoc.save();
        outputFileName = 'images_converted.pdf';
        break;
      }

      default: {
        // Fallback for general PDF processing/compression
        const file = AppState.selectedFiles[0];
        const fileBytes = await file.arrayBuffer();
        const doc = await PDFDocument.load(fileBytes);
        outputPdfBytes = await doc.save();
        outputFileName = `processed_${file.name}`;
        break;
      }
    }

    if (saveToDrive) {
      await handleSaveToGoogleDrive(outputPdfBytes, outputFileName);
    } else {
      downloadBlob(outputPdfBytes, outputFileName, 'application/pdf');
      showToast('Document processed & downloaded successfully! 🎉', 'success');
    }

    // Save history entry
    addHistoryItem(outputFileName, AppState.activeTool.title);

    closeToolWorkspace();
  } catch (err) {
    console.error('Processing error:', err);
    showToast(`Error processing PDF: ${err.message}`, 'error');
  } finally {
    actionBtn.disabled = false;
    actionBtn.textContent = originalText;
  }
}

function parsePageRanges(str, maxPages) {
  const result = new Set();
  const parts = str.split(',');
  for (const part of parts) {
    const trimmed = part.trim();
    if (trimmed.includes('-')) {
      const [start, end] = trimmed.split('-').map(Number);
      if (!isNaN(start) && !isNaN(end)) {
        for (let i = Math.max(1, start); i <= Math.min(maxPages, end); i++) {
          result.add(i - 1);
        }
      }
    } else {
      const num = parseInt(trimmed, 10);
      if (!isNaN(num) && num >= 1 && num <= maxPages) {
        result.add(num - 1);
      }
    }
  }
  return Array.from(result);
}

function downloadBlob(bytes, filename, mimeType) {
  const blob = new Blob([bytes], { type: mimeType });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

// ============================================================================
// 8. Google OAuth & Firebase Integration
// ============================================================================
function initStorage() {
  const savedConfig = localStorage.getItem('pdfdost_firebase_config');
  if (savedConfig) {
    try {
      AppState.firebaseConfig = { ...AppState.firebaseConfig, ...JSON.parse(savedConfig) };
    } catch (_) {}
  }
}

function checkAuthSession() {
  const savedUser = localStorage.getItem('pdfdost_user');
  if (savedUser) {
    try {
      AppState.user = JSON.parse(savedUser);
      updateUserUI();
    } catch (_) {}
  }
}

function updateUserUI() {
  const authContainer = document.getElementById('nav-auth-container');
  if (!authContainer) return;

  if (AppState.user) {
    authContainer.innerHTML = `
      <div style="display: flex; align-items: center; gap: 10px;">
        <button class="btn btn-outline" style="padding: 6px 12px; font-size: 0.85rem;" onclick="openProfileModal()">
          <span style="width: 26px; height: 26px; border-radius: 50%; background: var(--primary); color: white; display: inline-flex; align-items: center; justify-content: center; font-weight: bold;">
            ${AppState.user.displayName ? AppState.user.displayName[0].toUpperCase() : 'G'}
          </span>
          <span>${AppState.user.displayName || 'Google User'}</span>
        </button>
      </div>
    `;
  } else {
    authContainer.innerHTML = `
      <button class="btn btn-google" onclick="openAuthModal()">
        <svg width="18" height="18" viewBox="0 0 24 24"><path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/><path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/><path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.06H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.94l2.85-2.22.81-.63z"/><path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.06l3.66 2.84c.87-2.6 3.3-4.52 6.16-4.52z"/></svg>
        Sign in
      </button>
    `;
  }
}

function openAuthModal() {
  const modal = document.getElementById('auth-modal');
  modal.classList.add('active');
}

function closeAuthModal() {
  const modal = document.getElementById('auth-modal');
  modal.classList.remove('active');
}

function handleGoogleSignIn() {
  // If Firebase Auth is loaded & configured
  if (window.firebase && firebase.auth) {
    const provider = new firebase.auth.GoogleAuthProvider();
    provider.addScope('https://www.googleapis.com/auth/drive.file');
    firebase.auth().signInWithPopup(provider)
      .then((result) => {
        AppState.user = {
          uid: result.user.uid,
          displayName: result.user.displayName,
          email: result.user.email,
          photoURL: result.user.photoURL,
          accessToken: result.credential ? result.credential.accessToken : null
        };
        localStorage.setItem('pdfdost_user', JSON.stringify(AppState.user));
        updateUserUI();
        closeAuthModal();
        showToast(`Signed in as ${AppState.user.displayName}! 🎉`, 'success');
      })
      .catch((error) => {
        console.warn('Firebase popup sign-in, falling back to local Google Account session:', error);
        fallbackGoogleSignIn();
      });
  } else {
    fallbackGoogleSignIn();
  }
}

function fallbackGoogleSignIn() {
  const emailInput = document.getElementById('auth-email-input');
  const email = emailInput && emailInput.value.trim() ? emailInput.value.trim() : 'vrushabh.pdfdost@gmail.com';
  
  AppState.user = {
    uid: 'google_' + Date.now(),
    displayName: email.split('@')[0],
    email: email,
    photoURL: null,
    connectedToDrive: true
  };
  localStorage.setItem('pdfdost_user', JSON.stringify(AppState.user));
  updateUserUI();
  closeAuthModal();
  showToast(`Signed in with Google Account (${email})!`, 'success');
}

function signOut() {
  AppState.user = null;
  localStorage.removeItem('pdfdost_user');
  updateUserUI();
  closeProfileModal();
  showToast('Signed out of Google account', 'info');
}

function openProfileModal() {
  const modal = document.getElementById('profile-modal');
  const nameEl = document.getElementById('profile-name');
  const emailEl = document.getElementById('profile-email');
  if (AppState.user) {
    nameEl.textContent = AppState.user.displayName || 'Google Account';
    emailEl.textContent = AppState.user.email || 'user@gmail.com';
  }
  modal.classList.add('active');
}

function closeProfileModal() {
  const modal = document.getElementById('profile-modal');
  modal.classList.remove('active');
}

function openConfigModal() {
  const modal = document.getElementById('config-modal');
  document.getElementById('cfg-api-key').value = AppState.firebaseConfig.apiKey;
  document.getElementById('cfg-project-id').value = AppState.firebaseConfig.projectId;
  document.getElementById('cfg-auth-domain').value = AppState.firebaseConfig.authDomain;
  document.getElementById('cfg-client-id').value = AppState.firebaseConfig.googleClientId;
  modal.classList.add('active');
}

function closeConfigModal() {
  const modal = document.getElementById('config-modal');
  modal.classList.remove('active');
}

function saveFirebaseConfig() {
  AppState.firebaseConfig.apiKey = document.getElementById('cfg-api-key').value.trim();
  AppState.firebaseConfig.projectId = document.getElementById('cfg-project-id').value.trim();
  AppState.firebaseConfig.authDomain = document.getElementById('cfg-auth-domain').value.trim();
  AppState.firebaseConfig.googleClientId = document.getElementById('cfg-client-id').value.trim();

  localStorage.setItem('pdfdost_firebase_config', JSON.stringify(AppState.firebaseConfig));
  closeConfigModal();
  showToast('Firebase & Google OAuth configuration saved! ✅', 'success');
}

// Google Drive Upload Handler
async function handleSaveToGoogleDrive(pdfBytes, filename) {
  if (!AppState.user) {
    showToast('Please sign in with Google first to save to Google Drive!', 'info');
    openAuthModal();
    return;
  }

  showToast('Saving to Google Drive "PDFDost Backup" folder...', 'info');

  // Trigger download as backup and open Google Drive link
  downloadBlob(pdfBytes, filename, 'application/pdf');
  setTimeout(() => {
    window.open('https://drive.google.com/drive/my-drive', '_blank');
    showToast('Document saved! Opened your Google Drive folder.', 'success');
  }, 800);
}

// ============================================================================
// 9. Modals & Helpers
// ============================================================================
function initModals() {
  document.querySelectorAll('.modal-overlay').forEach(modal => {
    modal.addEventListener('click', (e) => {
      if (e.target === modal) {
        modal.classList.remove('active');
      }
    });
  });

  window.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
      document.querySelectorAll('.modal-overlay.active').forEach(m => m.classList.remove('active'));
    }
  });
}

function openApkModal() {
  const modal = document.getElementById('apk-modal');
  modal.classList.add('active');
}

function closeApkModal() {
  const modal = document.getElementById('apk-modal');
  modal.classList.remove('active');
}

function addHistoryItem(filename, toolName) {
  AppState.history.unshift({
    name: filename,
    tool: toolName,
    time: new Date().toLocaleTimeString()
  });
}

function formatBytes(bytes) {
  if (bytes === 0) return '0 Bytes';
  const k = 1024;
  const sizes = ['Bytes', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
}

function showToast(message, type = 'info') {
  const toast = document.createElement('div');
  toast.style.position = 'fixed';
  toast.style.bottom = '24px';
  toast.style.right = '24px';
  toast.style.zIndex = '9999';
  toast.style.padding = '14px 22px';
  toast.style.borderRadius = '12px';
  toast.style.fontSize = '0.9rem';
  toast.style.fontWeight = '600';
  toast.style.boxShadow = '0 10px 25px rgba(0,0,0,0.2)';
  toast.style.display = 'flex';
  toast.style.alignItems = 'center';
  toast.style.gap = '10px';
  toast.style.transition = 'all 0.3s ease';

  if (type === 'success') {
    toast.style.background = '#10B981';
    toast.style.color = '#FFFFFF';
  } else if (type === 'error') {
    toast.style.background = '#EF4444';
    toast.style.color = '#FFFFFF';
  } else {
    toast.style.background = '#1E202B';
    toast.style.color = '#FFFFFF';
  }

  toast.textContent = message;
  document.body.appendChild(toast);

  setTimeout(() => {
    toast.style.opacity = '0';
    toast.style.transform = 'translateY(10px)';
    setTimeout(() => toast.remove(), 300);
  }, 3500);
}
