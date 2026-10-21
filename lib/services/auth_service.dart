import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/utils/validators.dart';
import '../models/patient.dart';

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thrown by [AuthService.deleteAccount] when Firebase needs the patient to
/// confirm their password first. Nothing has been deleted when it is thrown.
class ReauthenticationRequiredException extends AuthException {
  const ReauthenticationRequiredException()
      : super('For your security, please enter your password again to '
            'delete your account.');
}

abstract class AuthService {
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

  /// Deletes the patient's Firestore data and Firebase Auth account.
  ///
  /// Throws [ReauthenticationRequiredException] (without deleting anything)
  /// when the session is too old; call again with the patient's [password].
  Future<void> deleteAccount({String? password});
}

class FirebaseAuthService implements AuthService {
  FirebaseAuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    DateTime Function()? clock,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _clock = clock ?? DateTime.now;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final DateTime Function() _clock;

  /// Firebase rejects account deletion when the last sign-in is older than
  /// about five minutes. Stay under that so the password is asked for before
  /// anything is deleted, rather than discovered halfway through.
  static const Duration _recentLoginWindow = Duration(minutes: 4);

  /// Sub-collections under patients/{patientEmail} (see FirebaseDataRepository).
  static const List<String> _patientSubcollections = [
    'emergency_contacts',
    'reminders',
    'fog_episodes',
    'devices',
    'settings',
  ];

  /// Firestore allows at most 500 writes per batch.
  static const int _maxBatchWrites = 500;

  CollectionReference<Map<String, dynamic>> get _patients =>
      _firestore.collection('patients');

  @override
  Future<Patient?> restoreSession() async {
    final user = _auth.currentUser;

    if (user == null) return null;

    final email = user.email;
    if (email == null) return null;

    return _getPatient(email);
  }

