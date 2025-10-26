// lib/main.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_code_tools/qr_code_tools.dart'; // decode QR from gallery

void main() {
  runApp(const QRDetectionApp());
}

class QRDetectionApp extends StatelessWidget {
  const QRDetectionApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR Phish Detector',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomePage(),
    );
  }
}

/// Home page
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _openScanChoice(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SizedBox(
        height: 140,
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Use Camera'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CameraScannerPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Upload from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GalleryPickerPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR Phish Detector')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text(
              'Detect malicious URLs from QR codes',
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan QR Code'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                textStyle: const TextStyle(fontSize: 18),
              ),
              onPressed: () => _openScanChoice(context),
            ),
            const SizedBox(height: 18),
            const Text(
              'Tip: Use camera for real-time scanning. Use gallery to analyze a stored image.',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            )
          ]),
        ),
      ),
    );
  }
}

/// Camera scanner page
class CameraScannerPage extends StatefulWidget {
  const CameraScannerPage({super.key});

  @override
  State<CameraScannerPage> createState() => _CameraScannerPageState();
}

class _CameraScannerPageState extends State<CameraScannerPage> {
  final MobileScannerController cameraController = MobileScannerController();
  Interpreter? _interpreter;
  bool _modelLoaded = false;
  String? _lastUrl;
  double? _lastProb;
  String _message = 'Point the camera at a QR code';
  bool _handling = false;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  @override
  void dispose() {
    cameraController.dispose();
    _interpreter?.close();
    super.dispose();
  }

  Future<void> _loadModel() async {
    try {
      // Use 'assets/model.tflite'
      _interpreter = await Interpreter.fromAsset('assets/model.tflite');
      setState(() => _modelLoaded = true);
      debugPrint('[INFO] ✅ Model loaded successfully');
    } catch (e) {
      debugPrint('[ERROR] ❌ Failed to load model: $e');
      setState(() => _message = 'Failed to load model');
    }
  }

  List<double> _extractFeatures(String url) {
    final uri = Uri.tryParse(url) ?? Uri();
    final domain = uri.host;
    final path = uri.path;
    final scheme = uri.scheme;

    int domainLength = domain.length;
    int haveIp = RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(domain) ? 1 : 0;
    int haveAt = url.contains('@') ? 1 : 0;
    int urlLength = url.length;
    int urlDepth = path.split('/').where((s) => s.isNotEmpty).length;
    int redirection = path.contains('//') ? 1 : 0;
    int httpsDomain = (scheme == 'https') ? 1 : 0;
    int tinyUrl = (domain.contains('tinyurl') || domain.contains('bit.ly')) ? 1 : 0;
    int prefixSuffix = domain.contains('-') ? 1 : 0;

    return <double>[
      domainLength.toDouble(),
      haveIp.toDouble(),
      haveAt.toDouble(),
      urlLength.toDouble(),
      urlDepth.toDouble(),
      redirection.toDouble(),
      httpsDomain.toDouble(),
      tinyUrl.toDouble(),
      prefixSuffix.toDouble(),
    ];
  }

  Future<void> _predictAndSet(String url) async {
    if (!_modelLoaded || _interpreter == null) {
      setState(() => _message = 'Model not loaded yet');
      return;
    }

    final input = [_extractFeatures(url)];
    final output = List.filled(1, 0.0).reshape([1, 1]);
    try {
      _interpreter!.run(input, output);
      final prob = (output[0][0] as num).toDouble();
      setState(() {
        _lastUrl = url;
        _lastProb = prob;
        _message = prob >= 0.5 ? "It's not safe to open" : "Safe to open";
      });
    } catch (e) {
      setState(() => _message = 'Prediction failed');
    }
  }

