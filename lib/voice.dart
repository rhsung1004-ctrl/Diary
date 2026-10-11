import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';

import 'common.dart';
import 'i18n.dart';
import 'lock.dart';
import 'models.dart';
import 'store.dart';

const _maxLength = Duration(minutes: 10);

String fmtVoiceLength(int ms) {
  final s = (ms / 1000).round();
  return '${s ~/ 60}:${two(s % 60)}';
}

// ───────────────────────── 재생 ─────────────────────────

/// 앱 전체에서 하나만 재생 (다른 메모를 누르면 이전 것은 멈춤)
class VoicePlayback extends ChangeNotifier {
  VoicePlayback._();
  static final VoicePlayback instance = VoicePlayback._();

  AudioPlayer? _player;
  String? current;
  bool playing = false;
  Duration position = Duration.zero;
  Duration? duration;

  AudioPlayer get _p {
    final existing = _player;
    if (existing != null) return existing;
    final p = AudioPlayer();
    p.onPositionChanged.listen((d) {
      position = d;
      notifyListeners();
    });
    p.onDurationChanged.listen((d) {
      duration = d;
      notifyListeners();
    });
    p.onPlayerComplete.listen((_) {
      playing = false;
      position = Duration.zero;
      notifyListeners();
    });
    return _player = p;
  }

  Future<void> toggle(String file) async {
    try {
      if (current == file) {
        if (playing) {
          await _p.pause();
          playing = false;
        } else {
          await _p.resume();
          playing = true;
        }
      } else {
        await _p.stop();
        current = file;
        position = Duration.zero;
        duration = null;
        playing = true;
        notifyListeners();
        await _p.play(DeviceFileSource(AppStore.instance.photoFile(file).path));
      }
    } catch (e) {
      debugPrint('재생 실패: $e');
      playing = false;
    }
    notifyListeners();
  }

  Future<void> seek(Duration d) async {
    await _p.seek(d);
    position = d;
    notifyListeners();
  }

  Future<void> stop() async {
    if (current == null) return;
    current = null;
    playing = false;
    position = Duration.zero;
    notifyListeners();
    await _player?.stop();
  }
}

/// 음성 메모 하나 (재생 버튼 + 진행 막대 + 길이)
class VoiceTile extends StatelessWidget {
  final VoiceMemo memo;
  final VoidCallback? onDelete;
  const VoiceTile(this.memo, {super.key, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final pb = VoicePlayback.instance;
    return ListenableBuilder(
      listenable: pb,
      builder: (context, _) {
        final active = pb.current == memo.file;
        final playing = active && pb.playing;
        final totalMs = active && pb.duration != null && pb.duration!.inMilliseconds > 0
            ? pb.duration!.inMilliseconds
            : memo.ms;
        final posMs = active ? pb.position.inMilliseconds.clamp(0, totalMs) : 0;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
          decoration: BoxDecoration(
            color: t.colorScheme.secondaryContainer.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(children: [
            IconButton(
              tooltip: playing ? tr.voicePause : tr.voicePlay,
              icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
                  size: 36, color: t.colorScheme.primary),
              onPressed: () => pb.toggle(memo.file),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: SliderComponentShape.noOverlay,
                ),
                child: Slider(
                  value: totalMs == 0 ? 0 : posMs / totalMs,
                  onChanged: !active || totalMs == 0
                      ? null
                      : (v) => pb.seek(Duration(milliseconds: (v * totalMs).round())),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(active && posMs > 0 ? '${fmtVoiceLength(posMs)} / ${fmtVoiceLength(totalMs)}' : fmtVoiceLength(totalMs),
                style: t.textTheme.labelMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
            if (onDelete != null)
              IconButton(
                tooltip: tr.delete,
                icon: const Icon(Icons.close, size: 20),
                onPressed: onDelete,
              )
            else
              const SizedBox(width: 12),
          ]),
        );
      },
    );
  }
}

/// 보기 화면용 목록. 화면을 나가면 재생을 멈춤
class VoiceList extends StatefulWidget {
  final List<VoiceMemo> voices;
  const VoiceList(this.voices, {super.key});

  @override
  State<VoiceList> createState() => _VoiceListState();
}

class _VoiceListState extends State<VoiceList> {
  @override
  void dispose() {
    final pb = VoicePlayback.instance;
    if (widget.voices.any((v) => v.file == pb.current)) pb.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.voices.isEmpty) return const SizedBox.shrink();
    return Column(children: [for (final v in widget.voices) VoiceTile(v)]);
  }
}

// ───────────────────────── 편집 ─────────────────────────

/// 편집 화면용: 녹음 추가, 재생, 삭제
class VoiceEditor extends StatefulWidget {
  final List<VoiceMemo> voices; // 이 리스트를 직접 수정함
  final VoidCallback? onChanged;
  const VoiceEditor({super.key, required this.voices, this.onChanged});

  @override
  State<VoiceEditor> createState() => _VoiceEditorState();
}

class _VoiceEditorState extends State<VoiceEditor> {
  @override
  void dispose() {
    final pb = VoicePlayback.instance;
    if (widget.voices.any((v) => v.file == pb.current)) pb.stop();
    super.dispose();
  }

  Future<void> _record() async {
    await VoicePlayback.instance.stop();
    if (!mounted) return;
    final memo = await recordVoice(context);
    if (memo == null || !mounted) return;
    setState(() => widget.voices.add(memo));
    widget.onChanged?.call();
  }