  @override
  Future<Patient> signIn(String email, String password) async {
    final normalizedEmail = email.trim().toLowerCase();

    try {
      await _auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      final patient = await _getPatient(normalizedEmail);

      if (patient == null) {
        throw const AuthException('Patient profile was not found.');
      }

      return patient;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_authErrorMessage(e));
    }
  }

  @override
  Future<Patient> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    // Reject weak passwords before contacting Firebase. Firebase's own
    // password policy remains the authoritative, server-side check.
    if (!PasswordPolicy.isValid(password)) {
      throw const AuthException(PasswordPolicy.summary);
    }

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        throw const AuthException('Account could not be created.');
      }

      final patient = Patient(
        id: normalizedEmail,
        fullName: fullName.trim(),
        email: normalizedEmail,
      );

      await _patients.doc(normalizedEmail).set({
        'email': normalizedEmail,
        'full_name': patient.fullName,
        'birth_date': null,
        'waiting_time': null,
      });

      return patient;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_authErrorMessage(e));
    } on FirebaseException catch (e) {
      throw AuthException(e.message ?? 'Could not save patient profile.');
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
    } on FirebaseAuthException catch (e) {
      // Don't reveal whether an account exists for this email; the screen
      // already says "If an account exists...".
      if (e.code == 'user-not-found') return;
      throw AuthException(_authErrorMessage(e));
    }
  }

  @override
  Future<Patient> updateProfile(Patient patient) async {
    try {
      // The email is never updated here: it is the Firestore document ID and
      // the Firebase Auth login, both fixed at registration.
      await _patients.doc(patient.id).update({
        'full_name': patient.fullName,
        'birth_date': patient.dateOfBirth,
        'waiting_time': patient.waitingTime,
      });

      // The document ID is the registered email, so return that rather than
      // whatever email the caller passed in.
      return patient.copyWith(email: patient.id);
    } on FirebaseException catch (e) {
      throw AuthException(e.message ?? 'Could not update patient profile.');
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
  }

  @override
  Future<void> deleteAccount({String? password}) async {
    final user = _auth.currentUser;

    if (user == null) return;

    final email = user.email?.trim().toLowerCase();

    // 1. Make sure Firebase will accept the deletion before touching any data.
    if (password != null) {
      if (email == null) {
        throw const AuthException('Could not confirm your identity.');
      }
      try {
        await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: email, password: password),
        );
      } on FirebaseAuthException catch (e) {
        switch (e.code) {
          case 'wrong-password':
          case 'invalid-credential':
          case 'user-mismatch':
            throw const AuthException(
              'Incorrect password. Please check and try again.',
            );
          default:
            throw AuthException(_authErrorMessage(e));
        }
      }
    } else if (!await _hasRecentLogin(user)) {
      throw const ReauthenticationRequiredException();
    }

    // 2. Delete the Firestore data, keeping a copy so it can be restored.
    var backup =
        <DocumentReference<Map<String, dynamic>>, Map<String, dynamic>>{};
    if (email != null) {
      try {
        backup = await _readPatientData(email);
        await _deleteDocuments(backup.keys);
      } on FirebaseException catch (e) {
        // Each batch applies fully or not at all; restore anything an earlier
        // batch already removed.
        await _tryRestore(backup);
        throw AuthException(
          e.message ?? 'Could not delete your account. Please try again.',
        );
      }
    }

    // 3. Delete the Firebase Auth account. If that still fails, put the data
    // back so the patient keeps a working account.
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      final restored = await _tryRestore(backup);
      if (!restored) {
        throw const AuthException(
          'Your account could not be deleted and some of your data could not '
          'be restored. Please try again or contact support.',
        );
      }
      if (e.code == 'requires-recent-login') {
        throw const ReauthenticationRequiredException();
      }
      throw AuthException(_authErrorMessage(e));
    }
  }

  Future<bool> _hasRecentLogin(User user) async {
    try {
      final authTime = (await user.getIdTokenResult()).authTime;
      if (authTime == null) return false;
      return _clock().difference(authTime) < _recentLoginWindow;
    } on FirebaseAuthException {
      // Can't tell (e.g. offline): ask for the password to be safe.
      return false;
    }
  }

  /// Reads the patient document and every document in its sub-collections.
  Future<Map<DocumentReference<Map<String, dynamic>>, Map<String, dynamic>>>
      _readPatientData(String email) async {
    final patientDoc = _patients.doc(email);
    final data =
        <DocumentReference<Map<String, dynamic>>, Map<String, dynamic>>{};

    for (final name in _patientSubcollections) {
      final snapshot = await patientDoc.collection(name).get();
      for (final doc in snapshot.docs) {
        data[doc.reference] = doc.data();
      }
    }

    final snapshot = await patientDoc.get();
    if (snapshot.exists) data[patientDoc] = snapshot.data()!;

    return data;
  }

  Future<void> _deleteDocuments(
    Iterable<DocumentReference<Map<String, dynamic>>> refs,
  ) async {
    final list = refs.toList();
    for (var i = 0; i < list.length; i += _maxBatchWrites) {
      final batch = _firestore.batch();
      for (final ref in list.skip(i).take(_maxBatchWrites)) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }

  /// Writes [backup] back to Firestore. Returns false if that failed.
  Future<bool> _tryRestore(
    Map<DocumentReference<Map<String, dynamic>>, Map<String, dynamic>> backup,
  ) async {
    try {
      final entries = backup.entries.toList();
      for (var i = 0; i < entries.length; i += _maxBatchWrites) {
        final batch = _firestore.batch();
        for (final entry in entries.skip(i).take(_maxBatchWrites)) {
          batch.set(entry.key, entry.value);
        }
        await batch.commit();
      }
      return true;
    } on FirebaseException {
      return false;
    }
  }

  Future<Patient?> _getPatient(String email) async {
    final normalizedEmail = email.trim().toLowerCase();

    final snapshot = await _patients.doc(normalizedEmail).get();

    if (!snapshot.exists) return null;

    final data = snapshot.data()!;

    return Patient(
      id: normalizedEmail,
      fullName: data['full_name'] as String? ?? '',
      email: data['email'] as String? ?? normalizedEmail,
      dateOfBirth: _parseDate(data['birth_date']),
      waitingTime: (data['waiting_time'] as num?)?.toInt(),
    );
  }

  DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    return null;
  }

  String _authErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email is already registered. Try signing in instead.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
      case 'password-does-not-meet-requirements':
        return PasswordPolicy.summary;
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password. Please check and try again.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'requires-recent-login':
        return const ReauthenticationRequiredException().message;
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      default:
        // Some platform SDK versions report a password policy violation only
        // in the message, under a generic code.
        if ((e.message ?? '').contains('PASSWORD_DOES_NOT_MEET_REQUIREMENTS')) {
          return PasswordPolicy.summary;
        }
        return e.message ?? 'Authentication failed.';
    }
  }
}
