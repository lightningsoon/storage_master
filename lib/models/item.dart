import 'package:flutter/foundation.dart';

class Item {
  final int? id;
  final String name;
  final DateTime createdAt;
  final String? imagePath;
  final int? groupId;
  final String? category;

  Item({
    this.id,
    required this.name,
    required this.createdAt,
    this.imagePath,
    this.groupId,
    this.category,
  });

  // 从Map构造一个Item对象
  factory Item.fromMap(Map<String, dynamic> map) {
    return Item(
      id: map['id'] as int?,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      imagePath: map['image_path'] as String?,
      groupId: map['group_id'] as int?,
      category: map['category'] as String?,
    );
  }

  // 转换为Map对象，方便数据库存储
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'image_path': imagePath,
      'group_id': groupId,
      'category': category,
    };
  }

  // 创建一个副本，可以修改特定字段
  Item copyWith({
    int? id,
    String? name,
    DateTime? createdAt,
    String? imagePath,
    int? groupId,
    String? category,
  }) {
    return Item(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      imagePath: imagePath ?? this.imagePath,
      groupId: groupId ?? this.groupId,
      category: category ?? this.category,
    );
  }

  @override
  String toString() {
    return 'Item(id: $id, name: $name, createdAt: $createdAt, imagePath: $imagePath, groupId: $groupId, category: $category)';
  }
} 