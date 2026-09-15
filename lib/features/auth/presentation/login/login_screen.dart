import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/animated_fluid_background.dart';
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

/// Pantalla de inicio de sesión.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final ok = await ref
        .read(authControllerProvider.notifier)
        .login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
    if (!mounted) return;
    if (ok) {
      final onboarding =
          ref.read(authControllerProvider).user?.onboardingCompleted ?? false;
      context.go(onboarding ? '/app/feed' : '/onboarding');
    } else {
      final error = ref.read(authControllerProvider).error;
      _showError(error);
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
    final message = _friendly(error);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _friendly(String? error) {
    if (error == null || error.trim().isEmpty) return 'No se pudo iniciar sesión';
    if (error.contains('DioException') || error.contains('[bad response]')) {
      if (error.contains('401')) {
        return 'Credenciales incorrectas. Verifica tu correo y contraseña.';
      }
      if (error.contains('400')) {
        return 'Los datos ingresados no son válidos.';
      }
      return 'No se pudo conectar con el servidor. Intenta de nuevo.';
    }
    // Parseamos el texto del error para extraer el código de estado
    // y proporcionar un mensaje amigable.
    final match = RegExp(r'ApiException\((\d+)\)').firstMatch(error);
    if (match != null) {
      final status = int.tryParse(match.group(1) ?? '') ?? 0;
      if (status == 401) return 'Credenciales incorrectas. Inténtalo de nuevo.';
      if (status == 403) return 'No tienes permiso para acceder.';
      if (status >= 500) return 'Error del servidor. Intenta más tarde.';
    }
    // Si contiene "401" sin el formato completo, también lo tratamos como no autorizado.
    if (error.contains('401')) {
      return 'Credenciales incorrectas. Inténtalo de nuevo.';
    }
    // Extraer el mensaje después del formato ApiException(status):
    final msgMatch = RegExp(r'ApiException\(\d+\):\s*(.*)').firstMatch(error);
    if (msgMatch != null && msgMatch.group(1) != null) {
      return msgMatch.group(1)!;
    }
    return error;
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authControllerProvider).busy;
    final scheme = Theme.of(context).colorScheme;

    return SizedBox.expand(
      child: AnimatedFluidBackground(
        assetPath: 'assets/images/bg_fluid_login.webp',
        overlayDarkness: 0.32,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.primary.withValues(
                          alpha: scheme.brightness == Brightness.dark
                              ? 0.16
                              : 0.08,
                        ),
                        Colors.transparent,
                      ],
                      stops: const [0, 0.45],
                    ),
                  ),
                ),
              ),
              const Positioned.fill(
                child: IgnorePointer(child: BrandBackdrop()),
              ),
              Positioned.fill(
                child: SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: AppDimens.pagePadding,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 12),
                              // Héroe: logotipo oficial de Kyubi (90x90).
                              const Center(child: KyubiLogo(size: 90)),
                              const SizedBox(height: 6),
                              Text(
                                AppConstants.appSlogan,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                              const SizedBox(height: 24),
                              // Formulario en tarjeta para dar estructura visual.
                              Container(
                                padding: AppDimens.cardPadding,
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerLow.withValues(
                                    alpha: 0.65,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppDimens.radiusLg,
                                  ),
                                  border: Border.all(
                                    color: scheme.outlineVariant.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      'Bienvenido de nuevo',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Inicia sesión para continuar',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                    ),
                                    const SizedBox(height: 20),
                                    TextFormField(
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      autofillHints: const [
                                        AutofillHints.email,
                                      ],
                                      validator: Validators.email,
                                      decoration: _kyubiInputDecoration(
                                        labelText: 'Correo electrónico',
                                        prefixIcon: const Icon(
                                          Icons.mail_outline_rounded,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    TextFormField(
                                      controller: _passwordController,
                                      obscureText: _obscure,
                                      textInputAction: TextInputAction.done,
                                      autofillHints: const [
                                        AutofillHints.password,
                                      ],
                                      validator: (v) => (v == null || v.isEmpty)
                                          ? 'Ingresa tu contraseña'
                                          : null,
                                      onFieldSubmitted: (_) => _submit(),
                                      decoration: _kyubiInputDecoration(
                                        labelText: 'Contraseña',
                                        prefixIcon: const Icon(
                                          Icons.lock_outline_rounded,
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscure
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined,
                                          ),
                                          onPressed: () => setState(
                                            () => _obscure = !_obscure,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: () =>
                                            context.push('/forgot-password'),
                                        child: const Text(
                                          '¿Olvidaste tu contraseña?',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    AppButton(
                                      label: 'Iniciar sesión',
                                      icon: Icons.login_rounded,
                                      loading: busy,
                                      onPressed: _submit,
                                    ),
                                  ],
                                ),
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
                                onPressed: _signInWithGoogle,
                              ),
                              const SizedBox(height: 16),
                              AppButton(
                                label: 'Crear cuenta con correo',
                                icon: Icons.person_add_alt_1_rounded,
                                isOutlined: true,
                                onPressed: () => context.push('/register'),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                AppConstants.tagline,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
