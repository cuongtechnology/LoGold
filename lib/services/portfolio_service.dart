import 'package:uuid/uuid.dart';
import '../models/user_holding.dart';
import '../models/gold_type.dart';
import '../services/backup_codec.dart';
import '../services/price_service.dart';
import '../services/profit_loss_calculator.dart';
import '../services/storage_service.dart';
import '../utils/gold_units.dart';

/// PortfolioService - Manages user's gold holdings (CRUD operations).
/// Persist qua Hive (StorageService) — mọi mutation flush ra disk async.
/// All data stays on device.
class PortfolioService {
  static PortfolioService? _instance;
  static PortfolioService get instance => _instance ??= PortfolioService._();

  PortfolioService._();

  final _uuid = const Uuid();
  final List<UserHolding> _holdings = [];
  final List<GoldType> _goldTypes = [];

  /// Load persisted data từ Hive. Nếu box rỗng, seed gold types từ defaults.
  ///
  /// `holdings` / `goldTypes` param cho phép override khi test — bỏ qua Hive.
  Future<void> init({
    List<UserHolding>? holdings,
    List<GoldType>? goldTypes,
  }) async {
    _holdings.clear();
    if (holdings != null) {
      _holdings.addAll(holdings);
    } else {
      _holdings.addAll(
        StorageService.readMapList(StorageService.holdings)
            .map(UserHolding.fromMap),
      );
    }

    _goldTypes.clear();
    if (goldTypes != null) {
      _goldTypes.addAll(goldTypes);
    } else {
      final stored = StorageService.readMapList(StorageService.goldTypes)
          .map(GoldType.fromMap)
          .toList();
      if (stored.isEmpty) {
        _goldTypes.addAll(GoldType.defaults);
        await _persistGoldTypes();
      } else {
        _goldTypes.addAll(stored);
        // Migration: user đã cài từ trước có thể thiếu loại vàng mặc định
        // mới thêm sau này — bổ sung, không đụng tới custom type đã có.
        final existingIds = stored.map((g) => g.id).toSet();
        final missingDefaults = GoldType.defaults
            .where((g) => !existingIds.contains(g.id))
            .toList();
        if (missingDefaults.isNotEmpty) {
          _goldTypes.addAll(missingDefaults);
          await _persistGoldTypes();
        }
      }
    }
  }

  /// Get all gold types
  List<GoldType> get goldTypes => List.unmodifiable(_goldTypes);

