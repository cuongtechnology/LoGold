import 'backup_codec.dart';
import 'portfolio_service.dart';

/// ExportService - Xuất dữ liệu ra CSV (đọc bằng Excel) và JSON (sao lưu,
/// khôi phục được). Phần encode nằm ở [BackupCodec] (thuần, có test); service
/// này chỉ lấy dữ liệu hiện tại từ [PortfolioService].
class ExportService {
  static ExportService? _instance;
  static ExportService get instance => _instance ??= ExportService._();

  ExportService._();

  /// Xuất danh mục thành CSV (RFC 4180). `withBom: true` thêm BOM UTF-8 để
  /// Excel trên Windows hiển thị đúng tiếng Việt — dùng khi ghi ra file.
  String exportToCSV({bool withBom = false}) {
    final portfolio = PortfolioService.instance;
    return BackupCodec.encodeCsv(
      holdings: portfolio.allHoldings,
      goldTypes: portfolio.goldTypes,
      withBom: withBom,
    );
  }

  /// Xuất file sao lưu JSON đầy đủ — có thể khôi phục qua
  /// `AppStore.importBackup`.
  String exportToJSON() {
    final portfolio = PortfolioService.instance;
    return BackupCodec.encodeJson(
      holdings: portfolio.allHoldings,
      goldTypes: portfolio.goldTypes,
    );
  }
}
