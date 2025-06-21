import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../models/item.dart';
import 'database_service.dart';

class BackupService {
  /// 备份所有数据到zip文件，返回备份文件路径
  Future<String> backupData() async {
    await Permission.storage.request();
    String dbName = 'storage_master.db';
    String dbDir = await getDatabasesPath();
    String dbPath = '$dbDir/$dbName';
    File dbFile = File(dbPath);
    if (!await dbFile.exists()) {
      throw Exception('数据库文件不存在: $dbPath\n请先添加至少一条数据后再备份。');
    }
    // 读取所有物品，收集图片路径
    final dbService = DatabaseService();
    final items = await dbService.getAllItems();
    List<File> imageFiles = [];
    for (var item in items) {
      if (item.imagePath != null && item.imagePath!.isNotEmpty) {
        final file = File(item.imagePath!);
        if (await file.exists()) {
          imageFiles.add(file);
        }
      }
    }
    // 生成readme.txt
    String readmeContent = '''收纳大师APP数据备份包\n\n包含内容：\n- storage_master.db: 数据库文件\n- images/: 物品图片文件夹\n- readme.txt: 本说明\n\nitems表结构：\n- id INTEGER 主键\n- name TEXT 名称\n- location TEXT 位置\n- tags TEXT 标签（逗号分隔）\n- notes TEXT 备注\n- created_at TEXT 创建时间\n- image_path TEXT 图片路径\n- group_id INTEGER 分组ID\n\n''';
    // 临时目录生成readme.txt
    final tempDir = await getTemporaryDirectory();
    final readmeFile = File('${tempDir.path}/readme.txt');
    await readmeFile.writeAsString(readmeContent);
    // 备份到Download目录
    String backupDir = '/storage/emulated/0/Download';
    String backupPath = '$backupDir/storage_master_backup.zip';
    // 创建zip
    final encoder = ZipFileEncoder();
    encoder.create(backupPath);
    encoder.addFile(dbFile);
    encoder.addFile(readmeFile);
    // images/目录下打包所有图片
    for (var img in imageFiles) {
      encoder.addFile(img, 'images/${img.uri.pathSegments.last}');
    }
    encoder.close();
    return backupPath;
  }

  /// 恢复数据：解压zip，恢复数据库和图片，修正图片路径
  Future<void> importData() async {
    await Permission.storage.request();
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['zip']);
    if (result == null || result.files.single.path == null) {
      throw Exception('未选择文件');
    }
    String zipPath = result.files.single.path!;
    // 1. 解压到临时目录
    final tempDir = await getTemporaryDirectory();
    final extractDir = Directory('${tempDir.path}/restore_${DateTime.now().millisecondsSinceEpoch}');
    if (!await extractDir.exists()) await extractDir.create(recursive: true);
    final inputStream = InputFileStream(zipPath);
    final archive = ZipDecoder().decodeBuffer(inputStream);
    for (final file in archive) {
      final filename = file.name;
      final data = file.content as List<int>;
      final outFile = File('${extractDir.path}/$filename');
      await outFile.parent.create(recursive: true);
      await outFile.writeAsBytes(data);
    }
    // 2. 恢复数据库
    String dbName = 'storage_master.db';
    String dbDir = await getDatabasesPath();
    String dbPath = '$dbDir/$dbName';
    final dbBackupFile = File('${extractDir.path}/storage_master.db');
    if (!await dbBackupFile.exists()) {
      throw Exception('备份包中未找到数据库文件');
    }
    await dbBackupFile.copy(dbPath);
    // 3. 恢复图片
    final imagesDir = Directory('${extractDir.path}/images');
    final appDocDir = await getApplicationDocumentsDirectory();
    final appImagesDir = Directory('${appDocDir.path}/images');
    if (!await appImagesDir.exists()) await appImagesDir.create(recursive: true);
    Map<String, String> oldToNewPath = {};
    if (await imagesDir.exists()) {
      await for (var img in imagesDir.list()) {
        if (img is File) {
          final fileName = img.uri.pathSegments.last;
          final newPath = '${appImagesDir.path}/$fileName';
          await img.copy(newPath);
          oldToNewPath[fileName] = newPath;
        }
      }
    }
    // 4. 修正数据库中image_path字段
    final db = await openDatabase(dbPath);
    final List<Map<String, dynamic>> items = await db.query('items');
    for (var item in items) {
      final oldPath = item['image_path'] as String?;
      if (oldPath != null && oldPath.isNotEmpty) {
        final fileName = oldPath.split('/').last;
        if (oldToNewPath.containsKey(fileName)) {
          await db.update('items', {'image_path': oldToNewPath[fileName]}, where: 'id = ?', whereArgs: [item['id']]);
        }
      }
    }
    await db.close();
    // 5. 清理临时文件
    await extractDir.delete(recursive: true);
    // 6. 重置数据库连接，避免database_closed
    await DatabaseService().close();
  }
} 