import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// Selcom API configuration.
/// In production, these should come from environment variables
/// or Firebase Remote Config, NOT hardcoded.
class SelcomConfig {
  static const String baseUrl = 'https://api.selcommobile.com/v1';
  static const String apiKey = 'YOUR_SELCOM_API_KEY';
  static const String apiSecret = 'YOUR_SELCOM_API_SECRET';
  static const String vendorId = 'YOUR_VENDOR_ID';

  /// Webhook secret for signature verification.
  static const String webhookSecret = 'YOUR_WEBHOOK_SECRET';
}

/// Supported Selcom payment channels.
enum SelcomChannel { mpesa, airtel, tigo, card, bank }

/// Response from Selcom API.
class SelcomResponse {
  final bool success;
  final String? transactionId;
  final String? status;
  final String? message;
  final Map<String, dynamic>? raw;

  SelcomResponse({
    required this.success,
    this.transactionId,
    this.status,
    this.message,
    this.raw,
  });

  factory SelcomResponse.fromJson(Map<String, dynamic> json) {
    return SelcomResponse(
      success: json['success'] == true || json['status'] == 'success',
      transactionId: json['transaction_id'] ?? json['order_id'],
      status: json['status']?.toString(),
      message: json['message']?.toString() ?? json['error']?.toString(),
      raw: json,
    );
  }
}

/// Selcom API wrapper for Tanzania mobile money and card payments.
class SelcomService {
  final String _baseUrl;
  final String _apiKey;
  final String _apiSecret;
  final String _vendorId;

  SelcomService({
    String? baseUrl,
    String? apiKey,
    String? apiSecret,
    String? vendorId,
  })  : _baseUrl = baseUrl ?? SelcomConfig.baseUrl,
        _apiKey = apiKey ?? SelcomConfig.apiKey,
        _apiSecret = apiSecret ?? SelcomConfig.apiSecret,
        _vendorId = vendorId ?? SelcomConfig.vendorId;

  /// Generate HMAC-SHA256 signature for Selcom requests.
  String _sign(String payload) {
    final key = utf8.encode(_apiSecret);
    final bytes = utf8.encode(payload);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(bytes);
    return base64Encode(digest.bytes);
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $_apiKey',
    'X-Vendor-ID': _vendorId,
  };

  /// ─── 1. CREATE CHECKOUT / PAYMENT ORDER ────────────────────────────
  ///
  /// Initiates a payment via Selcom checkout or STK push.
  /// Returns the Selcom order ID and payment URL (if applicable).
  Future<SelcomResponse> createPaymentOrder({
    required double amount,
    required String currency,
    required String orderId,
    required String customerEmail,
    required String customerPhone,
    required String description,
    String? redirectUrl,
    String? cancelUrl,
    SelcomChannel? channel,
  }) async {
    try {
      final body = jsonEncode({
        'vendor': _vendorId,
        'order_id': orderId,
        'buyer_email': customerEmail,
        'buyer_name': customerPhone,
        'buyer_phone': customerPhone,
        'amount': amount,
        'currency': currency,
        'payment_gateways': channel != null ? _mapChannel(channel) : null,
        'billing': {
          'email': customerEmail,
          'phone': customerPhone,
        },
        'redirect_url': redirectUrl,
        'cancel_url': cancelUrl,
        'webhook': 'https://your-firebase-function-url.com/selcomWebhook',
        'metadata': {
          'description': description,
        },
      });

      final response = await http.post(
        Uri.parse('$_baseUrl/checkout/create-order'),
        headers: _headers,
        body: body,
      );

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return SelcomResponse.fromJson(json);
    } catch (e) {
      return SelcomResponse(
        success: false,
        message: 'Network error: $e',
      );
    }
  }

  /// ─── 2. VERIFY PAYMENT STATUS ──────────────────────────────────────
  Future<SelcomResponse> verifyPayment(String orderId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/checkout/order-status?order_id=$orderId'),
        headers: _headers,
      );

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return SelcomResponse.fromJson(json);
    } catch (e) {
      return SelcomResponse(
        success: false,
        message: 'Network error: $e',
      );
    }
  }

  /// ─── 3. CREATE PAYOUT (WITHDRAWAL) ─────────────────────────────────
  ///
  /// Sends money from Dalali's Selcom account to a mobile money wallet
  /// or bank account.
  Future<SelcomResponse> createPayout({
    required String payoutId,
    required double amount,
    required String currency,
    required String phoneNumber,
    required String provider,
    required String narration,
  }) async {
    try {
      final body = jsonEncode({
        'vendor': _vendorId,
        'payout_id': payoutId,
        'amount': amount,
        'currency': currency,
        'recipient': {
          'phone': phoneNumber,
          'wallet_provider': provider,
        },
        'narration': narration,
      });

      final response = await http.post(
        Uri.parse('$_baseUrl/payout/create'),
        headers: _headers,
        body: body,
      );

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return SelcomResponse.fromJson(json);
    } catch (e) {
      return SelcomResponse(
        success: false,
        message: 'Network error: $e',
      );
    }
  }

  /// ─── 4. VERIFY PAYOUT STATUS ───────────────────────────────────────
  Future<SelcomResponse> verifyPayout(String payoutId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/payout/status?payout_id=$payoutId'),
        headers: _headers,
      );

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return SelcomResponse.fromJson(json);
    } catch (e) {
      return SelcomResponse(
        success: false,
        message: 'Network error: $e',
      );
    }
  }

  /// ─── 5. VERIFY WEBHOOK SIGNATURE ───────────────────────────────────
  ///
  /// Validates that a webhook payload came from Selcom.
  /// This MUST be called on the backend (Firebase Functions).
  bool verifyWebhookSignature(String payload, String signature) {
    final computed = _sign(payload);
    return computed == signature;
  }

  String _mapChannel(SelcomChannel channel) {
    switch (channel) {
      case SelcomChannel.mpesa:
        return 'MPESA';
      case SelcomChannel.airtel:
        return 'AIRTEL';
      case SelcomChannel.tigo:
        return 'TIGO';
      case SelcomChannel.card:
        return 'CARD';
      case SelcomChannel.bank:
        return 'BANK';
    }
  }

  /// Generate a cryptographically secure order ID.
  static String generateOrderId(String prefix) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random.secure().nextInt(999999).toString().padLeft(6, '0');
    return '${prefix}_$timestamp$random';
  }
}
