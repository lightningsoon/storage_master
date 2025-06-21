import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/item.dart';
import '../services/database_service.dart';
import 'package:camera/camera.dart';
import '../constants/categories.dart';

class PhotoAddItemScreen extends StatefulWidget {
  final Function? onItemsAdded;
  const PhotoAddItemScreen({Key? key, this.onItemsAdded}) : super(key: key);

  @override
  State<PhotoAddItemScreen> createState() => _PhotoAddItemScreenState();
}

class _PhotoAddItemScreenState extends State<PhotoAddItemScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  String? _imagePath;
  final List<TextEditingController> _nameControllers = [TextEditingController()];
  String? _category;
  bool _isSaving = false;

  final DatabaseService _databaseService = DatabaseService();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final firstCamera = cameras.first;

    _controller = CameraController(
      firstCamera,
      ResolutionPreset.medium,
    );

    _initializeControllerFuture = _controller!.initialize();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _takePicture() async {
    try {
      await _initializeControllerFuture;
      final image = await _controller!.takePicture();
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = path.basename(image.path);
      final savedImage = await File(image.path).copy('${appDir.path}/$fileName');
      setState(() {
        _imagePath = savedImage.path;
      });
    } catch (e) {
      print(e);
    }
  }

  void _addNameField() {
    setState(() {
      _nameControllers.add(TextEditingController());
    });
  }

  void _removeNameField(int index) {
    if (_nameControllers.length > 1) {
      setState(() {
        _nameControllers.removeAt(index);
      });
    }
  }

  Future<void> _saveItems() async {
    if (_imagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先拍照')));
      return;
    }
    final names = _nameControllers.map((c) => c.text.trim()).where((n) => n.isNotEmpty).toList();
    if (names.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写至少一个物品名称')));
      return;
    }
    setState(() { _isSaving = true; });
    try {
      final groupId = await _databaseService.getNextGroupId();
      final now = DateTime.now();
      final items = names.map((name) => Item(
        name: name,
        createdAt: now,
        imagePath: _imagePath!,
        groupId: groupId,
        category: _category,
      )).toList();
      await _databaseService.insertMultipleItems(items);
      if (widget.onItemsAdded != null) widget.onItemsAdded!();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('物品已保存')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败: $e')));
      }
    } finally {
      setState(() { _isSaving = false; });
    }
  }

  @override
  void dispose() {
    for (var c in _nameControllers) {
      c.dispose();
    }
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('拍照添加物品'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                FutureBuilder<void>(
                  future: _initializeControllerFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done) {
                      return CameraPreview(_controller!);
                    } else {
                      return Center(child: CircularProgressIndicator());
                    }
                  },
                ),
                if (_imagePath != null)
                  Image.file(File(_imagePath!), height: 200),
                ElevatedButton(
                  onPressed: _takePicture,
                  child: Text('拍照'),
                ),
                const SizedBox(height: 16),
                // 多物品名称
                const Text('物品名称（可添加多个）', style: TextStyle(fontSize: 16)),
                ..._nameControllers.asMap().entries.map((entry) {
                  int idx = entry.key;
                  var controller = entry.value;
                  return Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          decoration: InputDecoration(
                            labelText: '物品名称${idx + 1}',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      if (_nameControllers.length > 1)
                        IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                          onPressed: () => _removeNameField(idx),
                        ),
                    ],
                  );
                }).toList(),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('添加名称'),
                    onPressed: _addNameField,
                  ),
                ),
                const SizedBox(height: 16),
                // 类别选择器
                DropdownButtonFormField<String>(
                  value: _category,
                  items: kCommonCategories
                      .map((cat) => DropdownMenuItem(
                            value: cat,
                            child: Text(cat),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _category = value;
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: '类别',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveItems,
                  child: _isSaving 
                    ? const CircularProgressIndicator() 
                    : const Text('保存物品'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 