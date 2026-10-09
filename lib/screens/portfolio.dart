import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../common.dart';
import '../lock.dart';
import '../models.dart';
import '../photos.dart';
import '../portfolio_pdf.dart';
import '../prefs.dart';
import '../store.dart';
import '../theme.dart';

/// 내 프로필 (포트폴리오 표지)
class ProfileEditor extends StatefulWidget {
  const ProfileEditor({super.key});

  @override
  State<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<ProfileEditor> with DirtyGuard<ProfileEditor> {
  late final Profile d = AppStore.instance.profile.copy();
  late final List<String> _photos = [if (d.photo.isNotEmpty) d.photo];
  late final _name = TextEditingController(text: d.name);
  late final _headline = TextEditingController(text: d.headline);
  late final _email = TextEditingController(text: d.email);
  late final _phone = TextEditingController(text: d.phone);
  late final _link = TextEditingController(text: d.link);
  late final _intro = TextEditingController(text: d.intro);

  @override
  void dispose() {
    for (final c in [_name, _headline, _email, _phone, _link, _intro]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    d
      ..name = _name.text.trim()
      ..headline = _headline.text.trim()
      ..email = _email.text.trim()
      ..phone = _phone.text.trim()
      ..link = _link.text.trim()
      ..intro = _intro.text.trim()
      ..photo = _photos.isEmpty ? '' : _photos.last;
    await AppStore.instance.saveProfile(d);
    dirty = false;
    if (mounted) Navigator.pop(context);
  }

  Widget _field(TextEditingController c, String label,
          {String? hint, int? maxLines = 1, int minLines = 1, TextInputType? type}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          minLines: minLines,
          maxLines: maxLines,
          keyboardType: type,
          decoration: deco(label, hint: hint),
          onChanged: (_) => markDirty(),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return guard(Scaffold(
      appBar: AppBar(
        title: const Text('내 프로필'),
        actions: [TextButton(onPressed: _save, child: const Text('저장'))],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('포트폴리오 PDF의 첫 부분에 들어가요.', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 16),
        _field(_name, '이름'),
        _field(_headline, '한 줄 소개', hint: '예) 사용자 경험을 고민하는 앱 개발자'),
        _field(_email, '이메일 (선택)', type: TextInputType.emailAddress),
        _field(_phone, '연락처 (선택)', type: TextInputType.phone),
        _field(_link, '대표 링크 (선택)', hint: 'GitHub, 블로그, 노션 등', type: TextInputType.url),
        _field(_intro, '자기소개 (선택)', minLines: 4, maxLines: null),
        PhotoEditor(
          photos: _photos,
          label: '프로필 사진 (마지막에 추가한 1장 사용)',
          onChanged: markDirty,
        ),
      ]),
    ));
  }
}

/// PDF 만들기 옵션
class PortfolioExportScreen extends StatefulWidget {
  const PortfolioExportScreen({super.key});

  @override
  State<PortfolioExportScreen> createState() => _PortfolioExportScreenState();
}

class _PortfolioExportScreenState extends State<PortfolioExportScreen> {
  final store = AppStore.instance;
  late final Set<String> _types = {
    for (final t in portfolioOrder)
      if (store.careers.any((c) => c.type == t)) t,
  };
  bool _images = true;

  int _count(String type) => store.careers.where((c) => c.type == type).length;

  void _preview() {
    if (_types.isEmpty) {
      toast(context, '넣을 항목을 하나 이상 골라 주세요');
      return;
    }
    final prefs = AppPrefs.instance;
    final bytes = buildPortfolioPdf(
      profile: store.profile,
      items: store.careers,
      types: Set.of(_types),
      includeImages: _images,
      accentArgb: themeColors[prefs.colorIndex.clamp(0, themeColors.length - 1)].seed.toARGB32(),
    );
    Navigator.push(context, MaterialPageRoute(builder: (_) => _PdfPreviewScreen(bytes: bytes)));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final profile = store.profile;
    return Scaffold(
      appBar: AppBar(title: const Text('포트폴리오 PDF')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: Text(profile.name.isEmpty ? '프로필이 비어 있어요' : profile.name),
            subtitle: Text(profile.isEmpty ? '이름과 소개를 넣으면 PDF 맨 위에 들어가요' : profile.headline),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileEditor()));
              setState(() {});
            },
          ),
        ),
        const SectionTitle('넣을 항목'),
        for (final type in portfolioOrder)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(type),
            subtitle: Text('${_count(type)}개'),
            value: _types.contains(type),
            onChanged: _count(type) == 0
                ? null
                : (v) => setState(() => v == true ? _types.add(type) : _types.remove(type)),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('이미지 포함'),
          subtitle: const Text('항목마다 최대 3장'),
          value: _images,
          onChanged: (v) => setState(() => _images = v),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('PDF 만들기'),
          onPressed: store.careers.isEmpty ? null : _preview,
        ),
        if (store.careers.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('커리어 항목을 먼저 추가해 주세요', style: t.textTheme.bodySmall),
          ),
      ]),
    );
  }
}

class _PdfPreviewScreen extends StatelessWidget {
  final Future<Uint8List> bytes;
  const _PdfPreviewScreen({required this.bytes});

  String get _fileName {
    final name = AppStore.instance.profile.name;
    return name.isEmpty ? 'portfolio.pdf' : '${name}_포트폴리오.pdf';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('미리보기'),
        actions: [
          IconButton(
            tooltip: '인쇄',
            icon: const Icon(Icons.print_outlined),
            onPressed: () async {
              final b = await bytes;
              await AppLock.instance.runExternal(() => Printing.layoutPdf(onLayout: (_) async => b, name: _fileName));
            },
          ),
          IconButton(
            tooltip: '공유·저장',
            icon: const Icon(Icons.share_outlined),
            onPressed: () async {
              final b = await bytes;
              await AppLock.instance.runExternal(() => Printing.sharePdf(bytes: b, filename: _fileName));
            },
          ),
        ],
      ),
      body: PdfPreview(
        build: (_) => bytes,
        allowPrinting: false,
        allowSharing: false,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        pdfFileName: _fileName,
      ),
    );
  }
}
