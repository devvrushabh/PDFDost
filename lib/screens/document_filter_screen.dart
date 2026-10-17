import 'dart:io';
import 'package:flutter/material.dart';
import '../services/scanner_engine.dart';

class DocumentFilterScreen extends StatefulWidget {
  final String imagePath;
  final bool isDark;
  final DocScanFilter initialFilter;
  final double initialBrightness;
  final double initialContrast;
  final bool showApplyToAll;

  const DocumentFilterScreen({
    super.key,
    required this.imagePath,
    required this.isDark,
    this.initialFilter = DocScanFilter.magicColor,
    this.initialBrightness = 0.0,
    this.initialContrast = 1.0,
    this.showApplyToAll = true,
  });

  @override
  State<DocumentFilterScreen> createState() => _DocumentFilterScreenState();
}

class _DocumentFilterScreenState extends State<DocumentFilterScreen> {
  late DocScanFilter _selectedFilter;
  late double _brightness;
  late double _contrast;
  bool _applyToAll = false;
  bool _showFineTune = false;

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter;
    _brightness = widget.initialBrightness;
    _contrast = widget.initialContrast;
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDark ? const Color(0xFF0F1015) : const Color(0xFF1E2024);
    final cardBg = widget.isDark ? const Color(0xFF1A1C23) : const Color(0xFF2B2D38);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Document Filters & Color',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showFineTune ? Icons.tune_rounded : Icons.tune_outlined,
              color: _showFineTune ? const Color(0xFFFA9282) : Colors.white70,
              size: 22,
            ),
            tooltip: 'Fine-tune Brightness & Contrast',
            onPressed: () => setState(() => _showFineTune = !_showFineTune),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Center Live Document Preview
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ColorFiltered(
                      colorFilter: ScannerEngine.getColorFilter(
                        _selectedFilter,
                        brightness: _brightness,
                        contrast: _contrast,
                      ),
                      child: Image.file(
                        File(widget.imagePath),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Optional Fine-Tune Controls (Brightness & Contrast)
            if (_showFineTune)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Column(
                  children: [
                    // Brightness slider
                    Row(
                      children: [
                        const Icon(Icons.brightness_6_rounded, color: Colors.white70, size: 18),
                        const SizedBox(width: 8),
                        const Text('Brightness', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: const Color(0xFFFA9282),
                              thumbColor: const Color(0xFFFA9282),
                              overlayColor: const Color(0xFFFA9282).withValues(alpha: 0.2),
                              trackHeight: 3,
                            ),
                            child: Slider(
                              value: _brightness,
                              min: -0.3,
                              max: 0.3,
                              divisions: 30,
                              onChanged: (v) => setState(() => _brightness = v),
                            ),
                          ),
                        ),
                        Text(
                          '${(_brightness * 100).toInt()}%',
                          style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    // Contrast slider
                    Row(
                      children: [
                        const Icon(Icons.contrast_rounded, color: Colors.white70, size: 18),
                        const SizedBox(width: 8),
                        const Text('Contrast', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: const Color(0xFFFA9282),
                              thumbColor: const Color(0xFFFA9282),
                              overlayColor: const Color(0xFFFA9282).withValues(alpha: 0.2),
                              trackHeight: 3,
                            ),
                            child: Slider(
                              value: _contrast,
                              min: 0.7,
                              max: 1.5,
                              divisions: 30,
                              onChanged: (v) => setState(() => _contrast = v),
                            ),
                          ),
                        ),
                        Text(
                          '${((_contrast - 1.0) * 100).toInt()}%',
                          style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // Filter Selector Carousel
            Container(
              height: 118,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: DocScanFilter.values.length,
                itemBuilder: (context, index) {
                  final filter = DocScanFilter.values[index];
                  final isSelected = _selectedFilter == filter;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedFilter = filter;
                      });
                    },
                    child: Container(
                      width: 80,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFFA9282).withValues(alpha: 0.18)
                            : cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFFA9282)
                              : Colors.white.withValues(alpha: 0.08),
                          width: isSelected ? 2.0 : 1.0,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Miniature Filter Preview thumbnail
                          Container(
                            width: 44,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.black26),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: ColorFiltered(
                              colorFilter: ScannerEngine.getColorFilter(filter),
                              child: Image.file(
                                File(widget.imagePath),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            ScannerEngine.getFilterTitle(filter),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontSize: 10.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Apply to all pages toggle + Save Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: widget.isDark ? const Color(0xFF16171B) : const Color(0xFF262831),
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
              ),
              child: Row(
                children: [
                  if (widget.showApplyToAll)
                    GestureDetector(
                      onTap: () => setState(() => _applyToAll = !_applyToAll),
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        children: [
                          Icon(
                            _applyToAll ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                            color: _applyToAll ? const Color(0xFFFA9282) : Colors.white54,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Apply to all pages',
                            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFA9282),
                      foregroundColor: const Color(0xFF141518),
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 20),
                    label: const Text(
                      'Apply Filter',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      Navigator.pop(context, {
                        'filter': _selectedFilter,
                        'brightness': _brightness,
                        'contrast': _contrast,
                        'applyToAll': _applyToAll,
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
