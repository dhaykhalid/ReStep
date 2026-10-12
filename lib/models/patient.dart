/// The signed-in patient (account + profile).
class Patient {
  const Patient({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    this.dateOfBirth,
  });

  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final DateTime? dateOfBirth;

  String get firstName {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty || parts.first.isEmpty ? 'there' : parts.first;
  }

  String get initials {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  Patient copyWith({
    String? fullName,
    String? email,
    String? phone,
    DateTime? dateOfBirth,
  }) {
    return Patient(
      id: id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
    );
  }
}
