/// ═══════════════════════════════════════════════════════════════
/// OCR VALIDATION SERVICE
/// ═══════════════════════════════════════════════════════════════
///
/// Validates extracted text fields from identity documents.
/// Pure Dart logic — no external dependencies required.
///
class OcrValidationService {
  // ─── NIDA ID ────────────────────────────────────────────────
  static bool isValidNin(String nin) {
    // NIDA NIN: exactly 20 digits
    final regex = RegExp(r'^\d{20}$');
    if (!regex.hasMatch(nin)) return false;
    return _ninChecksumValid(nin);
  }

  static bool _ninChecksumValid(String nin) {
    // Placeholder: NIDA uses a weighted modulus-11 algorithm.
    // Replace with official algorithm when available.
    final weights = [3, 7, 1, 3, 7, 1, 3, 7, 1, 3, 7, 1, 3, 7, 1, 3, 7, 1, 3];
    int sum = 0;
    for (int i = 0; i < weights.length; i++) {
      sum += int.parse(nin[i]) * weights[i];
    }
    final checkDigit = int.parse(nin[19]);
    final remainder = sum % 11;
    final expected = remainder == 10 ? 1 : remainder;
    return checkDigit == expected;
  }

  // ─── Passport (Tanzanian) ───────────────────────────────────
  static bool isValidTzPassportNumber(String number) {
    // TZ passport: 1 letter + 7 digits (e.g., A1234567)
    return RegExp(r'^[A-Z]\d{7}$').hasMatch(number);
  }

  static bool isValidMrz(String mrz) {
    // ICAO 9303 MRZ: TD3 format = 2 lines x 44 chars
    if (mrz.length != 88 && mrz.length != 90) return false;
    final lines = mrz.split('\n');
    if (lines.length != 2) return false;
    if (lines[0].length != 44 || lines[1].length != 44) return false;
    return _mrzChecksumValid(lines[0]) && _mrzChecksumValid(lines[1]);
  }

  static bool _mrzChecksumValid(String line) {
    // MRZ checksum: weighted mod 10 with specific digit/letter mapping
    // Simplified check for structure validation
    return line.contains('<') && RegExp(r'^[A-Z0-9<]+$').hasMatch(line);
  }

  // ─── Driver's License ───────────────────────────────────────
  static bool isValidDriversLicenseNumber(String number) {
    // TANROADS format varies; accept alphanumeric 6-12 chars
    return RegExp(r'^[A-Z0-9]{6,12}$').hasMatch(number);
  }

  // ─── ZanID ──────────────────────────────────────────────────
  static bool isValidZanId(String zanId) {
    // Zanzibar ID format placeholder
    return RegExp(r'^ZAN\d{8,12}$').hasMatch(zanId);
  }

  // ─── Voter's ID ─────────────────────────────────────────────
  static bool isValidVotersId(String votersId) {
    // NEC voter ID format placeholder
    return RegExp(r'^\d{8,12}$').hasMatch(votersId);
  }

  // ─── Universal Date Parser ──────────────────────────────────
  static DateTime? parseDate(String raw) {
    // Try common TZ date formats
    final patterns = [
      r'(\d{2})/(\d{2})/(\d{4})', // DD/MM/YYYY
      r'(\d{2})-(\d{2})-(\d{4})', // DD-MM-YYYY
      r'(\d{4})-(\d{2})-(\d{2})', // YYYY-MM-DD
      r'(\d{2})(\d{2})(\d{4})',    // DDMMYYYY (MRZ style)
    ];

    for (final pattern in patterns) {
      final match = RegExp(pattern).firstMatch(raw);
      if (match != null) {
        try {
          if (pattern.contains(r'\d{4})-(\d{2})-(\d{2})')) {
            return DateTime(
              int.parse(match.group(1)!),
              int.parse(match.group(2)!),
              int.parse(match.group(3)!),
            );
          } else if (pattern == r'(\d{2})(\d{2})(\d{4})') {
            return DateTime(
              int.parse(match.group(3)!),
              int.parse(match.group(2)!),
              int.parse(match.group(1)!),
            );
          } else {
            return DateTime(
              int.parse(match.group(3)!),
              int.parse(match.group(2)!),
              int.parse(match.group(1)!),
            );
          }
        } catch (_) {
          continue;
        }
      }
    }
    return null;
  }

  // ─── Name Normalization ─────────────────────────────────────
  static String normalizeName(String raw) {
    return raw
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // ─── Image Quality Checks (stub for native integration) ─────
  static Future<IqcResult> checkImageQuality(String imagePath) async {
    // In production: integrate OpenCV or ML Kit for real-time checks
    // Return mock pass for stub
    return IqcResult(
      blurScore: 850.0, // Laplacian variance threshold > 500
      glareScore: 0.12, // Glare ratio < 0.20
      hasFace: true,
      isAcceptable: true,
    );
  }
}

class IqcResult {
  final double blurScore;
  final double glareScore;
  final bool hasFace;
  final bool isAcceptable;

  const IqcResult({
    required this.blurScore,
    required this.glareScore,
    required this.hasFace,
    required this.isAcceptable,
  });
}
