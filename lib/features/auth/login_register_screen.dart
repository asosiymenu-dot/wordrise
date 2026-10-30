import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/google_web_sign_in_button.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/state_views.dart';
import '../../models/api_models.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

class LoginRegisterScreen extends StatefulWidget {
  const LoginRegisterScreen({
    required this.authService,
    required this.onAuthenticated,
    super.key,
  });

  final AuthService authService;
  final ValueChanged<UserModel> onAuthenticated;

  @override
  State<LoginRegisterScreen> createState() => _LoginRegisterScreenState();
}

class _LoginRegisterScreenState extends State<LoginRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _register = false;
  bool _loading = false;
  bool _googleLoading = false;
  String? _error;
  StreamSubscription<AuthResponse>? _googleAuthSubscription;

  bool get _busy => _loading || _googleLoading;

  @override
  void initState() {
    super.initState();
    _listenForGoogleWebAuth();
  }

  @override
  void dispose() {
    unawaited(_googleAuthSubscription?.cancel());
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _busy) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = _register
          ? await widget.authService.register(
              name: _nameController.text.trim(),
              username: _usernameController.text.trim(),
              email: _emailController.text.trim(),
              password: _passwordController.text,
            )
          : await widget.authService.login(
              identifier: _emailController.text.trim(),
              password: _passwordController.text,
            );
      if (!mounted) return;
      widget.onAuthenticated(response.user);
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _googleLoading = true;
      _error = null;
    });
    try {
      final response = await widget.authService.loginWithGoogle();
      if (!mounted || response == null) return;
      widget.onAuthenticated(response.user);
    } on GoogleAuthException catch (error) {
      if (!mounted) return;
      final key = switch (error.failure) {
        GoogleAuthFailure.configuration => 'auth.googleConfigError',
        GoogleAuthFailure.unavailable => 'auth.googleUnavailable',
        GoogleAuthFailure.missingIdToken => 'auth.googleTokenMissing',
      };
      setState(() => _error = context.l10n.t(key));
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(
        () => _error = error.statusCode == 409
            ? context.l10n.t('auth.googleAccountConflict')
            : error.message,
      );
    } on Object {
      if (mounted) {
        setState(() => _error = context.l10n.t('auth.googleUnavailable'));
      }
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  void _listenForGoogleWebAuth() {
    if (!kIsWeb || !widget.authService.googleSignInConfigured) return;
    _googleAuthSubscription = widget.authService.googleAuthenticationResponses
        .listen(
          (response) {
            if (!mounted) return;
            setState(() => _googleLoading = false);
            widget.onAuthenticated(response.user);
          },
          onError: (Object error) {
            if (!mounted) return;
            setState(() {
              _googleLoading = false;
              _error = _messageForGoogleError(context, error);
            });
          },
        );
  }

  String _messageForGoogleError(BuildContext context, Object error) {
    if (error is GoogleAuthException) {
      final key = switch (error.failure) {
        GoogleAuthFailure.configuration => 'auth.googleConfigError',
        GoogleAuthFailure.unavailable => 'auth.googleUnavailable',
        GoogleAuthFailure.missingIdToken => 'auth.googleTokenMissing',
      };
      return context.l10n.t(key);
    }
    if (error is ApiException) {
      return error.statusCode == 409
          ? context.l10n.t('auth.googleAccountConflict')
          : error.message;
    }
    return context.l10n.t('auth.googleUnavailable');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = AppColors.isDark(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBgStart : const Color(0xFFF0F4F8), // Soft gamified background
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.blue,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.blue.withValues(alpha: 0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.rocket_launch_rounded,
                          color: Colors.white,
                          size: 64,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _register
                          ? l10n.t('auth.createAccount')
                          : l10n.t('auth.welcome'),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.displayFor(context).copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppColors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.t('auth.subtitle'),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.captionFor(context).copyWith(
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (_register) ...[
                      AppTextField(
                        controller: _nameController,
                        label: l10n.t('auth.name'),
                        icon: Icons.person_outline_rounded,
                        validator: (value) => _required(context, value),
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        controller: _usernameController,
                        label: l10n.t('auth.username'),
                        icon: Icons.alternate_email_rounded,
                        validator: (value) =>
                            _usernameValidator(context, value),
                      ),
                      const SizedBox(height: 12),
                    ],
                    AppTextField(
                      controller: _emailController,
                      label: _register
                          ? l10n.t('auth.email')
                          : l10n.t('auth.identifier'),
                      icon: _register
                          ? Icons.email_outlined
                          : Icons.alternate_email_rounded,
                      keyboardType: _register
                          ? TextInputType.emailAddress
                          : TextInputType.text,
                      validator: (value) => _required(context, value),
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _passwordController,
                      label: l10n.t('auth.password'),
                      icon: Icons.lock_outline_rounded,
                      obscureText: true,
                      validator: (value) => _required(context, value),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      ErrorStateView(message: _error!),
                    ],
                    const SizedBox(height: 18),
                    PrimaryButton(
                      label: _register
                          ? l10n.t('auth.register')
                          : l10n.t('auth.login'),
                      icon: _register
                          ? Icons.person_add_alt_rounded
                          : Icons.login_rounded,
                      loading: _loading,
                      onPressed: _busy ? null : _submit,
                    ),
                    const SizedBox(height: 16),
                    _AuthDivider(label: l10n.t('auth.or')),
                    const SizedBox(height: 16),
                    if (kIsWeb)
                      buildGoogleWebSignInButton(
                        locale: l10n.locale.languageCode,
                      )
                    else
                      _GoogleSignInButton(
                        label: l10n.t('auth.continueWithGoogle'),
                        loading: _googleLoading,
                        onPressed: _busy ? null : _signInWithGoogle,
                      ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _register = !_register),
                      child: Text(
                        _register
                            ? l10n.t('auth.haveAccount')
                            : l10n.t('auth.createNew'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    );
  }
}

class _AuthDivider extends StatelessWidget {
  const _AuthDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final border = Theme.of(context).dividerColor.withValues(alpha: 0.6);
    return Row(
      children: [
        Expanded(child: Divider(color: border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label, style: AppTextStyles.captionFor(context)),
        ),
        Expanded(child: Divider(color: border)),
      ],
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Material(
        color: const Color(0xFFFFFFFF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF747775)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: loading ? null : onPressed,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 12,
                child: loading
                    ? const SizedBox.shrink()
                    : const _GoogleBrandMark(),
              ),
              if (loading)
                const SizedBox.square(
                  dimension: 21,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Color(0xFF1F1F1F),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 46),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF1F1F1F),
                      fontSize: 14,
                      height: 20 / 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
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

class _GoogleBrandMark extends StatelessWidget {
  const _GoogleBrandMark();

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 20,
      child: ClipRect(
        child: OverflowBox(
          minWidth: 44,
          maxWidth: 44,
          minHeight: 44,
          maxHeight: 44,
          child: Image.asset(
            'assets/branding/google_sign_in_source.png',
            width: 44,
            height: 44,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}

String? _required(BuildContext context, String? value) {
  if (value == null || value.trim().isEmpty) {
    return context.l10n.t('common.required');
  }
  return null;
}

String? _usernameValidator(BuildContext context, String? value) {
  final required = _required(context, value);
  if (required != null) return required;
  final username = value!.trim();
  if (!RegExp(r'^[a-zA-Z0-9_.]{3,30}$').hasMatch(username)) {
    return context.l10n.t('auth.usernameHint');
  }
  return null;
}
