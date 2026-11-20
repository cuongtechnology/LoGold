import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lo/api/cafef_price_adapter.dart';
import 'package:lo/api/pnj_price_adapter.dart';

http.Response _json(Object body, {int status = 200}) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Map<String, dynamic> _cafef(List<Map<String, dynamic>> rows) => {
      'Data': {
        'goldPriceWorlds': {'name': 'Gold', 'price': 3554.83},
        'goldPriceWorldHistories': rows,
      },
    };

void main() {
  final now = DateTime.utc(2026, 11, 20, 16);

  group('CafefPriceAdapter', () {
    test('lấy dòng SJC mới nhất, đổi triệu/lượng sang VND/lượng', () async {
      final adapter = CafefPriceAdapter(
        now: () => now,
        client: MockClient((req) async {
          expect(req.url.host, 'cafef.vn');
          return _json(_cafef([
            {'name': 'SJC', 'buyPrice': 129.2, 'sellPrice': 134.2, 'createdAt': '2026-11-20T15:44:39.787Z'},
            {'name': 'SJC', 'buyPrice': 133.2, 'sellPrice': 136.2, 'createdAt': '2026-11-19T16:57:42.578Z'},
          ]));
        }),
      );

      final price = (await adapter.fetchPrices()).single;

      expect(price.goldTypeId, 'sjc');
      expect(price.buyPrice, 129200000);
      expect(price.sellPrice, 134200000);
      expect(price.source, 'cafef');
    });

    test('dữ liệu quá cũ, rỗng, sai định dạng hoặc HTTP lỗi đều ném lỗi', () async {
      CafefPriceAdapter withBody(http.Response res) =>
          CafefPriceAdapter(now: () => now, client: MockClient((_) async => res));

      final stale = withBody(_json(_cafef([
        {'name': 'SJC', 'buyPrice': 120.0, 'sellPrice': 122.0, 'createdAt': '2026-11-01T10:00:00Z'},
      ])));
      final empty = withBody(_json(_cafef([])));
      final noData = withBody(_json({'Data': null}));
      final badNumbers = withBody(_json(_cafef([
        {'name': 'SJC', 'buyPrice': '', 'sellPrice': 0, 'createdAt': '2026-11-20T15:00:00Z'},
      ])));
      final down = withBody(http.Response('', 503));

      for (final adapter in [stale, empty, noData, badNumbers, down]) {
        await expectLater(adapter.fetchPrices(), throwsException);
      }
    });
  });

  group('PnjPriceAdapter', () {
    test('đổi nghìn/chỉ sang VND/lượng và bỏ dòng thiếu giá', () async {
      final adapter = PnjPriceAdapter(client: MockClient((req) async {
        expect(req.url.queryParameters['zone'], '11');
        return _json({
          'chinhanh': 'hanoi',
          'updateDate': '20/11/2026 16:29:04',
          'data': [
            {'masp': 'SJC', 'tensp': 'Vàng miếng SJC 999.9', 'giaban': 13420, 'giamua': 12920},
            {'masp': 'N24K', 'tensp': 'Nhẫn Trơn PNJ 999.9', 'giaban': 13200, 'giamua': 12780},
            {'masp': '24K', 'tensp': 'Vàng nữ trang 999.9', 'giaban': 12954, 'giamua': 12404},
            {'masp': 'RAW_9999', 'tensp': 'Vàng nguyên liệu', 'giaban': '', 'giamua': 11525},
          ],
        });
      }));

      final prices = await adapter.fetchPrices();
      final byType = {for (final p in prices) p.goldTypeId: p};

      expect(byType.keys.toSet(), {'pnj_hanoi', 'pnj_24k'});
      expect(byType['pnj_hanoi']!.buyPrice, 129200000);
      expect(byType['pnj_hanoi']!.sellPrice, 134200000);
      expect(byType['pnj_24k']!.buyPrice, 127800000);
      expect(byType['pnj_24k']!.sellPrice, 132000000);
    });

    test('giá bán là chuỗi rỗng ở mã đang track thì bỏ, không còn mã nào thì ném lỗi', () async {
      final adapter = PnjPriceAdapter(
          client: MockClient((_) async => _json({
                'data': [
                  {'masp': 'SJC', 'giaban': '', 'giamua': 12920},
                ],
              })));
      final down =
          PnjPriceAdapter(client: MockClient((_) async => http.Response('', 502)));

      await expectLater(adapter.fetchPrices(), throwsException);
      await expectLater(down.fetchPrices(), throwsException);
    });
  });
}
