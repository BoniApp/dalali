class PaymentGatewayModel {
  final String id;
  final String providerName;
  final String environment; // sandbox | production
  final bool enabled;
  final Map<String, dynamic> config;

  PaymentGatewayModel({
    required this.id,
    required this.providerName,
    required this.environment,
    required this.enabled,
    required this.config,
  });

  factory PaymentGatewayModel.fromJson(Map<String, dynamic> json) {
    return PaymentGatewayModel(
      id: json['id'] ?? '',
      providerName: json['provider_name'] ?? '',
      environment: json['environment'] ?? 'production',
      enabled: (json['enabled'] as bool?) ?? false,
      config: (json['config'] as Map<String, dynamic>?) ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'provider_name': providerName,
        'environment': environment,
        'enabled': enabled,
        'config': config,
      };
}
