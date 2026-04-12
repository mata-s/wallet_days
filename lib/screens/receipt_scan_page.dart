import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

class ReceiptScanPage extends StatefulWidget {
  const ReceiptScanPage({super.key});

  @override
  State<ReceiptScanPage> createState() => _ReceiptScanPageState();
}

class _ReceiptScanPageState extends State<ReceiptScanPage> {
  bool _isLoading = false;
  String? _selectedImageLabel;
  String? _errorMessage;
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;

  Future<void> _pickFromCamera() async {
    try {
      final image = await _picker.pickImage(source: ImageSource.camera);
      if (image == null) return;

      setState(() {
        _errorMessage = null;
        _selectedImage = File(image.path);
        _selectedImageLabel = 'カメラで撮影したレシートを選択中';
      });

      await _processImage(_selectedImage!);
    } catch (e) {
      setState(() {
        _errorMessage = 'カメラの起動に失敗しました';
      });
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final assets = await AssetPicker.pickAssets(
        context,
        pickerConfig: const AssetPickerConfig(
          requestType: RequestType.image,
          maxAssets: 1,
        ),
      );

      if (assets == null || assets.isEmpty) return;

      final file = await assets.first.file;
      if (file == null) {
        if (!mounted) return;
        setState(() {
          _errorMessage = '画像ファイルの取得に失敗しました';
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _errorMessage = null;
        _selectedImage = file;
        _selectedImageLabel = '写真から選んだレシートを確認中';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '画像の取得に失敗しました';
      });
    }
  }

  Future<void> _processImage(File image) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _selectedImageLabel = '読み取り中...';
    });

    try {
      final bytes = await image.readAsBytes();

      final response = await Supabase.instance.client.functions.invoke(
        'scan-receipt',
        body: {
          'image': base64Encode(bytes),
        },
      );

      final raw = response.data as String;

      final cleaned = raw
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final data = jsonDecode(cleaned);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _selectedImageLabel = '読み取り完了';
      });

      Navigator.pop(context, {
        'store': data['store'],
        'amount': data['amount'],
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = '読み取りに失敗しました';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('レシート読み込み'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8F4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFD9CC)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'レシートをアップして支出を自動入力',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '店名と金額を自動で読み取ります。読み取り結果はあとから編集できます。',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFEAEAEA)),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.receipt_long,
                    size: 56,
                    color: Color(0xFFFF8A65),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _selectedImageLabel ?? 'まだレシートは選択されていません',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (_selectedImage != null) ...[
                    const SizedBox(height: 20),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.file(
                        _selectedImage!,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _pickFromCamera,
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('カメラで撮る'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _pickFromGallery,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('写真から選ぶ'),
                    ),
                  ),
                ],
              ),
            ),
            if (_isLoading) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE6E9F2)),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'レシート画像を準備しています...',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              '読み込みのコツ',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '・レシート全体が入るように撮影してください\n・明るい場所で影が入らないようにしてください\n・金額が違う場合は、このあと手で修正できます',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.black54,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: null,
            child: const Text('この内容で入力する'),
          ),
        ),
      ),
    );
  }
}