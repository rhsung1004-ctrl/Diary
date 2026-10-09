import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import 'backup.dart';
import 'common.dart';
import 'prefs.dart';
import 'i18n.dart';

/// 앱 잠금 상태 관리
class AppLock extends ChangeNotifier {
  AppLock._();
  static final AppLock instance = AppLock._();

  static const _grace = Duration(seconds: 10); // 잠깐 나갔다 오면 다시 안 물어봄
  final _auth = LocalAuthentication();
  final _prefs = AppPrefs.instance;

  bool locked = false;
  DateTime? _leftAt;
  int _external = 0;

  void lockOnStart() {
    locked = _prefs.lockEnabled;
  }

  /// 사진 고르기·구글 로그인처럼 잠깐 다른 화면에 갔다 오는 동안은 잠그지 않음
  Future<T> runExternal<T>(Future<T> Function() action) async {
    _external++;
    try {
      return await action();
    } finally {
      _external--;
      _leftAt = null;
    }
  }

  void onLifecycle(AppLifecycleState state) {
    if (!_prefs.lockEnabled || locked) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      if (_external == 0) _leftAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final left = _leftAt;
      _leftAt = null;
      if (left != null && _external == 0 && DateTime.now().difference(left) > _grace) {
        locked = true;
        notifyListeners();
      }
    }
  }

  // ───── PIN ─────
  static String _hash(String salt, String pin) => sha256.convert(utf8.encode('$salt:$pin')).toString();

  bool checkPin(String pin) {
    final salt = _prefs.pinSalt, hash = _prefs.pinHash;
    if (salt == null || hash == null) return false;
    return _hash(salt, pin) == hash;
  }

  Future<void> setPin(String pin, {String? recoveryEmail}) async {
    final r = Random.secure();
    final salt = base64Url.encode(List<int>.generate(16, (_) => r.nextInt(256)));
    await _prefs.update((p) {
      p.pinSalt = salt;
      p.pinHash = _hash(salt, pin);
      p.lockRecoveryEmail = recoveryEmail;
    });
  }

  Future<void> disable() async {
    await _prefs.update((p) {
      p.pinHash = null;
      p.pinSalt = null;
      p.biometric = false;
      p.lockRecoveryEmail = null;
    });
    unlock();
  }

  void unlock() {
    locked = false;
    _leftAt = null;
    notifyListeners();
  }

  // ───── 생체 인증 ─────
  Future<bool> biometricAvailable() async {
    try {
      return await _auth.isDeviceSupported() &&
          await _auth.canCheckBiometrics &&
          (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateBiometric() async {
    try {
      return await runExternal(() => _auth.authenticate(
            localizedReason: tr.lockReason,
            biometricOnly: true,
          ));
    } catch (e) {
      debugPrint('생체 인증 실패: $e');
      return false;
    }
  }
}

/// 잠금 화면 (앱 위에 덮어씌움)
class LockOverlay extends StatelessWidget {
  const LockOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    // 잠금 화면 전용 Navigator는 앱 본 화면의 HeroController를 같이 쓰면 안 됨.
    // (같이 쓰면 잠금을 푼 뒤 새 화면을 열 때 전환이 깨져 검은 화면이 됨)
    return HeroControllerScope.none(
      child: ScaffoldMessenger(
        child: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => const _LockScreen()),
        ),
      ),
    );
  }
}

class _LockScreen extends StatefulWidget {
  const _LockScreen();

  @override
  State<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<_LockScreen> {
  final lock = AppLock.instance;
  String _pin = '';
  String? _error;
  int _fails = 0;
  DateTime? _blockedUntil;
  bool _bio = false;

  @override
  void initState() {
    super.initState();
    if (AppPrefs.instance.biometric) {
      lock.biometricAvailable().then((ok) {
        if (!mounted) return;
        setState(() => _bio = ok);
        if (ok) _tryBiometric();
      });
    }
  }

  Future<void> _tryBiometric() async {
    if (await lock.authenticateBiometric()) lock.unlock();
  }

  void _digit(String d) {
    final until = _blockedUntil;
    if (until != null && DateTime.now().isBefore(until)) {
      setState(() => _error = tr.lockRetryIn(until.difference(DateTime.now()).inSeconds + 1));
      return;
    }
    if (_pin.length >= 4) return;
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length == 4) {
      if (lock.checkPin(_pin)) {
        lock.unlock();
      } else {
        HapticFeedback.heavyImpact();
        _fails++;
        setState(() {
          _pin = '';
          if (_fails >= 5) {
            _blockedUntil = DateTime.now().add(const Duration(seconds: 30));
            _fails = 0;
            _error = tr.lockTooMany;
          } else {
            _error = tr.lockWrong;
          }
        });
      }
    }
  }

