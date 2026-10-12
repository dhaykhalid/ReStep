/// Reusable form validators. Each returns an error message or null.
class Validators {
  Validators._();

  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final RegExp _phoneChars = RegExp(r'^[0-9+\-\s()]+$');

  static String? required(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    if (!_emailPattern.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  /// Used on the sign-in form (no strength rules, only presence).
  static String? passwordPresent(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    return null;
  }

  /// Used when creating an account.
  static String? newPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Use at least 8 characters';
    }
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(value);
    final hasNumber = RegExp(r'[0-9]').hasMatch(value);
    if (!hasLetter || !hasNumber) {
      return 'Include at least one letter and one number';
    }
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != original) {
      return 'Passwords do not match';
    }
    return null;
  }

  static String? phone(String? value, {bool isRequired = true}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return isRequired ? 'Phone number is required' : null;
    }
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (!_phoneChars.hasMatch(text) || digits.length < 8 || digits.length > 15) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  static String? durationSeconds(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Duration is required';
    }
    final n = int.tryParse(text);
    if (n == null) {
      return 'Enter the duration as a whole number of seconds';
    }
    if (n < 1) {
      return 'Duration must be at least 1 second';
    }
    if (n > 3600) {
      return 'Duration must be 3600 seconds (1 hour) or less';
    }
    return null;
  }
}
