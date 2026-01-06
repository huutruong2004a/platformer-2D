import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Lấy User ID hiện tại
  String? get currentUserId => _auth.currentUser?.uid;

  // 1. Đăng nhập Ẩn danh trên Firebase
  Future<UserCredential?> signInAnonymously() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      print("Firebase Signed In UID: ${userCredential.user?.uid}");
      return userCredential;
    } catch (e) {
      print("Firebase Auth Error: $e");
      return null;
    }
  }

  // 2. Đăng xuất
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
