import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/profile_controller.dart';
import '../models/profile_model.dart';
import '../theme/spark_colors.dart';
import '../widgets/spark_snackbar.dart';
import '../widgets/spark_text_field.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  late final ProfileController _controller;
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _aboutController = TextEditingController();
  final _nameFocus = FocusNode();
  final _ageFocus = FocusNode();
  final _aboutFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = ProfileController()..addListener(_onUpdate);
    _controller.load().then((_) {
      if (!mounted) return;
      if (_controller.needsReauthentication) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      }
    });
  }

  void _onUpdate() {
    if (!mounted) return;
    if (!_controller.isLoading) {
      final model = _controller.model;
      // Keep text fields in sync after load/save without fighting user typing
      // while a request is in flight.
      if (_nameController.text != model.name && !_nameFocus.hasFocus) {
        _nameController.text = model.name;
      }
      if (_ageController.text != model.age && !_ageFocus.hasFocus) {
        _ageController.text = model.age;
      }
      if (_aboutController.text != model.about && !_aboutFocus.hasFocus) {
        _aboutController.text = model.about;
      }
    }
    setState(() {});
  }

  void _syncFieldsFromModel() {
    final model = _controller.model;
    _nameController.text = model.name;
    _ageController.text = model.age;
    _aboutController.text = model.about;
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onUpdate)
      ..dispose();
    _nameController.dispose();
    _ageController.dispose();
    _aboutController.dispose();
    _nameFocus.dispose();
    _ageFocus.dispose();
    _aboutFocus.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    FocusScope.of(context).unfocus();
    final ok = await _controller.save();
    if (!mounted) return;
    final message = ok
        ? (_controller.saveMessage ?? 'Profile saved')
        : (_controller.saveMessage ?? 'Please fix the highlighted fields');
    final needsLogin = !ok && _controller.needsReauthentication;
    showSparkSnackBar(context, message);
    if (ok) {
      _syncFieldsFromModel();
    } else if (needsLogin) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final model = _controller.model;
    final errors = _controller.errors;

    return ColoredBox(
      color: SparkColors.background,
      child: SafeArea(
        child: Column(
          children: [
            if (_controller.isLoading)
              const LinearProgressIndicator(
                color: SparkColors.accent,
                backgroundColor: SparkColors.surface,
                minHeight: 2,
              ),
            if (_controller.loadError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: SparkColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _controller.loadError!,
                          style: textTheme.bodyLarge?.copyWith(fontSize: 13),
                        ),
                      ),
                      TextButton(
                        onPressed: _controller.load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profile',
                      style: textTheme.headlineLarge?.copyWith(fontSize: 28),
                    ),
                    const SizedBox(height: 28),
                    const _SectionLabel(label: 'About me'),
                    const SizedBox(height: 14),
                    SparkTextField(
                      hint: 'Name',
                      controller: _nameController,
                      focusNode: _nameFocus,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      errorText: errors['name'],
                      onChanged: _controller.setName,
                      onSubmitted: (_) => _ageFocus.requestFocus(),
                    ),
                    const SizedBox(height: 12),
                    SparkTextField(
                      hint: 'Age',
                      controller: _ageController,
                      focusNode: _ageFocus,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      errorText: errors['age'],
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      onChanged: _controller.setAge,
                      onSubmitted: (_) => _aboutFocus.requestFocus(),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Gender',
                      style: textTheme.titleMedium?.copyWith(
                        color: SparkColors.placeholder,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _ChoiceRow<ProfileGender>(
                      values: ProfileGender.values,
                      selected: model.gender,
                      labelOf: (g) => g.label,
                      onSelected: _controller.setGender,
                    ),
                    if (errors['gender'] != null) ...[
                      const SizedBox(height: 8),
                      _FieldError(text: errors['gender']!),
                    ],
                    const SizedBox(height: 12),
                    SparkTextField(
                      hint: 'Say some things about yourself',
                      controller: _aboutController,
                      focusNode: _aboutFocus,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.newline,
                      keyboardType: TextInputType.multiline,
                      minLines: 4,
                      maxLines: 6,
                      maxLength: 500,
                      errorText: errors['about'],
                      onChanged: _controller.setAbout,
                    ),
                    const SizedBox(height: 32),
                    const _SectionLabel(label: 'What are you looking for?'),
                    const SizedBox(height: 14),
                    ...LookingForIntent.values.map((intent) {
                      final selected = model.intents.contains(intent);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _IntentCard(
                          intent: intent,
                          selected: selected,
                          onTap: () => _controller.toggleIntent(intent),
                          genderChild: _genderPickerFor(intent, selected),
                        ),
                      );
                    }),
                    if (errors['intents'] != null) ...[
                      _FieldError(text: errors['intents']!),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _controller.isSaving ? null : _onSave,
                  child: Text(
                    _controller.isSaving ? 'Saving...' : 'Save profile',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _genderPickerFor(LookingForIntent intent, bool selected) {
    if (!selected) return null;
    final model = _controller.model;

    if (intent == LookingForIntent.date) {
      return _GenderPreferenceBlock(
        title: 'Choose gender you are looking for',
        selected: model.dateLookingFor,
        onSelected: _controller.setDateLookingFor,
      );
    }
    if (intent == LookingForIntent.makeFriends) {
      return _GenderPreferenceBlock(
        title: 'Specific gender?',
        selected: model.friendsLookingFor,
        onSelected: _controller.setFriendsLookingFor,
      );
    }
    return null;
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: SparkColors.title,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
    );
  }
}

class _FieldError extends StatelessWidget {
  const _FieldError({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: const Color(0xFFFF6B6B),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
    );
  }
}

class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  final List<T> values;
  final T? selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < values.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: _ChoiceChip(
              label: labelOf(values[i]),
              selected: selected == values[i],
              onTap: () => onSelected(values[i]),
            ),
          ),
        ],
      ],
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? SparkColors.accent : SparkColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: selected ? SparkColors.onAccent : SparkColors.fieldText,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
          ),
        ),
      ),
    );
  }
}

class _IntentCard extends StatelessWidget {
  const _IntentCard({
    required this.intent,
    required this.selected,
    required this.onTap,
    this.genderChild,
  });

  final LookingForIntent intent;
  final bool selected;
  final VoidCallback onTap;
  final Widget? genderChild;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: SparkColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? SparkColors.accent : Colors.transparent,
          width: 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      intent.label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: SparkColors.title,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    color: selected
                        ? SparkColors.accent
                        : SparkColors.placeholder,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
          if (genderChild != null) ...[
            const Divider(height: 1, color: SparkColors.surfaceElevated),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: genderChild,
            ),
          ],
        ],
      ),
    );
  }
}

class _GenderPreferenceBlock extends StatelessWidget {
  const _GenderPreferenceBlock({
    required this.title,
    required this.selected,
    required this.onSelected,
  });

  final String title;
  final LookingForGender selected;
  final ValueChanged<LookingForGender> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: SparkColors.placeholder,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 10),
        _ChoiceRow<LookingForGender>(
          values: LookingForGender.values,
          selected: selected,
          labelOf: (g) => g.label,
          onSelected: onSelected,
        ),
      ],
    );
  }
}
