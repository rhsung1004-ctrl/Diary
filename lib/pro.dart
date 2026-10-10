import 'dart:async';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'common.dart';
import 'config.dart';
import 'i18n.dart';
import 'lock.dart';
import 'prefs.dart';

/// 프로(평생 이용권) 결제 상태
/// 서버가 없는 앱이라 구글 플레이가 알려주는 구매 내역을 기기에 기억해 두고,
/// 앱을 켤 때마다 구매 복원으로 다시 확인함.
class ProService extends ChangeNotifier {
  ProService._();
  static final ProService instance = ProService._();

  final _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  ProductDetails? product;
  bool available = false;
  bool busy = false;
  bool _restoring = false;
  bool _restoredSomething = false;
  void Function(String message)? onMessage; // 화면에 알림 띄우기

  /// 프로 기능을 쓸 수 있는지 (잠금 스위치가 꺼져 있으면 항상 true)
  bool get isPro => !kProGateEnabled || AppPrefs.instance.isPro;

  Future<void> init() async {
    try {
      _sub = _iap.purchaseStream.listen(_onPurchases, onError: (Object e) => debugPrint('결제 오류: $e'));
      available = await _iap.isAvailable();
      if (!available) return;
      final res = await _iap.queryProductDetails({kProProductId});
      if (res.productDetails.isNotEmpty) product = res.productDetails.first;
      notifyListeners();
      // 다른 폰·재설치 후에도 프로 유지
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('결제 초기화 실패: $e');
    }
  }

  String get priceLabel => product?.price ?? '₩3,900';

  Future<void> buy() async {
    if (!available || product == null) {
      onMessage?.call(tr.proUnavailable);
      return;
    }
    busy = true;
    notifyListeners();
    try {
      await AppLock.instance.runExternal(
          () => _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: product!)));
    } catch (e) {
      busy = false;
      notifyListeners();
      onMessage?.call(tr.proFailed);
    }
  }

  Future<void> restore() async {
    if (!available) {
      onMessage?.call(tr.proUnavailable);
      return;
    }
    _restoring = true;
    _restoredSomething = false;
    busy = true;
    notifyListeners();
    await _iap.restorePurchases();
    // 복원 결과는 스트림으로 오므로 잠깐 기다렸다가 안내
    await Future<void>.delayed(const Duration(seconds: 3));
    if (_restoring) {
      _restoring = false;
      busy = false;
      notifyListeners();
      onMessage?.call(_restoredSomething ? tr.proRestored : tr.proNothing);
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      if (p.productID != kProProductId) continue;
      switch (p.status) {
        case PurchaseStatus.pending:
          onMessage?.call(tr.proPending);
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final wasPro = AppPrefs.instance.isPro;
          await AppPrefs.instance.update((x) => x.isPro = true);
          _restoredSomething = true;
          if (p.status == PurchaseStatus.purchased && !wasPro) onMessage?.call(tr.proThanks);
        case PurchaseStatus.error:
          onMessage?.call(tr.proFailed);
        case PurchaseStatus.canceled:
          break;
      }
      if (p.pendingCompletePurchase) {
        await _iap.completePurchase(p);
      }
    }
    if (!_restoring) busy = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// 프로 기능을 쓰기 전에 호출: 프로면 true, 아니면 프로 화면을 보여주고 결과를 돌려줌
Future<bool> requirePro(BuildContext context) async {
  final pro = ProService.instance;
  if (pro.isPro) return true;
  await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const ProScreen()));
  return pro.isPro;
}

/// 잠긴 항목 옆에 붙이는 작은 자물쇠
class ProBadge extends StatelessWidget {
  const ProBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppPrefs.instance,
      builder: (context, _) => ProService.instance.isPro
          ? const SizedBox.shrink()
          : Icon(Icons.lock_outline, size: 16, color: Theme.of(context).colorScheme.tertiary),
    );
  }
}

class ProScreen extends StatefulWidget {
  const ProScreen({super.key});

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  final pro = ProService.instance;

  @override
  void initState() {
    super.initState();
    pro.onMessage = (m) {
      if (mounted) toast(context, m);
    };
  }

  @override
  void dispose() {
    pro.onMessage = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: ListenableBuilder(
        listenable: Listenable.merge([pro, AppPrefs.instance]),
        builder: (context, _) {
          final benefits = [tr.proB1, tr.proB2, tr.proB3, tr.proB4, tr.proB5, tr.proB6];
          return ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 32), children: [
            const Center(child: Text('💎', style: TextStyle(fontSize: 64))),
            const SizedBox(height: 12),
            Text(tr.proName,
                textAlign: TextAlign.center,
                style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(tr.proTagline,
                textAlign: TextAlign.center,
                style: t.textTheme.bodyLarge?.copyWith(color: t.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 24),
            Card(
              elevation: 0,
              color: t.colorScheme.surfaceContainerHigh,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(children: [
                  for (final b in benefits)
                    ListTile(dense: true, title: Text(b, style: t.textTheme.bodyLarge)),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            Text(tr.proFree,
                textAlign: TextAlign.center,
                style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 24),
            if (AppPrefs.instance.isPro)
              Card(
                elevation: 0,
                color: t.colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(tr.proActive, textAlign: TextAlign.center, style: t.textTheme.titleMedium),
                ),
              )
            else ...[
              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: pro.busy ? null : pro.buy,
                  child: pro.busy
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(tr.proBuy(pro.priceLabel), style: const TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: pro.busy ? null : pro.restore, child: Text(tr.proRestore)),
            ],
          ]);
        },
      ),
    );
  }
}
