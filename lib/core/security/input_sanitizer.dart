// lib/core/security/input_sanitizer.dart
// ─────────────────────────────────────────────────────────────────────────────
// Input validation and sanitization.
// Supabase uses parameterized queries (prevents SQL injection), but we
// still sanitize inputs to prevent XSS in UI and malformed data in DB.
// ─────────────────────────────────────────────────────────────────────────────

class InputSanitizer {
  InputSanitizer._();

  // Remove HTML tags and dangerous characters
  static String sanitizeText(String input, {int maxLength = 200}) {
    return input
        .trim()
        .replaceAll(RegExp(r'<[^>]*>'), '')            // strip HTML
        .replaceAll(RegExp(r'[<>"\x00-\x1F]'), '')     // strip control chars
        .substring(0, input.trim().length.clamp(0, maxLength));
  }

  // Sanitize for use as a search query
  static String sanitizeSearch(String input) {
    return input
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9 _\-\u0600-\u06FF]'), '')
        .substring(0, input.trim().length.clamp(0, 100));
  }

  // Validate and normalize email
  static String? normalizeEmail(String email) {
    final trimmed = email.trim().toLowerCase();
    final emailRegex = RegExp(r'^[\w.+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(trimmed) ? trimmed : null;
  }

  // Validate password strength
  static PasswordStrength checkPasswordStrength(String password) {
    if (password.length < 8) return PasswordStrength.weak;
    
    int score = 0;
    if (password.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password)) score++;

    if (score <= 2) return PasswordStrength.weak;
    if (score <= 3) return PasswordStrength.medium;
    return PasswordStrength.strong;
  }

  // Sanitize a display name
  static String sanitizeDisplayName(String name) {
    return name
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9 _\-\.\u0600-\u06FF]'), '')
        .substring(0, name.trim().length.clamp(0, 50));
  }

  // Validate quantity input
  static double? parseQuantity(String input) {
    final cleaned = input.trim().replaceAll(RegExp(r'[^0-9.]'), '');
    final value = double.tryParse(cleaned);
    if (value == null || value <= 0 || value > 99999) return null;
    return value;
  }

  // Validate a date string
  static DateTime? parseDate(String input) {
    try {
      final dt = DateTime.parse(input.trim());
      // Reject dates more than 10 years in the future or in the past
      final now = DateTime.now();
      if (dt.isBefore(now.subtract(const Duration(days: 3650)))) return null;
      if (dt.isAfter(now.add(const Duration(days: 3650)))) return null;
      return dt;
    } catch (_) {
      return null;
    }
  }

  // Prevent prompt injection in AI requests
  static String sanitizeAiPromptInput(String input) {
    return input
        .trim()
        .replaceAll(RegExp(r'ignore (all )?previous instructions', caseSensitive: false), '')
        .replaceAll(RegExp(r'you are now', caseSensitive: false), '')
        .replaceAll(RegExp(r'system prompt', caseSensitive: false), '')
        .replaceAll(RegExp(r'<\|.*?\|>', caseSensitive: false), '')
        .substring(0, input.trim().length.clamp(0, 500));
  }
}

enum PasswordStrength { weak, medium, strong }

extension PasswordStrengthExt on PasswordStrength {
  String get label {
    switch (this) {
      case PasswordStrength.weak: return 'Weak';
      case PasswordStrength.medium: return 'Medium';
      case PasswordStrength.strong: return 'Strong';
    }
  }
}