  /// Get a gold type by ID
  GoldType? getGoldType(String id) {
    try {
      return _goldTypes.firstWhere((gt) => gt.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Add a custom gold type
  Future<void> addGoldType(GoldType goldType) async {
    _goldTypes.add(goldType);
    await _persistGoldTypes();
  }

  /// Get all active holdings (status = "holding")
  List<UserHolding> get activeHoldings =>
      _holdings.where((h) => h.status == 'holding').toList();

  /// Get all holdings (including sold)
  List<UserHolding> get allHoldings => List.unmodifiable(_holdings);

  /// Add a new gold purchase
  Future<UserHolding> addHolding({
    required String goldTypeId,
    required double quantity,
    required String unit,
    required double buyPricePerUnit,
    double fee = 0,
    required DateTime buyDate,
    String? note,
    String? invoiceImageUri,
  }) async {
    final quantityInLuong = GoldUnits.toLuong(quantity, unit);
    final buyPricePerLuong = GoldUnits.pricePerLuong(buyPricePerUnit, unit);
    final totalCost = (buyPricePerLuong * quantityInLuong) + fee;

    final now = DateTime.now();
    final holding = UserHolding(
      id: _uuid.v4(),
      goldTypeId: goldTypeId,
      quantity: quantity,
      unit: unit,
      quantityInLuong: quantityInLuong,
      buyPricePerLuong: buyPricePerLuong,
      totalCost: totalCost,
      fee: fee,
      buyDate: buyDate,
      note: note,
      invoiceImageUri: invoiceImageUri,
      status: 'holding',
      createdAt: now,
      updatedAt: now,
    );

    _holdings.add(holding);
    await _persistHoldings();
    return holding;
  }

  /// Update an existing holding
  Future<void> updateHolding(UserHolding holding) async {
    final index = _holdings.indexWhere((h) => h.id == holding.id);
    if (index >= 0) {
      _holdings[index] = holding.copyWith(updatedAt: DateTime.now());
      await _persistHoldings();
    }
  }

  /// Delete a holding
  Future<void> deleteHolding(String id) async {
    _holdings.removeWhere((h) => h.id == id);
    await _persistHoldings();
  }

  /// Mark a holding as sold, ghi lại giá bán thực tế (per lượng), ngày bán và
  /// phí bán. Gọi lại với holding đã 'sold' để bổ sung/sửa thông tin bán.
  Future<void> markAsSold(
    String id, {
    required double sellPricePerLuong,
    required DateTime sellDate,
    double sellFee = 0,
  }) async {
    final index = _holdings.indexWhere((h) => h.id == id);
    if (index >= 0) {
      _holdings[index] = _holdings[index].copyWith(
        status: 'sold',
        sellPricePerLuong: sellPricePerLuong,
        sellDate: sellDate,
        sellFee: sellFee,
        updatedAt: DateTime.now(),
      );
      await _persistHoldings();
    }
  }

  /// Hoàn tác bán: về lại 'holding' và xoá thông tin bán.
  Future<void> undoSale(String id) async {
    final index = _holdings.indexWhere((h) => h.id == id);
    if (index >= 0) {
      _holdings[index] = _holdings[index].copyWith(
        status: 'holding',
        clearSale: true,
        updatedAt: DateTime.now(),
      );
      await _persistHoldings();
    }
  }

  /// Áp dụng kết quả nhập file sao lưu (đã validate + tính sẵn bằng
  /// `BackupCodec.plan`). Nếu ghi đĩa lỗi thì khôi phục lại state trong memory
  /// rồi ném lại lỗi.
  Future<void> applyImport(ImportPlan plan) async {
    final oldHoldings = List<UserHolding>.of(_holdings);
    final oldGoldTypes = List<GoldType>.of(_goldTypes);
    try {
      _goldTypes
        ..clear()
        ..addAll(plan.goldTypes);
      _holdings
        ..clear()
        ..addAll(plan.holdings);
      // Loại vàng ghi trước: là tập cha của cũ nên an toàn nếu bước sau lỗi.
      await _persistGoldTypes();
      await _persistHoldings();
    } catch (_) {
      _goldTypes
        ..clear()
        ..addAll(oldGoldTypes);
      _holdings
        ..clear()
        ..addAll(oldHoldings);
      rethrow;
    }
  }

  /// Duplicate a holding
  Future<UserHolding?> duplicateHolding(String id) async {
    final index = _holdings.indexWhere((h) => h.id == id);
    if (index < 0) return null;

    final original = _holdings[index];
    final now = DateTime.now();
    final copy = UserHolding(
      id: _uuid.v4(),
      goldTypeId: original.goldTypeId,
      quantity: original.quantity,
      unit: original.unit,
      quantityInLuong: original.quantityInLuong,
      buyPricePerLuong: original.buyPricePerLuong,
      totalCost: original.totalCost,
      fee: original.fee,
      buyDate: original.buyDate,
      note: original.note,
      invoiceImageUri: original.invoiceImageUri,
      status: 'holding',
      createdAt: now,
      updatedAt: now,
    );
    _holdings.add(copy);
    await _persistHoldings();
    return copy;
  }

  /// Get the current portfolio summary with live prices
  PortfolioSummary getPortfolioSummary() {
    final holdings = activeHoldings;
    final Map<String, double> currentPrices = {};

    for (final holding in holdings) {
      final price = PriceService.instance.getBuyPrice(holding.goldTypeId);
      if (price != null) {
        currentPrices[holding.goldTypeId] = price;
      }
    }

    return ProfitLossCalculator.calculatePortfolio(
      holdings: holdings,
      currentBuyPrices: currentPrices,
    );
  }

  /// Get P/L result for a single holding
  ProfitLossResult? getHoldingResult(String holdingId) {
    final holding = _holdings.firstWhere(
      (h) => h.id == holdingId,
      orElse: () => throw StateError('Holding not found'),
    );

    final currentPrice =
        PriceService.instance.getBuyPrice(holding.goldTypeId);
    if (currentPrice == null) return null;

    return ProfitLossCalculator.calculate(
      holding: holding,
      currentBuyPricePerLuong: currentPrice,
    );
  }

  Future<void> _persistHoldings() async {
    await StorageService.writeMapList(
      StorageService.holdings,
      _holdings.map((h) => h.toMap()),
      keyOf: (m) => m['id'] as String,
    );
  }

  Future<void> _persistGoldTypes() async {
    await StorageService.writeMapList(
      StorageService.goldTypes,
      _goldTypes.map((g) => g.toMap()),
      keyOf: (m) => m['id'] as String,
    );
  }
}
