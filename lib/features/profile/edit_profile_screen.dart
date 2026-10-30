import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/user_avatar.dart';
import '../../models/api_models.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    required this.user,
    required this.authService,
    super.key,
  });

  final UserModel user;
  final AuthService authService;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _username;
  late final TextEditingController _email;
  final _password = TextEditingController();
  final _picker = ImagePicker();
  Uint8List? _avatarBytes;
  String _avatarMime = 'image/jpeg';
  bool _avatarRemoved = false;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.user.name);
    _username = TextEditingController(text: widget.user.username);
    _email = TextEditingController(text: widget.user.email);
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 900,
        maxHeight: 900,
        imageQuality: 82,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _avatarBytes = bytes;
        _avatarMime = picked.mimeType ?? _mimeFromPath(picked.path);
        _avatarRemoved = false;
      });
    } on Object catch (_) {
      if (!mounted) return;
      setState(() => _error = context.l10n.t('profile.avatarPickError'));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      var user = await widget.authService.updateProfile(
        name: _name.text.trim(),
        username: _username.text.trim(),
        email: _email.text.trim(),
        avatar: widget.user.avatar ?? '',
        password: _password.text,
      );
      final bytes = _avatarBytes;
      if (bytes != null) {
        user = await widget.authService.uploadAvatar(
          bytes: bytes,
          mimeType: _avatarMime,
        );
      } else if (_avatarRemoved) {
        user = await widget.authService.deleteAvatar();
      }
      if (!mounted) return;
      Navigator.of(context).pop(user);
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: GradientBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.t('profile.edit'),
                    style: AppTextStyles.titleFor(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GlassCard(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _AvatarPicker(
                      name: _name.text,
                      avatarUrl: _avatarRemoved ? null : widget.user.avatar,
                      avatarBytes: _avatarBytes,
                      onGallery: () => _pickAvatar(ImageSource.gallery),
                      onCamera: kIsWeb
                          ? null
                          : () => _pickAvatar(ImageSource.camera),
                      onRemove: () => setState(() {
                        _avatarBytes = null;
                        _avatarRemoved = true;
                      }),
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _name,
                      label: l10n.t('auth.name'),
                      icon: Icons.person_outline_rounded,
                      validator: (value) => _required(context, value),
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _username,
                      label: l10n.t('auth.username'),
                      icon: Icons.alternate_email_rounded,
                      validator: (value) => _usernameValidator(context, value),
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _email,
                      label: l10n.t('auth.email'),
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) => _required(context, value),
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _password,
                      label: l10n.t('profile.newPassword'),
                      icon: Icons.lock_outline_rounded,
                      obscureText: true,
                    ),
                  ],
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              ErrorStateView(message: _error!),
            ],
            const SizedBox(height: 16),
            PrimaryButton(
              label: l10n.t('profile.save'),
              icon: Icons.check_rounded,
              loading: _loading,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({
    required this.name,
    required this.avatarUrl,
    required this.avatarBytes,
    required this.onGallery,
    this.onCamera,
    required this.onRemove,
  });

  final String name;
  final String? avatarUrl;
  final Uint8List? avatarBytes;
  final VoidCallback onGallery;
  final VoidCallback? onCamera;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        ClipOval(
          child: avatarBytes != null
              ? Image.memory(
                  avatarBytes!,
                  width: 92,
                  height: 92,
                  fit: BoxFit.cover,
                )
              : UserAvatar(
                  name: name,
                  avatarUrl: avatarUrl,
                  size: 92,
                  backgroundColor: AppColors.blue.withValues(alpha: .86),
                ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: onGallery,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(l10n.t('profile.gallery')),
              ),
            ),
            if (onCamera != null) ...[
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: onCamera,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(l10n.t('profile.camera')),
                ),
              ),
            ],
          ],
        ),
        if ((avatarUrl ?? '').isNotEmpty || avatarBytes != null) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline_rounded),
            label: Text(l10n.t('profile.removePhoto')),
          ),
        ],
      ],
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
  if (!RegExp(r'^[a-zA-Z0-9_.]{3,30}$').hasMatch(value!.trim())) {
    return context.l10n.t('auth.usernameHint');
  }
  return null;
}

String _mimeFromPath(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}
