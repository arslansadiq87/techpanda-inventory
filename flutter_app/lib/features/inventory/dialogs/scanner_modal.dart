import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Modal bottom sheet for scanning barcodes and QR codes using device camera, photo upload, or manual entry.
class ScannerModal extends StatefulWidget {
  const ScannerModal({
    super.key,
    required this.onCodeScanned,
  });

  final ValueChanged<String> onCodeScanned;

  static Future<void> show({
    required BuildContext context,
    required ValueChanged<String> onCodeScanned,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (modalContext) => ScannerModal(onCodeScanned: onCodeScanned),
    );
  }

  @override
  State<ScannerModal> createState() => _ScannerModalState();
}

class _ScannerModalState extends State<ScannerModal> {
  final _manualController = TextEditingController();
  MobileScannerController? _scannerController;
  bool _cameraAvailable = true;

  @override
  void initState() {
    super.initState();
    try {
      _scannerController = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
      );
    } catch (_) {
      _cameraAvailable = false;
    }
  }

  @override
  void dispose() {
    _manualController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  void _submitCode(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return;
    Navigator.pop(context);
    widget.onCodeScanned(trimmed);
  }

  Future<void> _pickAndScanImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (!mounted) return;

    if (picked != null && _scannerController != null) {
      final barcodeCapture = await _scannerController!.analyzeImage(picked.path);
      final val = barcodeCapture?.barcodes.firstOrNull?.rawValue;
      if (val != null && val.trim().isNotEmpty) {
        if (mounted) {
          _submitCode(val);
        }
        return;
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No QR code found in the selected image.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.qr_code_scanner, size: 28),
                  const SizedBox(width: 10),
                  Text(
                    'Scan Barcode or QR Code',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Scan a location QR code to view its contents, or a component barcode to view its details.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              if (_scannerController != null && _cameraAvailable) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 240,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        MobileScanner(
                          controller: _scannerController,
                          onDetect: (capture) {
                            for (final barcode in capture.barcodes) {
                              final val = barcode.rawValue;
                              if (val != null && val.trim().isNotEmpty) {
                                _submitCode(val);
                                break;
                              }
                            }
                          },
                        ),
                        Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.8),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _pickAndScanImage,
                    icon: const Icon(Icons.image_search),
                    label: const Text('Scan from photo'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _manualController,
                autofocus: _scannerController == null || !_cameraAvailable,
                decoration: InputDecoration(
                  labelText: 'Barcode gun or manual code entry',
                  hintText: 'e.g. location:..., location name, or ID',
                  prefixIcon: const Icon(Icons.keyboard),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: () => _submitCode(_manualController.text),
                  ),
                ),
                onSubmitted: _submitCode,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
