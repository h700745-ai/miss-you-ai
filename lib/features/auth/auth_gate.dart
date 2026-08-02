import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/services/auth_service.dart';
import '../../core/models/couple_model.dart';
import '../home/home_screen.dart';
import 'splash_screen.dart';
import 'login_screen.dart';
import 'pairing_screen.dart';

/// Root routing widget. Decides what the person sees based on:
/// 1. Are they logged in at all? -> LoginScreen if not
/// 2. Are they paired with a partner yet? -> PairingScreen if not
/// 3. Otherwise -> HomeScreen
///
/// IMPORTANT: streams are cached as fields (created once, in initState)
/// rather than recreated inside build(). Recreating a stream on every
/// build makes StreamBuilder treat it as brand new and briefly reset
/// to "no data yet" -- which is what caused the login-screen flash
/// when navigating back from a feature screen.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Stream<User?> _authStream;

  // Cache the couple stream per-uid so it's only recreated when the
  // logged-in user actually changes (not on every rebuild).
  String? _coupleStreamUid;
  Stream<CoupleModel?>? _coupleStream;

  @override
  void initState() {
    super.initState();
    _authStream = AuthService.instance.authStateChanges;
  }

  Stream<CoupleModel?> _coupleStreamFor(String uid) {
    if (_coupleStreamUid != uid || _coupleStream == null) {
      _coupleStreamUid = uid;
      _coupleStream = AuthService.instance.watchCoupleForUser(uid);
    }
    return _coupleStream!;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authStream,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        final firebaseUser = authSnapshot.data;
        if (firebaseUser == null) {
          return const LoginScreen();
        }

        return StreamBuilder<CoupleModel?>(
          stream: _coupleStreamFor(firebaseUser.uid),
          builder: (context, coupleSnapshot) {
            if (coupleSnapshot.connectionState == ConnectionState.waiting) {
              return const SplashScreen();
            }

            if (coupleSnapshot.data == null) {
              return const PairingScreen();
            }

            return const HomeScreen();
          },
        );
      },
    );
  }
}
