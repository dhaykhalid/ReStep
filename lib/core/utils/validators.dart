/// Reusable form validators. Each returns an error message or null.
class Validators {
  Validators._();

  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final RegExp _saudiMobile = RegExp(r'^(?:(?:\+|00)?966)?0?(5\d{8})$');

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
      return 'Enter a valid email address, such as name@example.com';
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

  /// Used when creating an account or setting a new password. Mirrors the
  /// server-side Firebase Authentication password policy ([PasswordPolicy]).
  static String? newPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    for (final rule in PasswordPolicy.requirements) {
      if (!rule.isMetBy(value)) return rule.errorMessage;
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

  static const String saudiMobileError =
      'Enter a valid Saudi mobile number starting with 5 (9 digits).';

  /// Saudi mobile number for an emergency contact. Accepts the 9 digits after
  /// +966 (5XXXXXXXX), a local number (05XXXXXXXX) or a full international
  /// number (+9665XXXXXXXX, 009665XXXXXXXX); see [normalizeSaudiMobile].
  static String? saudiMobile(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Phone number is required';
    }
    if (normalizeSaudiMobile(text) == null) {
      return saudiMobileError;
    }
    return null;
  }

  /// Returns [value] as +9665XXXXXXXX, or null if it is not a valid Saudi
  /// mobile number. Spaces, dashes and brackets are ignored, and a pasted
  /// +966 / 00966 / 966 prefix or a leading 0 is not duplicated.
  static String? normalizeSaudiMobile(String value) {
    final compact = value.trim().replaceAll(RegExp(r'[\s\-()]'), '');
    final match = _saudiMobile.firstMatch(compact);
    return match == null ? null : '+966${match.group(1)}';
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

/// One rule of the ReStep password policy.
class PasswordRequirement {
  const PasswordRequirement._(this.label, this.errorMessage, this._test);

  /// Short text shown in the live checklist.
  final String label;

  /// Message shown under the field when this rule fails.
  final String errorMessage;

  final bool Function(String password) _test;

  bool isMetBy(String password) => _test(password);
}

/// ReStep password policy for new and changed passwords.
///
/// The authoritative enforcement is the Firebase Authentication password
/// policy (Console > Authentication > Settings > Password policy), which must
/// be configured with the same rules. These checks only give early feedback.
/// Sign-in is deliberately NOT checked against this policy so existing users
/// with older passwords can still log in.
class PasswordPolicy {
  PasswordPolicy._();

  static const int minLength = 8;

  /// The special characters Firebase Authentication accepts for its
  /// "special character" requirement. Characters outside this set (such as
  /// `+`, `=` or a space) are allowed in a password but do not count.
  static const String specialCharacters = r'^$*.[]{}()?"!@#%&/\,><' "'" r':;|_~`-';

  static final RegExp _upper = RegExp(r'[A-Z]');
  static final RegExp _lower = RegExp(r'[a-z]');
  static final RegExp _digit = RegExp(r'[0-9]');

  static bool _hasSpecial(String value) =>
      value.split('').any(specialCharacters.contains);

  static final List<PasswordRequirement> requirements = [
    PasswordRequirement._(
      'At least $minLength characters',
      'Use at least $minLength characters',
      (v) => v.length >= minLength,
    ),
    PasswordRequirement._(
      'One uppercase letter (A–Z)',
      'Include at least one uppercase letter (A–Z)',
      _upper.hasMatch,
    ),
    PasswordRequirement._(
      'One lowercase letter (a–z)',
      'Include at least one lowercase letter (a–z)',
      _lower.hasMatch,
    ),
    PasswordRequirement._(
      'One number (0–9)',
      'Include at least one number (0–9)',
      _digit.hasMatch,
    ),
    PasswordRequirement._(
      'One special character (e.g. @ # \$ ! %)',
      'Include at least one special character, such as @ # \$ ! %',
      _hasSpecial,
    ),
  ];

  static bool isValid(String password) =>
      requirements.every((rule) => rule.isMetBy(password));

  /// One-sentence summary, used where a checklist is not shown.
  static const String summary =
      'Passwords must be at least $minLength characters and include an '
      'uppercase letter, a lowercase letter, a number and a special '
      'character (such as @ # \$ ! %).';
}
