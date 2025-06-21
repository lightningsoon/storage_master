import 'package:flutter/material.dart';
import '../models/item.dart';
import '../services/database_service.dart';
import 'photo_grid_picker_screen.dart';
import 'dart:io';
import '../constants/categories.dart';

class AddItemScreen extends StatefulWidget {
  final Function? onItemAdded;
  final String? imagePath;
  const AddItemScreen({Key? key, this.onItemAdded, this.imagePath}) : super(key: key);

  @override
  _AddItemScreenState createState() => _AddItemScreenState();
}

class _ItemInput {
  final TextEditingController nameController;
  String? category;
  _ItemInput({String? name, this.category}) : nameController = TextEditingController(text: name);
  void dispose() => nameController.dispose();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final List<_ItemInput> _items = [];
  String? _imagePath;
  final DatabaseService _databaseService = DatabaseService();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _imagePath = widget.imagePath;
    _items.add(_ItemInput());
  }

  @override
  void dispose() {
    for (var item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhotoGridPickerScreen(),
      ),
    );
    if (result != null && result is String && result.isNotEmpty) {
      setState(() {
        _imagePath = result;
      });
    }
  }

  void _addItemGroup() {
    setState(() {
      _items.add(_ItemInput());
    });
  }

  void _removeItemGroup(int idx) {
    setState(() {
      _items[idx].dispose();
      _items.removeAt(idx);
    });
  }

  Future<void> _saveItem() async {
    if (_formKey.currentState!.validate()) {
      try {
        setState(() {
          _isSaving = true;
        });
        final now = DateTime.now();
        final items = _items
            .where((item) => item.nameController.text.trim().isNotEmpty)
            .map((item) => Item(
                  name: item.nameController.text.trim(),
                  createdAt: now,
                  imagePath: _imagePath,
                  category: item.category,
                ))
            .toList();
        if (items.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写至少一个物品')));
          setState(() {
            _isSaving = false;
          });
          return;
        }
        await _databaseService.insertMultipleItems(items);
        if (widget.onItemAdded != null) widget.onItemAdded!();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('物品已添加')));
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败: $e')));
        }
      } finally {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('添加物品'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_imagePath != null && _imagePath!.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      height: 180,
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
                    label: const Text('补充照片'),
                    onPressed: _pickImage,
                  ),
                  const SizedBox(height: 24),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _items.length,
                    itemBuilder: (context, idx) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('物品${_items.length > 1 ? ' ${idx + 1}' : ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const Spacer(),
                                  if (_items.length > 1)
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle, color: Colors.red),
                                      tooltip: '删除该物品',
                                      onPressed: () => _removeItemGroup(idx),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _items[idx].nameController,
                                decoration: const InputDecoration(
                                  labelText: '物品名称',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (idx == 0 && (value == null || value.trim().isEmpty)) {
                                    return '请输入物品名称';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                value: _items[idx].category,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                ),
                                hint: const Text('选择类别'),
                                items: [
                                  const DropdownMenuItem<String>(
                                    value: null,
                                    child: Text('无'),
                                  ),
                                  ...kCommonCategories.map((cat) => DropdownMenuItem(
                                    value: cat,
                                    child: Text(cat),
                                  )).toList(),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _items[idx].category = value;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('添加物品'),
                    onPressed: _addItemGroup,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveItem,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isSaving
                          ? const CircularProgressIndicator()
                          : const Text('保存', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 