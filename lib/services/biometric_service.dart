import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;

class BiometricAuthResult {
  const BiometricAuthResult({
    required this.authenticated,
    this.errorType,
  });

  final bool authenticated;
  final String? errorType;
}

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> canCheckBiometrics() async {
    try {
      return await _auth.canCheckBiometrics;
    } on PlatformException catch (_) {
      return false;
    }
  }

  Future<List<String>> availableBiometrics() async {
    try {
      final types = await _auth.getAvailableBiometrics();
      return types.map((type) => type.name).toList(growable: false);
    } on PlatformException catch (_) {
      return const <String>[];
    }
  }

  // Is biometric hardware available on device?
  Future<bool> isBiometricsAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } on PlatformException catch (_) {
      return false;
    }
  }

  Future<BiometricAuthResult> authenticateDetailed({
    required String localizedReason,
  }) async {
    try {
      final authenticated = await _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      return BiometricAuthResult(authenticated: authenticated);
    } on PlatformException catch (e) {
      if (e.code == auth_error.notAvailable) {
        return const BiometricAuthResult(
          authenticated: false,
          errorType: 'PlatformException:notAvailable',
        );
      }
      return BiometricAuthResult(
        authenticated: false,
        errorType: 'PlatformException:${e.code}',
      );
    } catch (e) {
      return BiometricAuthResult(
        authenticated: false,
        errorType: e.runtimeType.toString(),
      );
    }
  }

  // Do fingerprint/face auth
  Future<bool> authenticate({required String localizedReason}) async {
    final result = await authenticateDetailed(localizedReason: localizedReason);
    return result.authenticated;
  }
}
