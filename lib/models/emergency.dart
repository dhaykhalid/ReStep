
/// A person who receives an SMS when emergency escalation conditions are met.
/// They do not use the ReStep app.
class EmergencyContact {
  const EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    this.isDesignated = false,
  });

  final String id;
  final String name;
  final String phone;
  final bool isDesignated;

  EmergencyContact copyWith({
    String? name,
    String? phone,
    bool? isDesignated,
  }) {
    return EmergencyContact(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      isDesignated: isDesignated ?? this.isDesignated,
    );
  }
}

class EscalationSettings {
  const EscalationSettings({
    required this.waitSeconds,
  });

  /// How long the patient has to respond before the contact is alerted.
  final int waitSeconds;
}

