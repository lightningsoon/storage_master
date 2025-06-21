import 'package:flutter/material.dart';
import '../models/item.dart';
import '../services/database_service.dart';
import 'add_item_screen.dart';
import 'item_detail_screen.dart';
import 'search_screen.dart';
import 'photo_add_item_screen.dart';
import 'photo_grid_picker_screen.dart';
import '../services/backup_service.dart';

class ItemListScreen extends StatefulWidget {
  const ItemListScreen({Key? key}) : super(key: key);

  @override
  _ItemListScreenState createState() => _ItemListScreenState();
}

class _ItemListScreenState extends State<ItemListScreen> {
  final DatabaseService _databaseService = DatabaseService();
  List<Item> _items = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadItems();
  }
  
  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final items = await _databaseService.getAllItems();
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  // 删除物品
  Future<void> _deleteItem(Item item) async {
    try {
      await _databaseService.deleteItem(item.id!);
      setState(() {
        _items.removeWhere((i) => i.id == item.id);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('物品已删除')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }

  // 构建物品列表项（美化版，带分隔感）
  Widget _buildItemTile(Item item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          title: Text(item.name, style: const TextStyle(fontSize: 18)),
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ItemDetailScreen(item: item),
              ),
            );
            if (result == true) {
              _loadItems();
            }
          },
          trailing: IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _showDeleteConfirmation(item),
          ),
        ),
      ),
    );
  }

  // 显示删除确认对话框
  void _showDeleteConfirmation(Item item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除"${item.name}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteItem(item);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  // 构建极简普通列表
  Widget _buildNormalList() {
    return ListView.separated(
      itemCount: _items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 0),
      itemBuilder: (context, index) {
        return _buildItemTile(_items[index]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('收纳大师'),
        actions: [
          // 备份文字按钮
          TextButton(
            child: const Text('备份', style: TextStyle(color: Colors.black)),
            onPressed: () async {
              final backupService = BackupService();
              try {
                final backupPath = await backupService.backupData();
                if (mounted) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('备份完成'),
                      content: Text('备份文件已保存到：\n$backupPath'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('知道了'),
                        ),
                      ],
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('备份失败: $e')),
                  );
                }
              }
            },
          ),
          // 恢复文字按钮
          TextButton(
            child: const Text('恢复', style: TextStyle(color: Colors.black)),
            onPressed: () async {
              final backupService = BackupService();
              try {
                await backupService.importData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('恢复成功')),
                  );
                  await _loadItems();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('恢复失败: $e')),
                  );
                }
              }
            },
          ),
          // 搜索按钮
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SearchScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inventory, size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('没有物品', style: TextStyle(fontSize: 18)),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddItemScreen(
                                onItemAdded: _loadItems,
                              ),
                            ),
                          );
                        },
                        child: const Text('添加物品'),
                      ),
                    ],
                  ),
                )
              : _buildNormalList(),
      floatingActionButton: Builder(
        builder: (parentContext) => FloatingActionButton(
          onPressed: () {
            showModalBottomSheet(
              context: parentContext,
              builder: (sheetContext) {
                return SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: Icon(Icons.edit),
                        title: Text('文字记录'),
                        onTap: () async {
                          Navigator.pop(sheetContext);
                          await Future.delayed(const Duration(milliseconds: 200));
                          final result = await Navigator.push(
                            parentContext,
                            MaterialPageRoute(
                              builder: (context) => AddItemScreen(
                                onItemAdded: _loadItems,
                              ),
                            ),
                          );
                          if (result == true) {
                            _loadItems();
                          }
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.camera_alt),
                        title: Text('拍照记录'),
                        onTap: () async {
                          Navigator.pop(sheetContext);
                          await Future.delayed(const Duration(milliseconds: 200));
                          final imagePath = await Navigator.push(
                            parentContext,
                            MaterialPageRoute(
                              builder: (context) => PhotoGridPickerScreen(),
                            ),
                          );
                          if (imagePath != null && imagePath is String && imagePath.isNotEmpty) {
                            final result = await Navigator.push(
                              parentContext,
                              MaterialPageRoute(
                                builder: (context) => AddItemScreen(
                                  onItemAdded: _loadItems,
                                  imagePath: imagePath,
                                ),
                              ),
                            );
                            if (result == true) {
                              _loadItems();
                            }
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
} 