import 'package:flutter/material.dart';

/// What the user submitted.
///
/// Named `FeedbackSubmission` rather than `Feedback` because
/// `package:flutter/material.dart` already exports a `Feedback` class.
class FeedbackSubmission {
  /// Creates a submission.
  const FeedbackSubmission({
    required this.name,
    required this.email,
    required this.category,
    required this.message,
    required this.includeDiagnostics,
  });

  /// Who is reporting.
  final String name;

  /// How to reach them.
  final String email;

  /// What kind of feedback this is.
  final FeedbackCategory category;

  /// The body of the report.
  final String message;

  /// Whether to attach diagnostic information.
  final bool includeDiagnostics;
}

/// The kinds of feedback the form accepts.
enum FeedbackCategory {
  /// Something is broken.
  bug('Bug report', Icons.bug_report_outlined),

  /// Something is missing.
  feature('Feature request', Icons.lightbulb_outline),

  /// Something is unclear.
  question('Question', Icons.help_outline);

  const FeedbackCategory(this.label, this.icon);

  /// Human-readable name.
  final String label;

  /// Leading icon in the dropdown.
  final IconData icon;
}

/// Shows the feedback form and resolves with the submission, or null if the
/// user cancelled.
Future<FeedbackSubmission?> showFeedbackDialog(BuildContext context) {
  return showDialog<FeedbackSubmission>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) => const FeedbackDialog(),
  );
}

/// A form dialog, opened from the command palette.
class FeedbackDialog extends StatefulWidget {
  /// Creates the dialog.
  const FeedbackDialog({super.key});

  @override
  State<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _message = TextEditingController();

  FeedbackCategory _category = FeedbackCategory.bug;
  bool _includeDiagnostics = true;
  bool _submitting = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    // Stand in for a real network call.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    Navigator.of(context).pop(
      FeedbackSubmission(
        name: _name.text.trim(),
        email: _email.text.trim(),
        category: _category,
        message: _message.text.trim(),
        includeDiagnostics: _includeDiagnostics,
      ),
    );
  }

  String? _required(String? value, String field) =>
      (value == null || value.trim().isEmpty) ? '$field is required' : null;

  String? _validateEmail(String? value) {
    final String? missing = _required(value, 'Email');
    if (missing != null) return missing;
    // Deliberately permissive: enough to catch typos, not to police addresses.
    final bool looksValid = RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(value!.trim());
    return looksValid ? null : 'That does not look like an email address';
  }

  String? _validateMessage(String? value) {
    final String? missing = _required(value, 'Message');
    if (missing != null) return missing;
    return value!.trim().length < 10
        ? 'Please add a little more detail (at least 10 characters)'
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AlertDialog(
      icon: const Icon(Icons.forum_outlined),
      title: const Text('Send feedback'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextFormField(
                  controller: _name,
                  // First field takes focus as the dialog opens.
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (String? value) => _required(value, 'Name'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.alternate_email),
                  ),
                  validator: _validateEmail,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<FeedbackCategory>(
                  initialValue: _category,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                  items: <DropdownMenuItem<FeedbackCategory>>[
                    for (final FeedbackCategory category
                        in FeedbackCategory.values)
                      DropdownMenuItem<FeedbackCategory>(
                        value: category,
                        child: Row(
                          children: <Widget>[
                            Icon(category.icon, size: 18),
                            const SizedBox(width: 10),
                            Text(category.label),
                          ],
                        ),
                      ),
                  ],
                  onChanged: (FeedbackCategory? value) =>
                      setState(() => _category = value ?? _category),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _message,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    alignLabelWithHint: true,
                  ),
                  validator: _validateMessage,
                ),
                const SizedBox(height: 4),
                CheckboxListTile(
                  value: _includeDiagnostics,
                  onChanged: (bool? value) =>
                      setState(() => _includeDiagnostics = value ?? false),
                  title: const Text('Include diagnostics'),
                  subtitle: Text(
                    'Attaches the app version and platform.',
                    style: theme.textTheme.bodySmall,
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send'),
        ),
      ],
    );
  }
}
