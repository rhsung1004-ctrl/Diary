import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'common.dart';
import 'store.dart';

/// 정사각형 썸네일
class PhotoThumb extends StatelessWidget {
  final String name;
  final double size;
  const PhotoThumb(this.name, {super.key, this.size = 56});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(
        AppStore.instance.photoFile(name),
        key: ValueKey(name),
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: (size * 3).round(),
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Icon(Icons.broken_image_outlined),
        ),
      ),
    );
  }
}

/// 편집 화면용: 사진 추가(갤러리 여러 장 / 카메라), 삭제
class PhotoEditor extends StatefulWidget {
  final List<String> photos; // 이 리스트를 직접 수정함
  final String label;
  final VoidCallback? onChanged;
  const PhotoEditor({super.key, required this.photos, this.label = '사진', this.onChanged});

  @override
  State<PhotoEditor> createState() => _PhotoEditorState();
}

class _PhotoEditorState extends State<PhotoEditor> {
  final _picker = ImagePicker();
  bool _busy = false;

  Future<void> _add(ImageSource src) async {
    try {
      List<XFile> files;
      if (src == ImageSource.gallery) {
        files = await _picker.pickMultiImage(imageQuality: 85, maxWidth: 2048, maxHeight: 2048);
      } else {
        final f = await _picker.pickImage(
            source: src, imageQuality: 85, maxWidth: 2048, maxHeight: 2048);
        files = f == null ? <XFile>[] : [f];
      }
      if (files.isEmpty) return;
      setState(() => _busy = true);
      for (final f in files) {
        widget.photos.add(await AppStore.instance.importPhoto(f.path));
      }
      widget.onChanged?.call();
    } catch (e) {
      if (mounted) toast(context, '사진을 불러오지 못했어요: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _chooseSource() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('갤러리에서 선택'),
            onTap: () {
              Navigator.pop(ctx);
              _add(ImageSource.gallery);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('카메라로 찍기'),
            onTap: () {
              Navigator.pop(ctx);
              _add(ImageSource.camera);
            },
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final photos = widget.photos;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.label, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      SizedBox(
        height: 96,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          for (var i = 0; i < photos.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Stack(children: [
                GestureDetector(
                  onTap: () => openPhotoViewer(context, photos, i),
                  child: PhotoThumb(photos[i], size: 96),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: InkWell(
                    onTap: () {
                      setState(() => photos.removeAt(i));
                      widget.onChanged?.call();
                    },
                    child: const CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.black54,
                      child: Icon(Icons.close, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ]),
            ),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _busy ? null : _chooseSource,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: _busy
                  ? const Center(child: CircularProgressIndicator())
                  : Icon(Icons.add_a_photo_outlined, color: scheme.primary),
            ),
          ),
        ]),
      ),
    ]);
  }
}

/// 보기 화면용 사진 묶음 (1장이면 크게, 여러 장이면 3열 격자)
class PhotoGallery extends StatelessWidget {
  final List<String> photos;
  const PhotoGallery(this.photos, {super.key});

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) return const SizedBox.shrink();
    if (photos.length == 1) {
      return GestureDetector(
        onTap: () => openPhotoViewer(context, photos, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(AppStore.instance.photoFile(photos.first),
              width: double.infinity, fit: BoxFit.cover, cacheWidth: 1440),
        ),
      );
    }
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      children: [
        for (var i = 0; i < photos.length; i++)
          GestureDetector(
            onTap: () => openPhotoViewer(context, photos, i),
            child: LayoutBuilder(
              builder: (_, c) => PhotoThumb(photos[i], size: c.maxWidth),
            ),
          ),
      ],
    );
  }
}

void openPhotoViewer(BuildContext context, List<String> photos, int index) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => _PhotoViewer(photos: List.of(photos), initial: index)),
  );
}

class _PhotoViewer extends StatefulWidget {
  final List<String> photos;
  final int initial;
  const _PhotoViewer({required this.photos, required this.initial});

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late int _index = widget.initial;
  late final _ctl = PageController(initialPage: widget.initial);

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_index + 1} / ${widget.photos.length}'),
      ),
      body: PageView.builder(
        controller: _ctl,
        itemCount: widget.photos.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) => InteractiveViewer(
          maxScale: 5,
          child: Center(
            child: Image.file(AppStore.instance.photoFile(widget.photos[i]), fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
