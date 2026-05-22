import 'package:cloud_firestore/cloud_firestore.dart';

class SupplierModel {
  final String supplierId;
  final String name;
  final String phone;
  final List<String> categories;
  final String notes;
  final DateTime createdAt;

  const SupplierModel({
    required this.supplierId,
    required this.name,
    required this.phone,
    required this.categories,
    required this.notes,
    required this.createdAt,
  });

  factory SupplierModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SupplierModel(
      supplierId: doc.id,
      name: data['name'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      categories: List<String>.from(data['categories'] as List? ?? []),
      notes: data['notes'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'phone': phone,
    'categories': categories,
    'notes': notes,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  SupplierModel copyWith({
    String? supplierId,
    String? name,
    String? phone,
    List<String>? categories,
    String? notes,
    DateTime? createdAt,
  }) =>
      SupplierModel(
        supplierId: supplierId ?? this.supplierId,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        categories: categories ?? this.categories,
        notes: notes ?? this.notes,
        createdAt: createdAt ?? this.createdAt,
      );
}
