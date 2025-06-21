import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class PhotoGridPickerScreen extends StatefulWidget {
  @override
  _PhotoGridPickerScreenState createState() => _PhotoGridPickerScreenState();
}

class _PhotoGridPickerScreenState extends State<PhotoGridPickerScreen> {
  List<AssetEntity> _photos = [];
  AssetEntity? _selectedPhoto;
  List<AssetPathEntity> _albums = [];
  AssetPathEntity? _currentAlbum;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchAlbumsAndPhotos();
  }

  Future<void> _fetchAlbumsAndPhotos() async {
    setState(() { _loading = true; });
    final permitted = await PhotoManager.requestPermissionExtend();
    if (!permitted.isAuth) {
      setState(() { _loading = false; });
      return;
    }
    final albums = await PhotoManager.getAssetPathList(type: RequestType.image);
    if (albums.isNotEmpty) {
      final photos = await albums[0].getAssetListPaged(page: 0, size: 100);
      setState(() {
        _albums = albums;
        _currentAlbum = albums[0];
        _photos = photos;
        _selectedPhoto = null;
        _loading = false;
      });
    } else {
      setState(() {
        _albums = [];
        _currentAlbum = null;
        _photos = [];
        _selectedPhoto = null;
        _loading = false;
      });
    }
  }

  Future<void> _switchAlbum() async {
    if (_albums.length <= 1) return;
    final idx = _albums.indexOf(_currentAlbum!);
    final nextIdx = (idx + 1) % _albums.length;
    final nextAlbum = _albums[nextIdx];
    final photos = await nextAlbum.getAssetListPaged(page: 0, size: 100);
    setState(() {
      _currentAlbum = nextAlbum;
      _photos = photos;
      _selectedPhoto = null;
    });
  }

  Future<void> _onCameraTap() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera);
    if (picked != null) {
      // 复制到持久目录
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = path.basename(picked.path);
      final savedImage = await File(picked.path).copy('${appDir.path}/$fileName');
      // 保存到相册（可选）
      final asset = await PhotoManager.editor.saveImageWithPath(savedImage.path);
      if (asset != null) {
        setState(() {
          _photos.insert(0, asset);
          _selectedPhoto = asset;
        });
      }
    }
  }

  void _onPhotoTap(AssetEntity photo) {
    setState(() {
      _selectedPhoto = photo;
    });
    photo.file.then((file) {
      if (file != null) {
        showDialog(
          context: context,
          builder: (context) => Dialog(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Image.file(file, fit: BoxFit.contain),
            ),
          ),
        );
      }
    });
  }

  void _onDone() async {
    if (_selectedPhoto != null) {
      final file = await _selectedPhoto!.file;
      if (file != null) {
        // 复制到持久目录
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = path.basename(file.path);
        final savedImage = await File(file.path).copy('${appDir.path}/$fileName');
        Navigator.pop(context, savedImage.path);
      } else {
        Navigator.pop(context, null);
      }
    } else {
      Navigator.pop(context, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('选择照片'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _photos.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          // 左上角拍照按钮
                          return GestureDetector(
                            onTap: _onCameraTap,
                            child: Container(
                              color: Colors.purple[100],
                              child: const Icon(Icons.camera_alt, size: 40, color: Colors.purple),
                            ),
                          );
                        } else {
                          final photo = _photos[index - 1];
                          final isSelected = _selectedPhoto == photo;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedPhoto = photo),
                            onLongPress: () => _onPhotoTap(photo),
                            child: FutureBuilder<Uint8List?>(
                              future: photo.thumbnailDataWithSize(ThumbnailSize(200, 200)),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                                  return Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.memory(snapshot.data!, fit: BoxFit.cover),
                                      if (isSelected)
                                        Container(
                                          color: Colors.black26,
                                          child: const Icon(Icons.check_circle, color: Colors.white, size: 32),
                                        ),
                                    ],
                                  );
                                } else {
                                  return Container(color: Colors.grey[200]);
                                }
                              },
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  // 左下角相册切换按钮
                  if (_albums.length > 1)
                    Positioned(
                      left: 16,
                      bottom: 16,
                      child: FloatingActionButton(
                        heroTag: 'albumSwitch',
                        mini: true,
                        onPressed: _switchAlbum,
                        child: const Icon(Icons.photo_library),
                      ),
                    ),
                  // 右下角完成按钮
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: FloatingActionButton.extended(
                      heroTag: 'done',
                      onPressed: _onDone,
                      label: const Text('完成'),
                      icon: const Icon(Icons.check),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
} 