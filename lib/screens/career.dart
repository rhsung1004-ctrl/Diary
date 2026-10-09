import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../common.dart';
import '../models.dart';
import '../photos.dart';
import '../store.dart';

String careerPeriod(CareerItem c) {
  if (c.startDate == null) return '';
  final end = c.ongoing ? '현재' : (c.endDate == null ? '' : fmtMonth(c.endDate!));
  return end.isEmpty ? fmtMonth(c.startDate!) : '${fmtMonth(c.startDate!)} ~ $end';
}

class CareerScreen extends StatefulWidget {
  const CareerScreen({super.key});

  @override
  State<CareerScreen> createState() => _CareerScreenState();
}

class _CareerScreenState extends State<CareerScreen> {
  final store = AppStore.instance;
  String? _type; // null = 전체

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('커리어 · 포트폴리오')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_career',
        onPressed: () => openCareerEditor(context, null),
        child: const Icon(Icons.add),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final list = store.careers.where((c) => _type == null || c.type == _type).toList()
            ..sort((a, b) {
              // 진행 중 먼저, 그다음 시작일 최신순
              if (a.ongoing != b.ongoing) return a.ongoing ? -1 : 1;
              return (b.startDate ?? b.createdAt).compareTo(a.startDate ?? a.createdAt);
            });
          return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 96), children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final t in <String?>[null, ...careerTypes])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(t ?? '전체'),
                      selected: _type == t,
                      onSelected: (_) => setState(() => _type = t),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 8),
            if (list.isEmpty)
              const EmptyState(icon: Icons.work_outline, text: '프로젝트, 경력, 자격증을 정리해\n나만의 포트폴리오를 만들어 보세요'),
            for (final c in list) CareerCard(item: c),
          ]);
        },
      ),
    );
  }
}

class CareerCard extends StatelessWidget {
  final CareerItem item;
  const CareerCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final c = item;
    final t = Theme.of(context);
    final period = careerPeriod(c);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            Navigator.push(context, MaterialPageRoute(builder: (_) => CareerView(id: c.id))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (c.photos.isNotEmpty)
            Image.file(AppStore.instance.photoFile(c.photos.first),
                height: 140, width: double.infinity, fit: BoxFit.cover, cacheWidth: 1080),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _TypeBadge(c.type),
                const Spacer(),
                if (period.isNotEmpty)
                  Text(period,
                      style: t.textTheme.bodySmall
                          ?.copyWith(color: t.colorScheme.onSurfaceVariant)),
              ]),
              const SizedBox(height: 8),
              Text(c.title,
                  style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              if (c.org.isNotEmpty)
                Text(c.org,
                    style:
                        t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
              if (c.skills.isNotEmpty) ...[
                const SizedBox(height: 8),
                _Skills(c.skills),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge(this.type);

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration:
          BoxDecoration(color: s.tertiaryContainer, borderRadius: BorderRadius.circular(6)),
      child: Text(type,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: s.onTertiaryContainer)),
    );
  }
}

class _Skills extends StatelessWidget {
  final List<String> skills;
  const _Skills(this.skills);

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Wrap(spacing: 6, runSpacing: 6, children: [
      for (final k in skills)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            border: Border.all(color: s.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(k, style: Theme.of(context).textTheme.labelSmall),
        ),
    ]);
  }
}

/// 포트폴리오 상세 보기
class CareerView extends StatelessWidget {
  final String id;
  const CareerView({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final c = findById(store.careers, id, (CareerItem x) => x.id);
        if (c == null) return Scaffold(appBar: AppBar());
        final t = Theme.of(context);
        final period = careerPeriod(c);
        return Scaffold(
          appBar: AppBar(
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => openCareerEditor(context, c),
              ),
            ],
          ),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            _TypeBadge(c.type),
            const SizedBox(height: 8),
            Text(c.title, style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            if (c.org.isNotEmpty) Text(c.org, style: t.textTheme.titleMedium),
            if (period.isNotEmpty)
              Text(period,
                  style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            PhotoGallery(c.photos),
            if (c.photos.isNotEmpty) const SizedBox(height: 16),
            if (c.description.isNotEmpty)
              SelectableText(c.description, style: t.textTheme.bodyLarge?.copyWith(height: 1.6)),
            if (c.skills.isNotEmpty) ...[
              const SectionTitle('기술 · 키워드'),
              _Skills(c.skills),
            ],
            if (c.link.isNotEmpty) ...[
              const SectionTitle('링크'),
              Row(children: [
                Expanded(child: SelectableText(c.link, style: TextStyle(color: t.colorScheme.primary))),
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: c.link));
                    toast(context, '링크를 복사했어요');
                  },
                ),
              ]),
            ],
          ]),
        );
      },
    );
  }
}

