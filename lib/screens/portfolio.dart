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
import '../i18n.dart';

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
        title: Text(tr.myProfile),
        actions: [TextButton(onPressed: _save, child: Text(tr.save))],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(tr.profileHelp, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 16),
        _field(_name, tr.name),
        _field(_headline, tr.headline, hint: tr.headlineHint),
        _field(_email, tr.optional(tr.email), type: TextInputType.emailAddress),
        _field(_phone, tr.optional(tr.phone), type: TextInputType.phone),
        _field(_link, tr.optional(tr.mainLink), hint: tr.mainLinkHint, type: TextInputType.url),
        _field(_intro, tr.optional(tr.intro), minLines: 4, maxLines: null),
        PhotoEditor(
          photos: _photos,
          label: tr.profilePhoto,
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
      toast(context, tr.pdfPickOne);
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
    final name = store.profile.name;
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => PdfPreviewScreen(
                bytes: bytes,
                fileName: name.isEmpty ? 'portfolio.pdf' : '${name}_${tr.pdfFileSuffix}.pdf')));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final profile = store.profile;
    return Scaffold(
      appBar: AppBar(title: Text(tr.portfolioPdf)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: Text(profile.name.isEmpty ? tr.profileEmpty : profile.name),
            subtitle: Text(profile.isEmpty ? tr.profileEmptySub : profile.headline),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileEditor()));
              setState(() {});
            },
          ),
        ),
        SectionTitle(tr.pdfSections),
        for (final type in portfolioOrder)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(careerTypeLabel(type)),
            subtitle: Text(tr.countItems(_count(type))),
            value: _types.contains(type),
            onChanged: _count(type) == 0
                ? null
                : (v) => setState(() => v == true ? _types.add(type) : _types.remove(type)),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(tr.pdfImages),
          subtitle: Text(tr.pdfImagesSub),
          value: _images,
          onChanged: (v) => setState(() => _images = v),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: Text(tr.pdfMake),
          onPressed: store.careers.isEmpty ? null : _preview,
        ),
        if (store.careers.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(tr.pdfAddCareerFirst, style: t.textTheme.bodySmall),
          ),
      ]),
    );
  }
}

/// PDF 미리보기 + 인쇄 + 공유 (포트폴리오·일기장 공용)
class PdfPreviewScreen extends StatelessWidget {
  final Future<Uint8List> bytes;
  final String fileName;
  const PdfPreviewScreen({super.key, required this.bytes, required this.fileName});

  String get _fileName => fileName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr.preview),
        actions: [
          IconButton(
            tooltip: tr.print,
            icon: const Icon(Icons.print_outlined),
            onPressed: () async {
              final b = await bytes;
              await AppLock.instance.runExternal(() => Printing.layoutPdf(onLayout: (_) async => b, name: _fileName));
            },
          ),
          IconButton(
            tooltip: tr.shareSave,
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
