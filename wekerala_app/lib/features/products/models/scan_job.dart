import '../../../core/services/product_lookup_service.dart';

enum ScanStatus { scanning, done, failed }

class ScanJob {
  final String id;
  final String imagePath;
  final String base64Image;
  final String barcode; // set for barcode-scan jobs, empty for photo-scan
  ScanStatus status;
  ProductData? result;

  ScanJob({
    required this.id,
    required this.imagePath,
    required this.base64Image,
    this.barcode = '',
    this.status = ScanStatus.scanning,
    this.result,
  });
}
