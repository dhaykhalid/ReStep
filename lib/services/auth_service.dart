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

  Future<void> deleteAccount();
}

class FirebaseAuthService implements AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
        'phone': null,
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
        'phone': patient.phone,
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
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;

    if (user == null) return;

    final email = user.email;

    try {
      if (email != null) {
        await _patients.doc(email.toLowerCase()).delete();
      }

      await user.delete();
    } on FirebaseAuthException catch (e) {
      throw AuthException(_authErrorMessage(e));
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
      phone: data['phone'] as String?,
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
        return 'For your security, please sign out, sign in again and '
            'then try once more.';
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
