import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth auth = FirebaseAuth.instance;

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
  }) async {
    final credential = await auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await credential.user?.sendEmailVerification();

    return credential;
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
    await user.updatePassword(newPassword);
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

  bool _hasProvider(String providerId) {
    final user = auth.currentUser;
    if (user == null) return false;

    return user.providerData.any((info) => info.providerId == providerId);
  }
}