Future<void> openCareerEditor(BuildContext context, CareerItem? item) async {
  final deleted = await Navigator.push<bool>(
      context, MaterialPageRoute(builder: (_) => CareerEditor(item: item)));
  if (deleted == true && context.mounted && item != null) Navigator.pop(context);
}

class CareerEditor extends StatefulWidget {
  final CareerItem? item;
  const CareerEditor({super.key, this.item});

  @override
  State<CareerEditor> createState() => _CareerEditorState();
}

class _CareerEditorState extends State<CareerEditor> with DirtyGuard<CareerEditor> {
  late final CareerItem d = widget.item?.copy() ?? CareerItem();
  late final _title = TextEditingController(text: d.title);
  late final _org = TextEditingController(text: d.org);
  late final _desc = TextEditingController(text: d.description);
  late final _skills = TextEditingController(text: d.skills.join(', '));
  late final _link = TextEditingController(text: d.link);
  bool get isNew => widget.item == null;

  @override
  void dispose() {
    for (final c in [_title, _org, _desc, _skills, _link]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      toast(context, '이름을 입력해 주세요');
      return;
    }
    d
      ..title = _title.text.trim()
      ..org = _org.text.trim()
      ..description = _desc.text.trim()
      ..skills = _skills.text
          .split(RegExp(r'[,\n]'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList()
      ..link = _link.text.trim();
    await AppStore.instance.upsertCareer(d);
    dirty = false;
    if (mounted) Navigator.pop(context, false);
  }

  Future<void> _delete() async {
    if (!await confirmDialog(context, '삭제할까요?', '"${d.title}"을(를) 삭제해요.', '삭제')) return;
    await AppStore.instance.removeCareer(d.id);
    dirty = false;
    if (mounted) Navigator.pop(context, true);
  }

  Widget _field(TextEditingController c, String label,
          {String? hint, int minLines = 1, int? maxLines = 1, TextInputType? type}) =>
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
        title: Text(isNew ? '새 항목' : '항목 수정'),
        actions: [
          if (!isNew) IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
          TextButton(onPressed: _save, child: const Text('저장')),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Wrap(spacing: 8, runSpacing: 4, children: [
          for (final t in careerTypes)
            ChoiceChip(
              label: Text(t),
              selected: d.type == t,
              onSelected: (_) {
                setState(() => d.type = t);
                markDirty();
              },
            ),
        ]),
        const SizedBox(height: 16),
        _field(_title, '이름', hint: '예) 개인 일정 관리 앱 개발'),
        _field(_org, '소속 · 역할 (선택)', hint: '예) 개인 프로젝트 / 개발 전담'),
        DateTile(
          label: '시작',
          value: d.startDate,
          onPick: (v) {
            setState(() => d.startDate = v);
            markDirty();
          },
          onClear: () {
            setState(() => d.startDate = null);
            markDirty();
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('진행 중'),
          value: d.ongoing,
          onChanged: (v) {
            setState(() => d.ongoing = v);
            markDirty();
          },
        ),
        if (!d.ongoing)
          DateTile(
            label: '종료',
            value: d.endDate,
            onPick: (v) {
              setState(() => d.endDate = v);
              markDirty();
            },
            onClear: () {
              setState(() => d.endDate = null);
              markDirty();
            },
          ),
        const SizedBox(height: 12),
        _field(_desc, '설명', hint: '무엇을, 왜, 어떻게 했고 결과는 어땠는지', minLines: 5, maxLines: null),
        _field(_skills, '기술 · 키워드 (쉼표로 구분)', hint: 'Flutter, Python, 영상편집'),
        _field(_link, '링크 (선택)', hint: 'GitHub, 블로그, 시연 영상 주소', type: TextInputType.url),
        PhotoEditor(photos: d.photos, label: '이미지 (스크린샷, 결과물, 증명서)', onChanged: markDirty),
        const SizedBox(height: 24),
      ]),
    ));
  }
}
