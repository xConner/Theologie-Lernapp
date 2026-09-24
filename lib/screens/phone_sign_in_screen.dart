import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import '../services/auth_error_translator.dart';
import '../theme/app_theme.dart';
import '../utils/phone_number_utils.dart';
import '../widgets/recaptcha_notice.dart';

class PhoneSignInScreen extends StatefulWidget {
  const PhoneSignInScreen({super.key});

  @override
  State<PhoneSignInScreen> createState() => _PhoneSignInScreenState();
}

class _PhoneSignInScreenState extends State<PhoneSignInScreen> {
  final authService = AuthService();
  final phoneController = TextEditingController();
  final codeController = TextEditingController();

  bool sendingCode = false;
  bool verifying = false;
  bool codeSent = false;
  String? verificationId;
  String? error;

  @override
  void dispose() {
    phoneController.dispose();
    codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phoneNumber = normalizePhoneNumber(phoneController.text);

    if (!isValidE164PhoneNumber(phoneNumber)) {
      setState(() {
        error =
            "Bitte gib eine gültige Telefonnummer inkl. Ländervorwahl ein, z. B. +49...";
      });
      return;
    }

    setState(() {
      sendingCode = true;
      error = null;
    });

    try {
      await authService.startPhoneSignIn(
        phoneNumber: phoneNumber,
        verificationCompleted: (_) {},
        verificationFailed: (e) {
          if (!mounted) return;
          setState(() {
            sendingCode = false;
            error = logAndDescribeAuthErrorForDiagnosis(
              e,
              context: "PhoneSignIn.verificationFailed",
            );
          });
        },
        codeSent: (id, _) {
          if (!mounted) return;
          setState(() {
            sendingCode = false;
            codeSent = true;
            verificationId = id;
          });
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        sendingCode = false;
        error = logAndDescribeAuthErrorForDiagnosis(
          e,
          context: "PhoneSignIn.startPhoneSignIn",
        );
      });
    } catch (e) {
      // Fängt auch rohe, nicht-Firebase-Fehler ab (z. B. wenn die
      // reCAPTCHA-Initialisierung selbst mit einem generischen JS-Error
      // fehlschlägt) - genau das wollen wir hier sichtbar machen.
      if (!mounted) return;
      setState(() {
        sendingCode = false;
        error = logAndDescribeAuthErrorForDiagnosis(
          e,
          context: "PhoneSignIn.startPhoneSignIn.raw",
        );
      });
    }
  }

  Future<void> _confirmCode() async {
    final id = verificationId;
    if (id == null) return;

    final code = codeController.text.trim();
    if (code.isEmpty) {
      setState(() {
        error = "Bitte gib den erhaltenen Code ein.";
      });
      return;
    }

    setState(() {
      verifying = true;
      error = null;
    });

    try {
      await authService.signInWithSmsCode(
        verificationId: id,
        smsCode: code,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        error = describeAuthError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          verifying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = sendingCode || verifying;

    return Scaffold(
      appBar: AppBar(title: const Text("Mit Telefonnummer anmelden")),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.phone_iphone_rounded,
                      size: 40,
                      color: AppColors.primary,
                    ),

                    const SizedBox(height: 12),

                    Text(
                      "Telefonnummer",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),

                    const SizedBox(height: 20),

                    TextField(
                      controller: phoneController,
                      enabled: !codeSent,
                      keyboardType: TextInputType.phone,
                      onChanged: (_) {
                        if (error != null) {
                          setState(() {
                            error = null;
                          });
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: "Telefonnummer (z. B. +49...)",
                        prefixIcon: Icon(Icons.dialpad_rounded),
                      ),
                    ),

                    if (codeSent) ...[
                      const SizedBox(height: 14),
                      TextField(
                        controller: codeController,
                        keyboardType: TextInputType.number,
                        onChanged: (_) {
                          if (error != null) {
                            setState(() {
                              error = null;
                            });
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: "SMS-Code",
                          prefixIcon: Icon(Icons.pin_rounded),
                        ),
                      ),
                    ],

                    if (error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        error!,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ],

                    const SizedBox(height: 20),

                    ElevatedButton(
                      onPressed: busy
                          ? null
                          : (codeSent ? _confirmCode : _sendCode),
                      child: busy
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(codeSent ? "Bestätigen" : "Code senden"),
                    ),

                    if (codeSent) ...[
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: busy ? null : _sendCode,
                        child: const Text("Code erneut senden"),
                      ),
                    ],

                    // Firebase rendert für Phone-Auth auf Web automatisch ein
                    // unsichtbares reCAPTCHA-Widget; kein eigener Container
                    // nötig. Das Badge ist ausgeblendet, daher der Hinweis.
                    const RecaptchaNotice(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