  Color _resultColor() => (_lastProb ?? 0) >= 0.5 ? Colors.red : Colors.green;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan with Camera (Live)')),
      body: Column(
        children: [
          Expanded(
            flex: 6,
            child: MobileScanner(
              controller: cameraController,
              onDetect: (capture) async {
                if (_handling) return;
                if (capture.barcodes.isEmpty) return;
                final barcode = capture.barcodes.first;
                final raw = barcode.rawValue ?? barcode.displayValue;
                if (raw == null) return;
                _handling = true;
                await _predictAndSet(raw);
                await Future.delayed(const Duration(milliseconds: 800));
                _handling = false;
              },
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_lastUrl != null)
                    Text(
                      _lastUrl!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _resultColor(),
                        fontSize: 16,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    _message,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () => cameraController.toggleTorch(),
                    icon: const Icon(Icons.flash_on),
                    label: const Text('Toggle Torch'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gallery picker page
class GalleryPickerPage extends StatefulWidget {
  const GalleryPickerPage({super.key});
  @override
  State<GalleryPickerPage> createState() => _GalleryPickerPageState();
}

class _GalleryPickerPageState extends State<GalleryPickerPage> {
  final ImagePicker _picker = ImagePicker();
  Interpreter? _interpreter;
  bool _modelLoaded = false;
  String? _decoded;
  double? _prob;
  String _message = 'Pick an image that contains a QR code';

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/model.tflite');
      setState(() => _modelLoaded = true);
    } catch (e) {
      setState(() => _message = 'Model load failed');
    }
  }

  List<double> _extractFeatures(String url) {
    final uri = Uri.tryParse(url) ?? Uri();
    final domain = uri.host;
    final path = uri.path;
    final scheme = uri.scheme;

    int domainLength = domain.length;
    int haveIp = RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(domain) ? 1 : 0;
    int haveAt = url.contains('@') ? 1 : 0;
    int urlLength = url.length;
    int urlDepth = path.split('/').where((s) => s.isNotEmpty).length;
    int redirection = path.contains('//') ? 1 : 0;
    int httpsDomain = (scheme == 'https') ? 1 : 0;
    int tinyUrl = (domain.contains('tinyurl') || domain.contains('bit.ly')) ? 1 : 0;
    int prefixSuffix = domain.contains('-') ? 1 : 0;

    return <double>[
      domainLength.toDouble(),
      haveIp.toDouble(),
      haveAt.toDouble(),
      urlLength.toDouble(),
      urlDepth.toDouble(),
      redirection.toDouble(),
      httpsDomain.toDouble(),
      tinyUrl.toDouble(),
      prefixSuffix.toDouble(),
    ];
  }

  Future<void> _pickAndDecode() async {
    final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    setState(() {
      _message = 'Decoding QR...';
      _decoded = null;
      _prob = null;
    });

    try {
      final String? data = await QrCodeToolsPlugin.decodeFrom(file.path);
      if (data == null) {
        setState(() => _message = 'No QR detected in image');
        return;
      }
      setState(() => _decoded = data);

      final input = [_extractFeatures(data)];
      final output = List.filled(1, 0.0).reshape([1, 1]);
      _interpreter?.run(input, output);
      final prob = (output[0][0] as num).toDouble();
      setState(() {
        _prob = prob;
        _message = prob >= 0.5 ? "It's not safe to open" : "Safe to open";
      });
    } catch (e) {
      setState(() => _message = 'Failed to decode QR from image');
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = (_prob ?? 0) >= 0.5 ? Colors.red : Colors.green;
    final italicStyle = const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey);

    return Scaffold(
      appBar: AppBar(title: const Text('Upload from Gallery')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.photo_library),
            label: const Text('Pick image from gallery'),
            onPressed: _pickAndDecode,
          ),
          const SizedBox(height: 12),
          if (_decoded != null)
            Card(
              child: ListTile(
                title: Text(_decoded ?? ''),
                subtitle: Text('Prob: ${((_prob ?? 0) * 100).toStringAsFixed(1)}%'),
                trailing: CircleAvatar(
                  backgroundColor: color,
                  child: Icon(
                    (_prob ?? 0) >= 0.5 ? Icons.warning : Icons.check,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text(_message, style: italicStyle),
        ]),
      ),
    );
  }
}
