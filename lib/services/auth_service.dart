import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth auth = FirebaseAuth.instance;

  Future<User> signInAnonymously() async {
    final result = await auth.signInAnonymously();
    return result.user!;
  }

  String? get uid => auth.currentUser?.uid;
}
