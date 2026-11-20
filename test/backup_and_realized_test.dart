import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lo/models/gold_type.dart';
import 'package:lo/models/user_holding.dart';
import 'package:lo/services/backup_codec.dart';
import 'package:lo/services/profit_loss_calculator.dart';

UserHolding holding({
  String id = 'h1',
  String goldTypeId = 'sjc',
  double quantityInLuong = 2,
  double buyPricePerLuong = 100000000,
  double fee = 0,
  String status = 'holding',
  String? note,
  double? sellPricePerLuong,
  DateTime? sellDate,
  double? sellFee,
}) {
  return UserHolding(
    id: id,
    goldTypeId: goldTypeId,
    quantity: quantityInLuong,
    unit: 'luong',
    quantityInLuong: quantityInLuong,
    buyPricePerLuong: buyPricePerLuong,
    totalCost: buyPricePerLuong * quantityInLuong + fee,
    fee: fee,
    buyDate: DateTime(2025, 1, 10),
    note: note,
    status: status,
    sellPricePerLuong: sellPricePerLuong,
    sellDate: sellDate,
    sellFee: sellFee,
    createdAt: DateTime(2025, 1, 10, 8),
    updatedAt: DateTime(2025, 1, 10, 8),
  );
}

void main() {
  group('UserHolding sale fields', () {
    test('bản ghi cũ không có trường bán vẫn load được', () {
      final map = holding().toMap()
        ..remove('sellPricePerLuong')
        ..remove('sellDate')
        ..remove('sellFee');
      final h = UserHolding.fromMap(map);
      expect(h.sellPricePerLuong, isNull);
      expect(h.sellDate, isNull);
      expect(h.sellFee, isNull);
    });

    test('toMap/fromMap giữ nguyên trường bán, clearSale xoá chúng', () {
      final sold = holding(
        status: 'sold',
        sellPricePerLuong: 90000000,
        sellDate: DateTime(2025, 3, 1),
        sellFee: 50000,
      );
      final back = UserHolding.fromMap(
          jsonDecode(jsonEncode(sold.toMap())) as Map<String, dynamic>);
      expect(back.sellPricePerLuong, 90000000);
      expect(back.sellDate, DateTime(2025, 3, 1));
      expect(back.sellFee, 50000);

      final undone = back.copyWith(status: 'holding', clearSale: true);
      expect(undone.sellPricePerLuong, isNull);
      expect(undone.sellDate, isNull);
      expect(undone.sellFee, isNull);
    });
  });

  group('ProfitLossCalculator.calculateRealized', () {
    test('lỗ: tính cả phí mua và phí bán', () {
      // Vốn = 2 * 100tr + 1tr phí = 201tr. Thu = 2 * 95tr - 0.5tr = 189.5tr.
      final h = holding(
        fee: 1000000,
        status: 'sold',
        sellPricePerLuong: 95000000,
        sellFee: 500000,
      );
      final r = ProfitLossCalculator.calculateRealized(h)!;
      expect(r.totalCost, 201000000);
      expect(r.proceeds, 189500000);
      expect(r.profitLoss, -11500000);
      expect(r.profitLossPercent, closeTo(-5.721, 0.001));
      expect(r.isProfit, isFalse);
    });

    test('lãi, không phí bán', () {
      final h = holding(status: 'sold', sellPricePerLuong: 110000000);
      final r = ProfitLossCalculator.calculateRealized(h)!;
      expect(r.profitLoss, 20000000);
      expect(r.profitLossPercent, closeTo(10, 0.0001));
      expect(r.isProfit, isTrue);
    });

    test('null khi chưa ghi giá bán hoặc chưa bán', () {
      expect(
          ProfitLossCalculator.calculateRealized(holding(status: 'sold')),
          isNull);
      expect(
          ProfitLossCalculator.calculateRealized(
              holding(sellPricePerLuong: 1)),
          isNull);
    });

    test('tổng hợp bỏ qua mục thiếu giá bán và đếm riêng', () {
      final summary = ProfitLossCalculator.calculateRealizedSummary([
        holding(id: 'a', status: 'sold', sellPricePerLuong: 110000000),
        holding(id: 'b', status: 'sold', sellPricePerLuong: 90000000),
        holding(id: 'c', status: 'sold'),
        holding(id: 'd'),
      ]);
      expect(summary.count, 2);
      expect(summary.missingSellPriceCount, 1);
      expect(summary.totalCost, 400000000);
      expect(summary.profitLoss, 0);
    });
  });

  group('BackupCodec JSON', () {
    final custom = GoldType(
      id: 'custom_1',
      name: 'custom_1',
      displayName: 'Vàng nhà làm',
      defaultUnit: 'chi',
      sourceKey: 'mock',
      isCustom: true,
    );
    final types = [...GoldType.defaults, custom];

    test('round-trip giữ đủ holdings (kể cả trường bán) và loại vàng tự tạo', () {
      final holdings = [
        holding(id: 'a'),
        holding(
          id: 'b',
          goldTypeId: 'custom_1',
          status: 'sold',
          sellPricePerLuong: 99000000,
          sellDate: DateTime(2025, 4, 2),
          sellFee: 10000,
        ),
      ];
      final raw = BackupCodec.encodeJson(holdings: holdings, goldTypes: types);
      final data = BackupCodec.parse(raw);

      expect(data.version, BackupCodec.currentVersion);
      expect(data.holdings.map((h) => h.id), ['a', 'b']);
      expect(data.holdings[1].sellPricePerLuong, 99000000);
      expect(data.holdings[1].sellDate, DateTime(2025, 4, 2));
      expect(data.customGoldTypes.map((g) => g.id), ['custom_1']);
      expect(data.exportedAt, isNotNull);
      expect(raw, contains('Vàng nhà làm')); // tên hiển thị kèm theo
    });

    test('ghi chú có nháy kép, xuống dòng, dấu phẩy vẫn round-trip', () {
      const note = 'Mua "xịn", tiệm A\ndòng 2\\ok';
      final raw = BackupCodec.encodeJson(
        holdings: [holding(note: note)],
        goldTypes: types,
      );
      expect(BackupCodec.parse(raw).holdings.single.note, note);
    });

    test('file có BOM vẫn đọc được', () {
      final raw = BackupCodec.encodeJson(holdings: [holding()], goldTypes: types);
      expect(BackupCodec.parse('﻿$raw').holdings, hasLength(1));
    });

    void expectRejected(String raw) {
      expect(
        () => BackupCodec.parse(raw),
        throwsA(isA<BackupFormatException>()),
        reason: raw,
      );
    }

    test('từ chối dữ liệu rác', () {
      expectRejected('');
      expectRejected('không phải json');
      expectRejected('[1,2,3]');
      expectRejected('{"foo": 1}');
      expectRejected('{"format":"lo-backup","version":1}'); // thiếu holdings
      expectRejected(
          '{"format":"lo-backup","version":1,"holdings":[1]}'); // mục sai kiểu
      expectRejected(
          '{"format":"lo-backup","version":1,"holdings":[{"id":"x"}]}');
    });

    test('từ chối phiên bản không hỗ trợ', () {
      expectRejected('{"format":"lo-backup","version":999,"holdings":[]}');
      expectRejected('{"format":"lo-backup","version":0,"holdings":[]}');
      expectRejected('{"format":"lo-backup","version":"1","holdings":[]}');
    });

    test('từ chối số liệu vô lý và id trùng', () {
      final good = holding().toMap();
      String wrap(List<Map<String, dynamic>> hs) => jsonEncode({
            'format': 'lo-backup',
            'version': 1,
            'holdings': hs,
          });
      expectRejected(wrap([
        {...good, 'quantityInLuong': -1}
      ]));
      expectRejected(wrap([
        {...good, 'status': 'weird'}
      ]));
      expectRejected(wrap([
        {...good, 'unit': 'kg'}
      ]));
      expectRejected(wrap([good, good]));
    });

    test('thông báo lỗi là tiếng Việt thân thiện', () {
      try {
        BackupCodec.parse('xxx');
        fail('phải ném lỗi');
      } on BackupFormatException catch (e) {
        expect(e.message, contains('File'));
      }
    });
  });

  group('BackupCodec merge/replace', () {
    final existing = [holding(id: 'a', note: 'cũ'), holding(id: 'b')];
    final incoming = BackupData(
      version: 1,
      exportedAt: null,
      holdings: [holding(id: 'b', note: 'từ file'), holding(id: 'c')],
      customGoldTypes: [
        GoldType(
          id: 'custom_1',
          name: 'custom_1',
          displayName: 'X',
          defaultUnit: 'luong',
          sourceKey: 'mock',
          isCustom: true,
        ),
      ],
    );

    test('merge chỉ thêm id chưa có, giữ bản trên máy', () {
      final plan = BackupCodec.plan(
        existingHoldings: existing,
        existingGoldTypes: GoldType.defaults,
        data: incoming,
        mode: ImportMode.merge,
      );
      expect(plan.holdings.map((h) => h.id), ['a', 'b', 'c']);
      expect(plan.holdings[1].note, isNull); // không bị ghi đè
      expect(plan.addedCount, 1);
      expect(plan.skippedCount, 1);
      expect(plan.goldTypes.any((g) => g.id == 'custom_1'), isTrue);
    });

    test('replace dùng đúng nội dung file', () {
      final plan = BackupCodec.plan(
        existingHoldings: existing,
        existingGoldTypes: GoldType.defaults,
        data: incoming,
        mode: ImportMode.replace,
      );
      expect(plan.holdings.map((h) => h.id), ['b', 'c']);
      expect(plan.holdings.first.note, 'từ file');
      expect(plan.addedCount, 2);
    });

    test('plan không đổi danh sách đầu vào; preview đếm đúng', () {
      BackupCodec.plan(
        existingHoldings: existing,
        existingGoldTypes: GoldType.defaults,
        data: incoming,
        mode: ImportMode.replace,
      );
      expect(existing, hasLength(2));
      final p = BackupCodec.preview(existingHoldings: existing, data: incoming);
      expect(p.totalInFile, 2);
      expect(p.newCount, 1);
      expect(p.existingCount, 1);
      expect(p.currentCount, 2);
    });
  });

  group('BackupCodec CSV', () {
    test('escape RFC 4180', () {
      expect(BackupCodec.csvField('abc'), 'abc');
      expect(BackupCodec.csvField('a,b'), '"a,b"');
      expect(BackupCodec.csvField('nói "hi"'), '"nói ""hi"""');
      expect(BackupCodec.csvField('a\nb'), '"a\nb"');
    });

    test('mỗi dòng đủ cột dù ghi chú có ký tự đặc biệt; BOM tuỳ chọn', () {
      final csv = BackupCodec.encodeCsv(
        holdings: [
          holding(note: 'a,"b"\nc', status: 'sold', sellPricePerLuong: 9e7)
        ],
        goldTypes: GoldType.defaults,
      );
      expect(csv.startsWith('﻿'), isFalse);
      expect(csv, contains('"a,""b""\nc"'));
      expect(csv, contains('-20000000')); // lãi/lỗ đã chốt
      expect(
        BackupCodec.encodeCsv(
          holdings: const [],
          goldTypes: GoldType.defaults,
          withBom: true,
        ).startsWith('﻿'),
        isTrue,
      );
    });
  });
}
