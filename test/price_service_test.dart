import 'package:flutter_test/flutter_test.dart';
import 'package:lo/api/price_adapter.dart';
import 'package:lo/models/gold_price.dart';
import 'package:lo/services/price_service.dart';

class _FakeAdapter implements PriceAdapter {
  _FakeAdapter(this.sourceKey, {this.prices = const [], this.fail = false, this.available = true});

  @override
  final String sourceKey;
  final List<GoldPrice> prices;
  final bool fail;
  final bool available;
  final List<String> log = [];
  static final calls = <String>[];

  @override
  String get displayName => sourceKey;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<List<GoldPrice>> fetchPrices() async {
    calls.add(sourceKey);
    if (fail) throw Exception('chi tiết lỗi kỹ thuật không được lộ ra UI');
    return prices;
  }

  @override
  Future<List<PriceHistoryEntry>> fetchPriceHistory(String goldTypeId,
          {int days = 30}) async =>
      [];
}

class _MemoryStorage implements PriceCacheStorage {
  PriceCacheSnapshot? saved;

  @override
  Future<PriceCacheSnapshot?> load() async => saved;

  @override
  Future<void> save(PriceCacheSnapshot snapshot) async => saved = snapshot;
}

GoldPrice _price(String type, double buy, String source) => GoldPrice(
      id: '$type-$source',
      goldTypeId: type,
      buyPrice: buy,
      sellPrice: buy + 1000,
      source: source,
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  setUp(() => _FakeAdapter.calls.clear());

  test('thử adapter active trước, rồi các adapter khác theo thứ tự đăng ký', () async {
    final a = _FakeAdapter('a', fail: true);
    final b = _FakeAdapter('b', fail: true);
    final c = _FakeAdapter('c', prices: [_price('sjc', 100, 'c')]);
    final d = _FakeAdapter('d', prices: [_price('sjc', 999, 'd')]);
    final service = PriceService.forTest()
      ..registerAdapter(a)
      ..registerAdapter(b)
      ..registerAdapter(c)
      ..registerAdapter(d)
      ..setActiveAdapter('b');

    final result = await service.fetchCurrentPrices();

    expect(_FakeAdapter.calls, ['b', 'a', 'c']); // dừng ở c, không gọi d
    expect(result.single.source, 'c');
    expect(service.status, PriceSourceStatus.fresh);
    expect(service.getBuyPrice('sjc'), 100);
    expect(service.lastUpdated, isNotNull);
  });

  test('adapter trả list rỗng hoặc không khả dụng thì bị bỏ qua', () async {
    final empty = _FakeAdapter('empty');
    final off = _FakeAdapter('off', available: false);
    final ok = _FakeAdapter('ok', prices: [_price('sjc', 5, 'ok')]);
    final service = PriceService.forTest()
      ..registerAdapter(empty)
      ..registerAdapter(off)
      ..registerAdapter(ok)
      ..setActiveAdapter('empty');

    await service.fetchCurrentPrices();

    expect(_FakeAdapter.calls, ['empty', 'ok']);
    expect(service.getBuyPrice('sjc'), 5);
  });

  test('mọi nguồn lỗi: giữ giá cũ, status stale, thông báo không lộ exception', () async {
    final ok = _FakeAdapter('ok', prices: [_price('sjc', 100, 'ok')]);
    final service = PriceService.forTest()..registerAdapter(ok)..setActiveAdapter('ok');
    await service.fetchCurrentPrices();
    final firstUpdate = service.lastUpdated;

    final bad = _FakeAdapter('bad', fail: true);
    final failing = PriceService.forTest(storage: _MemoryStorage()..saved = PriceCacheSnapshot(
      prices: [_price('sjc', 100, 'ok')],
      fetchedAt: firstUpdate!,
    ))
      ..registerAdapter(bad)
      ..setActiveAdapter('bad');
    await failing.loadCachedPrices();
    final result = await failing.fetchCurrentPrices();

    expect(result.single.buyPrice, 100);
    expect(failing.getBuyPrice('sjc'), 100);
    expect(failing.status, PriceSourceStatus.stale);
    expect(failing.lastUpdated, firstUpdate);
    expect(failing.statusMessage, isNot(contains('Exception')));
    expect(failing.statusMessage, isNot(contains('kỹ thuật')));
  });

  test('lỗi sau khi đã có giá trong cùng phiên cũng trả giá cũ + stale', () async {
    var fail = false;
    final flaky = _SwitchableAdapter(() => fail, [_price('sjc', 70, 'f')]);
    final service = PriceService.forTest()
      ..registerAdapter(flaky)
      ..setActiveAdapter('flaky');

    await service.fetchCurrentPrices();
    expect(service.status, PriceSourceStatus.fresh);

    fail = true;
    final result = await service.fetchCurrentPrices();
    expect(result.single.buyPrice, 70);
    expect(service.status, PriceSourceStatus.stale);
  });

  test('lỗi và chưa có cache: status error, danh sách rỗng, không lộ exception', () async {
    final bad = _FakeAdapter('bad', fail: true);
    final service = PriceService.forTest()
      ..registerAdapter(bad)
      ..setActiveAdapter('bad');

    final result = await service.fetchCurrentPrices();

    expect(result, isEmpty);
    expect(service.status, PriceSourceStatus.error);
    expect(service.statusMessage, isNot(contains('Exception')));
    expect(service.lastUpdated, isNull);
  });

  test('lưu giá thành công và nạp lại ở lần khởi động sau (stale tới khi fetch xong)', () async {
    final storage = _MemoryStorage();
    final first = PriceService.forTest(storage: storage)
      ..registerAdapter(_FakeAdapter('ok', prices: [_price('sjc', 42, 'ok')]))
      ..setActiveAdapter('ok');
    await first.fetchCurrentPrices();
    expect(storage.saved, isNotNull);

    final second = PriceService.forTest(storage: storage);
    await second.loadCachedPrices();
    expect(second.getBuyPrice('sjc'), 42);
    expect(second.status, PriceSourceStatus.stale);
    expect(second.lastUpdated, storage.saved!.fetchedAt);
  });

  test('GoldPrice toMap/fromMap round-trip', () {
    final p = _price('sjc', 123, 'x');
    final back = GoldPrice.fromMap(p.toMap());
    expect(back.buyPrice, 123);
    expect(back.goldTypeId, 'sjc');
    expect(back.updatedAt, p.updatedAt);
  });
}

class _SwitchableAdapter extends _FakeAdapter {
  _SwitchableAdapter(this._shouldFail, List<GoldPrice> prices)
      : super('flaky', prices: prices);
  final bool Function() _shouldFail;

  @override
  Future<List<GoldPrice>> fetchPrices() async {
    if (_shouldFail()) throw Exception('mất mạng');
    return prices;
  }
}
