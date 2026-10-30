import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/shimmer_loading.dart';
import '../../core/widgets/state_views.dart';
import '../../models/api_models.dart';
import '../../services/api_service.dart';
import '../../services/app_notification_service.dart';
import '../../services/notification_service.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({required this.service, super.key});

  final AppNotificationService service;

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  LearningPreferencesModel? _preferences;
  String? _error;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final preferences = await widget.service.preferences();
      if (mounted) setState(() => _preferences = preferences);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickTime({required bool risk}) async {
    final value = _preferences;
    if (value == null) return;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: risk ? value.streakRiskHour : value.reminderHour,
        minute: risk ? value.streakRiskMinute : value.reminderMinute,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _preferences = LearningPreferencesModel(
        reminderEnabled: value.reminderEnabled,
        reminderHour: risk ? value.reminderHour : picked.hour,
        reminderMinute: risk ? value.reminderMinute : picked.minute,
        streakRiskEnabled: value.streakRiskEnabled,
        streakRiskHour: risk ? picked.hour : value.streakRiskHour,
        streakRiskMinute: risk ? picked.minute : value.streakRiskMinute,
        timezone: value.timezone,
      );
    });
  }

  void _toggle({required bool risk, required bool enabled}) {
    final value = _preferences;
    if (value == null) return;
    setState(() {
      _preferences = LearningPreferencesModel(
        reminderEnabled: risk ? value.reminderEnabled : enabled,
        reminderHour: value.reminderHour,
        reminderMinute: value.reminderMinute,
        streakRiskEnabled: risk ? enabled : value.streakRiskEnabled,
        streakRiskHour: value.streakRiskHour,
        streakRiskMinute: value.streakRiskMinute,
        timezone: value.timezone,
      );
    });
  }

  Future<void> _save() async {
    final value = _preferences;
    if (value == null || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      var timezone = value.timezone;
      try {
        timezone = (await FlutterTimezone.getLocalTimezone()).identifier;
      } on Object {
        // Keep the previously validated server timezone.
      }
      final updated = await widget.service.updatePreferences(
        LearningPreferencesModel(
          reminderEnabled: value.reminderEnabled,
          reminderHour: value.reminderHour,
          reminderMinute: value.reminderMinute,
          streakRiskEnabled: value.streakRiskEnabled,
          streakRiskHour: value.streakRiskHour,
          streakRiskMinute: value.streakRiskMinute,
          timezone: timezone,
        ),
      );
      if (!mounted) return;
      await NotificationService.instance.scheduleLearningReminders(
        preferences: updated,
        dailyTitle: context.l10n.t('notifications.dailyTitle'),
        dailyBody: context.l10n.t('notifications.dailyBody'),
        riskTitle: context.l10n.t('notifications.riskTitle'),
        riskBody: context.l10n.t('notifications.riskBody'),
      );
      if (!mounted) return;
      setState(() => _preferences = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.t('notifications.saved'))),
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: _loading
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: ShimmerLoadingList(itemCount: 4),
                )
              : _error != null && _preferences == null
              ? ErrorStateView(message: _error!, onRetry: _load)
              : _content(context),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final value = _preferences!;
    final material = MaterialLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
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
                context.l10n.t('notifications.settingsTitle'),
                style: AppTextStyles.titleFor(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        GlassCard(
          child: Column(
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.t('notifications.dailyReminder')),
                subtitle: Text(context.l10n.t('notifications.dailyHelp')),
                value: value.reminderEnabled,
                onChanged: (enabled) => _toggle(risk: false, enabled: enabled),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                enabled: value.reminderEnabled,
                leading: const Icon(Icons.schedule_rounded),
                title: Text(context.l10n.t('notifications.reminderTime')),
                trailing: Text(
                  material.formatTimeOfDay(
                    TimeOfDay(
                      hour: value.reminderHour,
                      minute: value.reminderMinute,
                    ),
                  ),
                  style: AppTextStyles.sectionFor(context),
                ),
                onTap: () => _pickTime(risk: false),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: Column(
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.t('notifications.streakRisk')),
                subtitle: Text(context.l10n.t('notifications.riskHelp')),
                value: value.streakRiskEnabled,
                onChanged: (enabled) => _toggle(risk: true, enabled: enabled),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                enabled: value.streakRiskEnabled,
                leading: const Icon(Icons.local_fire_department_outlined),
                title: Text(context.l10n.t('notifications.riskTime')),
                trailing: Text(
                  material.formatTimeOfDay(
                    TimeOfDay(
                      hour: value.streakRiskHour,
                      minute: value.streakRiskMinute,
                    ),
                  ),
                  style: AppTextStyles.sectionFor(context),
                ),
                onTap: () => _pickTime(risk: true),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          ErrorStateView(message: _error!),
        ],
        const SizedBox(height: 18),
        PrimaryButton(
          label: context.l10n.t('common.save'),
          icon: Icons.notifications_active_rounded,
          loading: _saving,
          onPressed: _save,
        ),
      ],
    );
  }
}
