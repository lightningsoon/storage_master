import 'package:flutter/material.dart';
import '../models/item.dart';
import '../services/database_service.dart';
import '../services/search_service.dart';
import 'item_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _nameController = TextEditingController();
  List<Item> _results = [];
  bool _isLoading = false;

  final SearchService _searchService = SearchService();
  final DatabaseService _databaseService = DatabaseService();

  @override
  void initState() {
    super.initState();
  }

  Future<void> _search() async {
    setState(() {
      _isLoading = true;
    });
    final results = await _searchService.searchItems(_nameController.text.trim());
    setState(() {
      _results = _searchService.sortByRelevance(results, _nameController.text.trim());
      _isLoading = false;
    });
  }

  void _clearFilters() {
    setState(() {
      _nameController.clear();
      _results = [];
    });
  }

  Widget _buildResultList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_results.isEmpty) {
      return const Center(child: Text('没有找到相关物品'));
    }
    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final item = _results[index];
        return ListTile(
          title: Text(item.name),
          subtitle: item.category != null ? Text('类别: ${item.category}') : null,
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ItemDetailScreen(item: item)),
            );
            if (result == true) {
              _search();
            }
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('物品搜索'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: _clearFilters,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: '物品名称',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _search,
                  child: const Text('搜索'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Expanded(child: _buildResultList()),
          ],
        ),
      ),
    );
  }
} 