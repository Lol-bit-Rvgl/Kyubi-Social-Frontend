import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/utils/open_url.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/brand_backdrop.dart';
import '../../../../core/widgets/google_sign_in_button.dart';
import '../../../../core/widgets/kyubi_logo.dart';
import '../../../../services/auth_controller.dart';

/// Consistent input decoration for Kyubi dark theme.
InputDecoration _kyubiInputDecoration({
  required String labelText,
  String? helperText,
  Widget? prefixIcon,
  String? prefixText,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    labelText: labelText,
    helperText: helperText,
    prefixIcon: prefixIcon != null
        ? Padding(padding: const EdgeInsets.all(12), child: prefixIcon)
        : null,
    prefixText: prefixText,
    suffixIcon: suffixIcon != null
        ? Padding(padding: const EdgeInsets.all(12), child: suffixIcon)
        : null,
    filled: true,
    fillColor: AppColors.ink800,
    labelStyle: TextStyle(color: AppColors.gray400),
    floatingLabelStyle: TextStyle(color: AppColors.primary),
    helperStyle: TextStyle(color: AppColors.gray500, fontSize: 12),
    prefixIconColor: AppColors.gray500,
    prefixStyle: TextStyle(color: AppColors.gray300),
    suffixIconColor: AppColors.gray500,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppDimens.md,
      vertical: 16,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      borderSide: BorderSide(color: AppColors.ink600, width: 1.5),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      borderSide: BorderSide(color: AppColors.ink600, width: 1.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      borderSide: BorderSide(color: AppColors.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      borderSide: BorderSide(color: AppColors.danger, width: 1.5),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      borderSide: BorderSide(color: AppColors.danger, width: 2),
    ),
    errorStyle: TextStyle(color: AppColors.danger, fontSize: 12),
  );
}

/// Pantalla de registro.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _agree = true;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agree) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes aceptar los términos y condiciones'),
        ),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    final ok = await ref
        .read(authControllerProvider.notifier)
        .register(
          email: _emailController.text.trim(),
          username: _usernameController.text.trim(),
          password: _passwordController.text,
          displayName: _nameController.text.trim(),
        );
    if (!mounted) return;
    if (ok) {
      context.go('/onboarding');
    } else {
      _showError(ref.read(authControllerProvider).error);
    }
  }

  Future<void> _signInWithGoogle() async {
    FocusScope.of(context).unfocus();
    final ok = await ref
        .read(authControllerProvider.notifier)
        .signInWithGoogle();
    if (!mounted) return;
    if (ok) {
      final onboarding =
          ref.read(authControllerProvider).user?.onboardingCompleted ?? false;
      context.go(onboarding ? '/app/feed' : '/onboarding');
    } else {
      final error = ref.read(authControllerProvider).error;
      if (error != null && error.isNotEmpty) {
        _showError(error);
      }
    }
  }

  void _showError(String? error) {
    String message = error ?? 'No se pudo crear la cuenta';
    if (error != null) {
      if (error.contains('409') ||
          error.toLowerCase().contains('ya está en uso') ||
          error.toLowerCase().contains('ya está registrado')) {
        message = 'Ese correo electrónico o usuario ya está en uso';
      } else if (error.contains('DioException') ||
          error.contains('[bad response]')) {
        message = 'No se pudo crear la cuenta. Por favor verifica tus datos.';
      }
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openDoc(String url) async {
    final ok = await openUrl(url);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el documento')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authControllerProvider).busy;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(child: BrandBackdrop(strength: 0.7)),
          ),
          Positioned.fill(
            child: SafeArea(
              child: SingleChildScrollView(
                padding: AppDimens.pagePadding,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(
                          child: KyubiLogo(size: 72, showGlow: false),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Únete a Kyubi',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Crea tu cuenta para empezar a compartir',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _nameController,
                          textInputAction: TextInputAction.next,
                          validator: Validators.displayName,
                          decoration: _kyubiInputDecoration(
                            labelText: 'Nombre',
                            prefixIcon: const Icon(Icons.badge_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _usernameController,
                          textInputAction: TextInputAction.next,
                          validator: Validators.username,
                          decoration: _kyubiInputDecoration(
                            labelText: 'Nombre de usuario',
                            prefixText: '@',
                            prefixIcon: const Icon(
                              Icons.alternate_email_rounded,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: Validators.email,
                          decoration: _kyubiInputDecoration(
                            labelText: 'Correo electrónico',
                            prefixIcon: const Icon(Icons.mail_outline_rounded),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          validator: Validators.password,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: _kyubiInputDecoration(
                            labelText: 'Contraseña',
                            helperText: 'Mínimo 8 caracteres',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        CheckboxListTile(
                          value: _agree,
                          onChanged: (v) => setState(() => _agree = v ?? false),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text.rich(
                            TextSpan(
                              text: 'Acepto los ',
                              style: TextStyle(
                                fontSize: 13,
                                color: scheme.onSurfaceVariant,
                              ),
                              children: [
                                TextSpan(
                                  text: 'términos y condiciones',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () =>
                                        _openDoc(AppConstants.termsUrl),
                                ),
                                const TextSpan(text: ' y la '),
                                TextSpan(
                                  text: 'política de privacidad',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () =>
                                        _openDoc(AppConstants.privacyUrl),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        AppButton(
                          label: 'Crear cuenta con correo',
                          icon: Icons.person_add_alt_1_rounded,
                          loading: busy,
                          onPressed: _submit,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppDimens.sm,
                              ),
                              child: Text(
                                'o continuar con',
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 16),
                        GoogleSignInButton(
                          loading: busy,
                          label: 'Registrarse con Google',
                          onPressed: _signInWithGoogle,
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '¿Ya tienes cuenta?',
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                            TextButton(
                              onPressed: () => context.go('/login'),
                              child: const Text('Inicia sesión'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
