import 'package:flutter/material.dart';
import '../models/item.dart';
import '../services/database_service.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../constants/categories.dart';

class EditItemScreen extends StatefulWidget {
  final Item item;
  const EditItemScreen({Key? key, required this.item}) : super(key: key);

  @override
  State<EditItemScreen> createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
  late TextEditingController _nameController;
  String? _imagePath;
  String? _category;
  final DatabaseService _databaseService = DatabaseService();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.name);
    _imagePath = widget.item.imagePath;
    _category = widget.item.category;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _imagePath = picked.path;
      });
    }
  }

  Future<void> _saveItem() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入物品名称')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final updatedItem = widget.item.copyWith(
        name: _nameController.text.trim(),
        imagePath: _imagePath,
        category: _category,
      );
      
      await _databaseService.updateItem(updatedItem);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存成功')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑物品'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // 图片展示/选择
            if (_imagePath != null && _imagePath!.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  image: DecorationImage(
                    image: FileImage(File(_imagePath!)),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_a_photo),
              label: const Text('选择/更换图片'),
              onPressed: _pickImage,
            ),
            const SizedBox(height: 16),
            // 名称
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '物品名称',
                border: OutlineInputBorder(),
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
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveItem,
                child: _isSaving
                    ? const CircularProgressIndicator()
                    : const Text('保存', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 