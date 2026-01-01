import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../services/backends/lightning_backend.dart';

/// Metadata for a wallet in multi-wallet setup
class WalletMetadata {
  final String id;
  final String name;
  final DateTime createdAt;
  final LightningBackendType backendType;

  WalletMetadata({
    required this.id,
    required this.name,
    required this.createdAt,
    this.backendType = LightningBackendType.liquid,
  });

  /// Create a new wallet with generated UUID
  factory WalletMetadata.create({
    required String name,
    LightningBackendType backendType = LightningBackendType.liquid,
  }) {
    return WalletMetadata(
      id: const Uuid().v4(),
      name: name,
      createdAt: DateTime.now(),
      backendType: backendType,
    );
  }

  /// Working directory path for Breez SDK (relative to app docs)
  String get workingDir => '${backendType.name}_wallet_$id';

  /// Create a copy with updated name
  WalletMetadata copyWith({
    String? name,
    LightningBackendType? backendType,
  }) {
    return WalletMetadata(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
      backendType: backendType ?? this.backendType,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'backendType': backendType.name,
    };
  }

  /// Create from JSON map
  factory WalletMetadata.fromJson(Map<String, dynamic> json) {
    // Parse backendType with backward compatibility - default to liquid
    LightningBackendType backendType = LightningBackendType.liquid;
    if (json['backendType'] != null) {
      final backendTypeStr = json['backendType'] as String;
      backendType = LightningBackendType.values.firstWhere(
        (e) => e.name == backendTypeStr,
        orElse: () => LightningBackendType.liquid,
      );
    }

    return WalletMetadata(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      backendType: backendType,
    );
  }

  /// Encode list of wallets to JSON string
  static String encodeList(List<WalletMetadata> wallets) {
    return jsonEncode(wallets.map((w) => w.toJson()).toList());
  }

  /// Decode list of wallets from JSON string
  static List<WalletMetadata> decodeList(String json) {
    final List<dynamic> list = jsonDecode(json);
    return list.map((item) => WalletMetadata.fromJson(item)).toList();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WalletMetadata &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'WalletMetadata(id: $id, name: $name)';
}
