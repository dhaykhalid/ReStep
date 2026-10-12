import '../data/mock/mock_data.dart';
import '../models/patient.dart';

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Account and profile operations.
/// TODO(backend): implement with Firebase Authentication + the user profile document.
abstract class AuthService {
  /// Returns the patient if a session is still active (stay signed in).
  Future<Patient?> restoreSession();

  Future<Patient> signIn(String email, String password);

  Future<Patient> register({
    required String fullName,
    required String email,
    required String password,
  });

  Future<void> sendPasswordReset(String email);

  Future<Patient> updateProfile(Patient patient);

  Future<void> signOut();

  Future<void> deleteAccount();
}

class _Account {
  _Account(this.password, this.patient);
  final String password;
  Patient patient;
}

/// In-memory implementation used for the frontend prototype.
class MockAuthService implements AuthService {
  MockAuthService() {
    _accounts[MockData.demoPatient.email] =
        _Account('Restep123', MockData.demoPatient);
  }

  final Map<String, _Account> _accounts = {};
  Patient? _current;

  Future<void> _latency([int ms = 800]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  @override
  Future<Patient?> restoreSession() async => _current;

  @override
  Future<Patient> signIn(String email, String password) async {
    await _latency();
    final account = _accounts[email.trim().toLowerCase()];
    if (account == null || account.password != password) {
      throw const AuthException(
          'Incorrect email or password. Please check and try again.');
    }
    _current = account.patient;
    return account.patient;
  }

  @override
  Future<Patient> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    await _latency();
    final key = email.trim().toLowerCase();
    if (_accounts.containsKey(key)) {
      throw const AuthException(
          'This email is already registered. Try signing in instead.');
    }
    final patient = Patient(
      id: 'patient-${_accounts.length + 1}',
      fullName: fullName.trim(),
      email: key,
    );
    _accounts[key] = _Account(password, patient);
    _current = patient;
    return patient;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    // Always succeeds so the response does not reveal which emails exist.
    await _latency(900);
  }

  @override
  Future<Patient> updateProfile(Patient patient) async {
    await _latency(500);
    for (final entry in _accounts.entries) {
      if (entry.value.patient.id == patient.id) {
        entry.value.patient = patient;
      }
    }
    _current = patient;
    return patient;
  }

  @override
  Future<void> signOut() async {
    _current = null;
  }

  @override
  Future<void> deleteAccount() async {
    await _latency(600);
    _accounts.removeWhere((_, a) => a.patient.id == _current?.id);
    _current = null;
  }
}