  Future<void> _delete(int i) async {
    if (!await confirmDialog(context, tr.voiceDeleteTitle, tr.cannotUndo, tr.delete)) return;
    final memo = widget.voices[i];
    if (VoicePlayback.instance.current == memo.file) await VoicePlayback.instance.stop();
    setState(() => widget.voices.removeAt(i));
    widget.onChanged?.call(); // 파일은 다음 실행 때 정리됨 (임시 저장과 겹칠 수 있어서)
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(tr.voiceMemo, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      for (var i = 0; i < widget.voices.length; i++)
        VoiceTile(widget.voices[i], onDelete: () => _delete(i)),
      OutlinedButton.icon(
        icon: const Icon(Icons.mic_none),
        label: Text(tr.voiceRecord),
        onPressed: _record,
      ),
    ]);
  }
}

/// 녹음 시트를 띄우고, 저장하면 메모를 돌려줌
Future<VoiceMemo?> recordVoice(BuildContext context) async {
  final rec = AudioRecorder();
  try {
    final ok = await AppLock.instance.runExternal(rec.hasPermission);
    if (!ok) {
      if (context.mounted) toast(context, tr.voiceNoPermission);
      return null;
    }
    if (!context.mounted) return null;
    return await showModalBottomSheet<VoiceMemo>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      showDragHandle: false,
      builder: (_) => PopScope(canPop: false, child: _RecorderSheet(rec)),
    );
  } catch (e) {
    debugPrint('녹음 실패: $e');
    if (context.mounted) toast(context, tr.voiceFail);
    return null;
  } finally {
    unawaited(rec.dispose());
  }
}

class _RecorderSheet extends StatefulWidget {
  final AudioRecorder rec;
  const _RecorderSheet(this.rec);

  @override
  State<_RecorderSheet> createState() => _RecorderSheetState();
}

class _RecorderSheetState extends State<_RecorderSheet> {
  final _watch = Stopwatch();
  final _levels = <double>[];
  late final String _name = AppStore.instance.newVoiceName();
  Timer? _tick;
  StreamSubscription<Amplitude>? _ampSub;
  bool _started = false;
  bool _paused = false;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      await widget.rec.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 44100, numChannels: 1),
        path: AppStore.instance.photoFile(_name).path,
      );
      _watch.start();
      _ampSub = widget.rec.onAmplitudeChanged(const Duration(milliseconds: 100)).listen((a) {
        if (_paused) return;
        // -60dB(조용함) ~ 0dB(큼) → 0~1
        final v = ((a.current + 60) / 60).clamp(0.05, 1.0).toDouble();
        _levels.add(v);
        if (_levels.length > 60) _levels.removeAt(0);
      });
      _tick = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (!mounted) return;
        if (_watch.elapsed >= _maxLength) {
          _finish(save: true);
          return;
        }
        setState(() {});
      });
      if (mounted) setState(() => _started = true);
    } catch (e) {
      debugPrint('녹음 시작 실패: $e');
      if (mounted) {
        toast(context, tr.voiceFail);
        Navigator.pop(context);
      }
    }
  }

  Future<void> _togglePause() async {
    if (_paused) {
      await widget.rec.resume();
      _watch.start();
    } else {
      await widget.rec.pause();
      _watch.stop();
    }
    setState(() => _paused = !_paused);
  }

  Future<void> _finish({required bool save}) async {
    if (_finishing) return;
    _finishing = true;
    _tick?.cancel();
    await _ampSub?.cancel();
    _watch.stop();
    final ms = _watch.elapsedMilliseconds;
    String? path;
    try {
      path = await widget.rec.stop();
    } catch (e) {
      debugPrint('녹음 정지 실패: $e');
    }
    final file = AppStore.instance.photoFile(_name);
    final keep = save && path != null && ms >= 500 && await file.exists();
    if (!keep) {
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
    if (!mounted) return;
    if (save && !keep) toast(context, tr.voiceTooShort);
    Navigator.pop(context, keep ? VoiceMemo(_name, ms) : null);
  }

  @override
  void dispose() {
    _tick?.cancel();
    _ampSub?.cancel();
    // 시트가 다른 이유로 닫혀도 녹음은 멈춤
    if (!_finishing) {
      widget.rec.stop().then((_) async {
        final f = File(AppStore.instance.photoFile(_name).path);
        if (await f.exists()) await f.delete();
      }).catchError((Object _) {});
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final ms = _watch.elapsedMilliseconds;
    final left = _maxLength.inMilliseconds - ms;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.fiber_manual_record,
                size: 14, color: _paused || !_started ? t.colorScheme.outline : Colors.redAccent),
            const SizedBox(width: 6),
            Text(_paused ? tr.voicePaused : tr.voiceRecording, style: t.textTheme.titleMedium),
          ]),
          const SizedBox(height: 12),
          Text(fmtVoiceLength(ms),
              style: t.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w300, fontFeatures: const [FontFeature.tabularFigures()])),
          const SizedBox(height: 16),
          SizedBox(
            height: 56,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (var i = 0; i < 60; i++)
                  Container(
                    width: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    height: 4 + 52 * (i < 60 - _levels.length ? 0.05 : _levels[i - (60 - _levels.length)]),
                    decoration: BoxDecoration(
                      color: t.colorScheme.primary.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(left < 60000 ? tr.voiceLeft(fmtVoiceLength(left)) : tr.voiceMax,
              style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: TextButton(
                onPressed: _finishing ? null : () => _finish(save: false),
                child: Text(tr.cancel),
              ),
            ),
            IconButton.filledTonal(
              iconSize: 32,
              tooltip: _paused ? tr.voiceResume : tr.voicePause,
              onPressed: !_started || _finishing ? null : _togglePause,
              icon: Icon(_paused ? Icons.mic : Icons.pause),
            ),
            Expanded(
              child: TextButton(
                onPressed: !_started || _finishing ? null : () => _finish(save: true),
                child: Text(tr.save),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
