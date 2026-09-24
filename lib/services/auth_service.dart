import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth auth = FirebaseAuth.instance;

  /// Obergrenze für den SMS-Versand inkl. reCAPTCHA. Auf Web wartet
  /// verifyPhoneNumber() auf das unsichtbare reCAPTCHA; wird dessen
  /// Bild-Challenge geschlossen, nicht angezeigt oder läuft sie ab (nach
  /// 2 Minuten), resolved/rejected das Firebase-Promise nie. Ohne Timeout
  /// bliebe die UI dann dauerhaft im Ladezustand.
  static const Duration phoneVerificationTimeout = Duration(seconds: 120);

  Future<void> _withPhoneVerificationTimeout(Future<void> verification) {
    return verification.timeout(
      phoneVerificationTimeout,
      onTimeout: () => throw FirebaseAuthException(
        code: "recaptcha-timeout",
        message: "Phone verification did not complete (reCAPTCHA pending).",
      ),
    );
  }

  Future<User> signInAnonymously() async {
    final result = await auth.signInAnonymously();
    return result.user!;
  }

  String? get uid => auth.currentUser?.uid;

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) {
    return auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
  }) {
    // Die Bestätigungs-Mail verschickt der EmailVerificationScreen beim
    // Öffnen, auf den AuthGate nach der Registrierung automatisch wechselt.
    return auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> sendEmailVerification() async {
    await auth.currentUser?.sendEmailVerification();
  }

  Future<void> reloadCurrentUser() async {
    await auth.currentUser?.reload();
  }

  Future<void> sendPasswordReset(String email) {
    return auth.sendPasswordResetEmail(email: email);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await reauthenticateWithPassword(currentPassword);
    await auth.currentUser?.updatePassword(newPassword);
  }

  /// Setzt ein neues Passwort, ohne erneut anzumelden. Nur nach einer
  /// bereits abgeschlossenen Reauthentifizierung verwenden (z. B. nachdem
  /// die MFA-Challenge von [changePassword] gelöst wurde).
  Future<void> updatePassword(String newPassword) async {
    await auth.currentUser?.updatePassword(newPassword);
  }

  Future<void> reauthenticateWithPassword(String currentPassword) async {
    final user = auth.currentUser;
    final email = user?.email;

    if (user == null || email == null) {
      throw FirebaseAuthException(code: "user-not-found");
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );

    await user.reauthenticateWithCredential(credential);
  }

  Future<void> reauthenticateWithGoogle() async {
    final user = auth.currentUser;

    if (user == null) {
      throw FirebaseAuthException(code: "user-not-found");
    }

    await user.reauthenticateWithProvider(GoogleAuthProvider());
  }

  Future<UserCredential> signInWithGoogle() {
    return auth.signInWithProvider(GoogleAuthProvider());
  }

  Future<void> signOut() {
    return auth.signOut();
  }

  bool get isEmailVerified => auth.currentUser?.emailVerified ?? false;

  bool get isEmailPasswordUser => _hasProvider("password");

  bool get isGoogleUser => _hasProvider("google.com");

  bool get isPhoneUser => _hasProvider("phone");

  bool _hasProvider(String providerId) {
    final user = auth.currentUser;
    if (user == null) return false;

    return user.providerData.any((info) => info.providerId == providerId);
  }

  // ==========================
  // TELEFON-LOGIN
  // ==========================

  /// Startet die Telefonnummer-Verifizierung für einen eigenständigen
  /// Phone-Login (kein Multi-Faktor-Kontext). Auf Web erzeugt Firebase
  /// automatisch ein unsichtbares reCAPTCHA-Widget im Hintergrund.
  Future<void> startPhoneSignIn({
    required String phoneNumber,
    required PhoneVerificationCompleted verificationCompleted,
    required PhoneVerificationFailed verificationFailed,
    required PhoneCodeSent codeSent,
    required PhoneCodeAutoRetrievalTimeout codeAutoRetrievalTimeout,
  }) {
    return _withPhoneVerificationTimeout(
      auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: verificationCompleted,
        verificationFailed: verificationFailed,
        codeSent: codeSent,
        codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
      ),
    );
  }

  Future<UserCredential> signInWithSmsCode({
    required String verificationId,
    required String smsCode,
  }) {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    return auth.signInWithCredential(credential);
  }

  // ==========================
  // SMS MULTI-FAKTOR-AUTHENTIFIZIERUNG
  // ==========================

  Future<List<MultiFactorInfo>> getEnrolledMfaFactors() async {
    final user = auth.currentUser;
    if (user == null) return [];

    return user.multiFactor.getEnrolledFactors();
  }

  Future<MultiFactorSession> getMfaEnrollmentSession() async {
    final user = auth.currentUser;

    if (user == null) {
      throw FirebaseAuthException(code: "user-not-found");
    }

    return user.multiFactor.getSession();
  }

  /// Startet die Telefonnummer-Verifizierung im Rahmen einer MFA-Aktivierung.
  Future<void> startMfaPhoneEnrollment({
    required String phoneNumber,
    required MultiFactorSession session,
    required PhoneVerificationCompleted verificationCompleted,
    required PhoneVerificationFailed verificationFailed,
    required PhoneCodeSent codeSent,
    required PhoneCodeAutoRetrievalTimeout codeAutoRetrievalTimeout,
  }) {
    return _withPhoneVerificationTimeout(
      auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        multiFactorSession: session,
        verificationCompleted: verificationCompleted,
        verificationFailed: verificationFailed,
        codeSent: codeSent,
        codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
      ),
    );
  }

  Future<void> enrollPhoneMfaFactor({
    required String verificationId,
    required String smsCode,
    String? displayName,
  }) async {
    final user = auth.currentUser;

    if (user == null) {
      throw FirebaseAuthException(code: "user-not-found");
    }

    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    final assertion = PhoneMultiFactorGenerator.getAssertion(credential);

    await user.multiFactor.enroll(assertion, displayName: displayName);
  }

  Future<void> unenrollMfaFactor(MultiFactorInfo factor) async {
    final user = auth.currentUser;

    if (user == null) {
      throw FirebaseAuthException(code: "user-not-found");
    }

    await user.multiFactor.unenroll(multiFactorInfo: factor);
  }

  /// Startet die Telefonnummer-Verifizierung, um eine MFA-Challenge während
  /// des Logins (siehe [FirebaseAuthMultiFactorException.resolver]) zu lösen.
  Future<void> startMfaSignInChallenge({
    required MultiFactorResolver resolver,
    required PhoneMultiFactorInfo hint,
    required PhoneVerificationCompleted verificationCompleted,
    required PhoneVerificationFailed verificationFailed,
    required PhoneCodeSent codeSent,
    required PhoneCodeAutoRetrievalTimeout codeAutoRetrievalTimeout,
  }) {
    return _withPhoneVerificationTimeout(
      auth.verifyPhoneNumber(
        multiFactorInfo: hint,
        multiFactorSession: resolver.session,
        verificationCompleted: verificationCompleted,
        verificationFailed: verificationFailed,
        codeSent: codeSent,
        codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
      ),
    );
  }

  // ==========================
  // TOTP MULTI-FAKTOR-AUTHENTIFIZIERUNG (AUTHENTICATOR-APP)
  // ==========================
  //
  // Unabhängig von Phone-Auth: TOTP braucht weder verifyPhoneNumber() noch
  // reCAPTCHA. Secret-Erzeugung und Code-Prüfung erfolgen ausschließlich
  // serverseitig durch Firebase; das Secret wird nirgends gespeichert.

  /// Erzeugt ein neues TOTP-Secret für die Einrichtung. Erfordert eine
  /// kürzliche Anmeldung (siehe [getMfaEnrollmentSession]).
  Future<TotpSecret> generateTotpSecret() async {
    final session = await getMfaEnrollmentSession();

    try {
      return await TotpMultiFactorGenerator.generateSecret(session);
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      // firebase_auth_web reicht Fehler von generateSecret() als rohen
      // JS-Fehler durch statt als FirebaseAuthException. Den Firebase-Code
      // ("auth/...") herausziehen, damit die UI eine normale Fehlermeldung
      // zeigen kann statt endlos zu laden.
      throw _toFirebaseAuthException(e);
    }
  }

  static FirebaseAuthException _toFirebaseAuthException(Object error) {
    final match = RegExp(r"auth/([a-z0-9-]+)").firstMatch(error.toString());
    return FirebaseAuthException(code: match?.group(1) ?? "unknown");
  }

  Future<void> enrollTotpMfaFactor({
    required TotpSecret secret,
    required String oneTimePassword,
    String? displayName,
  }) async {
    final user = auth.currentUser;

    if (user == null) {
      throw FirebaseAuthException(code: "user-not-found");
    }

    final assertion = await TotpMultiFactorGenerator.getAssertionForEnrollment(
      secret,
      oneTimePassword,
    );

    await user.multiFactor.enroll(assertion, displayName: displayName);
  }

  Future<UserCredential> resolveMfaSignInWithTotp({
    required MultiFactorResolver resolver,
    required TotpMultiFactorInfo hint,
    required String oneTimePassword,
  }) async {
    final assertion = await TotpMultiFactorGenerator.getAssertionForSignIn(
      hint.uid,
      oneTimePassword,
    );

    return resolver.resolveSignIn(assertion);
  }

  Future<UserCredential> resolveMfaSignIn({
    required MultiFactorResolver resolver,
    required String verificationId,
    required String smsCode,
  }) {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    final assertion = PhoneMultiFactorGenerator.getAssertion(credential);

    return resolver.resolveSignIn(assertion);
  }
}
