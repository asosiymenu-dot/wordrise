import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/api_models.dart';
import 'lesson_list_screen.dart' show LessonInput;

Future<LessonInput?> showCreateLessonSheet(
  BuildContext context, {
  LessonModel? initial,
}) {
  return showModalBottomSheet<LessonInput>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return CreateLessonSheet(initial: initial);
    },
  );
}

class CreateLessonSheet extends StatefulWidget {
  const CreateLessonSheet({super.key, this.initial});
  final LessonModel? initial;

  @override
  State<CreateLessonSheet> createState() => _CreateLessonSheetState();
}

class _CreateLessonSheetState extends State<CreateLessonSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _category;
  late final TextEditingController _description;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initial?.title ?? '');
    _category = TextEditingController(text: widget.initial?.category ?? 'General');
    _description = TextEditingController(text: widget.initial?.description ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _category.dispose();
    _description.dispose();
    super.dispose();
  }

  String? _required(BuildContext context, String? value) {
    if (value == null || value.trim().isEmpty) {
      return context.l10n.t('common.required');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final editing = widget.initial != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.isDark(context) ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                editing ? l10n.t('lessons.edit') : l10n.t('lessons.new'),
                style: AppTextStyles.titleFor(context),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _title,
                label: l10n.t('lessons.titleField'),
                icon: Icons.menu_book_outlined,
                validator: (value) => _required(context, value),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _category,
                label: l10n.t('lessons.category'),
                icon: Icons.category_outlined,
                validator: (value) => _required(context, value),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _description,
                label: l10n.t('lessons.description'),
                icon: Icons.notes_rounded,
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: editing ? l10n.t('lessons.update') : l10n.t('lessons.create'),
                icon: editing ? Icons.check_rounded : Icons.add_rounded,
                onPressed: () {
                  if (!_formKey.currentState!.validate()) return;
                  Navigator.pop(
                    context,
                    LessonInput(
                      title: _title.text.trim(),
                      description: _description.text.trim(),
                      category: _category.text.trim(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
