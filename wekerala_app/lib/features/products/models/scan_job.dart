import '../../../core/services/product_lookup_service.dart';

enum ScanStatus { scanning, done, failed }

class ScanJob {
  final String id;
  final String imagePath;
  final String base64Image;
  ScanStatus status;
  ProductData? result;

  ScanJob({
    required this.id,
    required this.imagePath,
    required this.base64Image,
    this.status = ScanStatus.scanning,
    this.result,
  });
}
