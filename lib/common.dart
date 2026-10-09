import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'i18n.dart';

String two(int n) => n.toString().padLeft(2, '0');
String weekday(DateTime d) => DateFormat.E(appLang).format(d);
String fmtDate(DateTime d) => DateFormat.yMd(appLang).format(d);
String fmtDateW(DateTime d) => DateFormat.yMMMEd(appLang).format(d);
String fmtDateTime(DateTime d) => '${fmtDateW(d)} ${DateFormat.Hm(appLang).format(d)}';
String fmtMonthTitle(DateTime d) => DateFormat.yMMMM(appLang).format(d);
String fmtMonth(DateTime d) => '${d.year}.${two(d.month)}';
bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String dday(DateTime due) {
  final diff = DateUtils.dateOnly(due).difference(DateUtils.dateOnly(DateTime.now())).inDays;
  if (diff == 0) return 'D-DAY';
  return diff > 0 ? 'D-$diff' : 'D+${-diff}';
}

/// 오늘(오늘 아직 안 썼으면 어제)부터 거꾸로 일기가 이어진 날 수
int diaryStreak(Set<DateTime> days, DateTime today) {
  var d = days.contains(today) ? today : DateUtils.dateOnly(today.subtract(const Duration(days: 1)));
  var n = 0;
  while (days.contains(d)) {
    n++;
    d = DateUtils.dateOnly(d.subtract(const Duration(days: 1)));
  }
  return n;
}

T? findById<T>(List<T> list, String id, String Function(T) idOf) {
  for (final e in list) {
    if (idOf(e) == id) return e;
  }
  return null;
}

Future<DateTime?> pickDate(BuildContext context, DateTime? initial) => showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
    );

Future<bool> confirmDialog(
    BuildContext context, String title, String message, String okLabel) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr.cancel)),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(okLabel)),
      ],
    ),
  );
  return r ?? false;
}

InputDecoration deco(String label, {String? hint}) => InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
      alignLabelWithHint: true,
    );

void toast(BuildContext context, String msg, {SnackBarAction? action}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), action: action));
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  final double top;
  const EmptyState({super.key, required this.icon, required this.text, this.top = 64});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 48, color: c),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: c)),
        ),
      ]),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final VoidCallback? onMore;
  const SectionTitle(this.text, {super.key, this.onMore});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Row(children: [
        Text(text,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const Spacer(),
        if (onMore != null) TextButton(onPressed: onMore, child: Text(tr.seeAll)),
      ]),
    );
  }
}

class DateTile extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onPick;
  final VoidCallback? onClear;
  const DateTile(
      {super.key, required this.label, required this.value, required this.onPick, this.onClear});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.event_outlined),
      title: Text(label),
      subtitle: Text(value == null ? tr.notSelected : fmtDateW(value!)),
      trailing: value != null && onClear != null
          ? IconButton(icon: const Icon(Icons.close), onPressed: onClear)
          : null,
      onTap: () async {
        final d = await pickDate(context, value);
        if (d != null) onPick(d);
      },
    );
  }
}

/// 수정 화면에서 저장 안 하고 뒤로 가면 한 번 물어보기
mixin DirtyGuard<T extends StatefulWidget> on State<T> {
  bool dirty = false;

  void markDirty() {
    if (!dirty) setState(() => dirty = true);
  }

  /// "저장하지 않고 나가기"를 골랐을 때 (필요하면 덮어쓰기)
  void onDiscard() {}

  Widget guard(Widget child) => PopScope<Object?>(
        canPop: !dirty,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          final leave = await confirmDialog(context, tr.leaveTitle, tr.leaveBody, tr.leave);
          if (leave && mounted) {
            dirty = false;
            onDiscard();
            Navigator.of(context).pop();
          }
        },
        child: child,
      );
}
