import '../models/item.dart';
import 'database_service.dart';

class SearchService {
  final DatabaseService _databaseService = DatabaseService();

  // 基础搜索功能
  Future<List<Item>> searchItems(String query) async {
    return await _databaseService.searchItems(query);
  }

  // 按相关性排序结果
  List<Item> sortByRelevance(List<Item> items, String query) {
    if (query.isEmpty) return items;
    
    // 按名称匹配度排序
    items.sort((a, b) {
      bool aNameContains = a.name.toLowerCase().contains(query.toLowerCase());
      bool bNameContains = b.name.toLowerCase().contains(query.toLowerCase());
      
      if (aNameContains && !bNameContains) return -1;
      if (!aNameContains && bNameContains) return 1;
      
      // 如果名称匹配度相同，按日期排序（新的在前）
      return b.createdAt.compareTo(a.createdAt);
    });
    
    return items;
  }
} 