  Future<void> _forgot() async {
    final email = AppPrefs.instance.lockRecoveryEmail;
    if (email == null) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(tr.lockForgotTitle),
          content: Text(tr.lockForgotNoAccount),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr.ok))],
        ),
      );
      return;
    }
    final ok = await confirmDialog(context, tr.lockGoogleTitle, tr.lockGoogleBody(email), tr.signIn);
    if (!ok || !mounted) return;
    try {
      final got = await lock.runExternal(BackupService.instance.verifyGoogleAccount);
      if (got != null && got.toLowerCase() == email.toLowerCase()) {
        await lock.disable();
      } else if (mounted) {
        toast(context, tr.lockWrongAccount(email));
      }
    } catch (e) {
      if (mounted) toast(context, backupErrorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          const Spacer(flex: 2),
          Icon(Icons.lock_outline, size: 40, color: t.colorScheme.primary),
          const SizedBox(height: 16),
          Text(tr.lockEnterPin, style: t.textTheme.titleMedium),
          const SizedBox(height: 24),
          PinDots(length: _pin.length),
          SizedBox(
            height: 40,
            child: Center(
              child: Text(_error ?? '', style: TextStyle(color: t.colorScheme.error)),
            ),
          ),
          const Spacer(),
          PinPad(
            onDigit: _digit,
            onBackspace: () => setState(() => _pin = _pin.isEmpty ? '' : _pin.substring(0, _pin.length - 1)),
            extra: _bio
                ? IconButton(
                    iconSize: 32,
                    icon: const Icon(Icons.fingerprint),
                    onPressed: _tryBiometric,
                  )
                : null,
          ),
          TextButton(onPressed: _forgot, child: Text(tr.lockForgot)),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}

class PinDots extends StatelessWidget {
  final int length;
  const PinDots({super.key, required this.length});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      for (var i = 0; i < 4; i++)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < length ? c.primary : Colors.transparent,
            border: Border.all(color: c.primary, width: 2),
          ),
        ),
    ]);
  }
}

class PinPad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final Widget? extra; // 왼쪽 아래 칸 (지문 버튼)
  const PinPad({super.key, required this.onDigit, required this.onBackspace, this.extra});

  Widget _key(BuildContext context, String d) => SizedBox(
        width: 80,
        height: 64,
        child: TextButton(
          onPressed: () => onDigit(d),
          child: Text(d, style: Theme.of(context).textTheme.headlineSmall),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];
    return Column(children: [
      for (final r in rows)
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (final d in r) _key(context, d)]),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(width: 80, height: 64, child: Center(child: extra)),
        _key(context, '0'),
        SizedBox(
          width: 80,
          height: 64,
          child: IconButton(icon: const Icon(Icons.backspace_outlined), onPressed: onBackspace),
        ),
      ]),
    ]);
  }
}

/// 새 PIN 만들기 (두 번 입력). 완료하면 PIN 문자열을 돌려줌
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String _pin = '';
  String? _first;
  String? _error;

  void _digit(String d) {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length < 4) return;
    if (_first == null) {
      setState(() {
        _first = _pin;
        _pin = '';
      });
    } else if (_first == _pin) {
      Navigator.pop(context, _pin);
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _first = null;
        _pin = '';
        _error = tr.pinMismatch;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(tr.pinSetup)),
      body: SafeArea(
        child: Column(children: [
          const Spacer(),
          Text(_first == null ? tr.pinNew : tr.pinAgain,
              style: t.textTheme.titleMedium),
          const SizedBox(height: 24),
          PinDots(length: _pin.length),
          SizedBox(
            height: 40,
            child: Center(child: Text(_error ?? '', style: TextStyle(color: t.colorScheme.error))),
          ),
          const Spacer(),
          PinPad(
            onDigit: _digit,
            onBackspace: () => setState(() => _pin = _pin.isEmpty ? '' : _pin.substring(0, _pin.length - 1)),
          ),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }
}
