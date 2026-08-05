import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/locale/locale_provider.dart';
import '../../../core/widgets/tone_toggle.dart';
import '../../../generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../application/team_provider.dart';
import '../data/invite_model.dart';

class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({required this.inviteId, super.key});
  final String inviteId;

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  late Future<InvitePublicInfo> _infoFuture;

  @override
  void initState() {
    super.initState();
    _infoFuture = ref.read(teamRepositoryProvider).getInvitePublicInfo(widget.inviteId);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final currentLocale = ref.watch(localeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.inviteTeamMember),
        actions: [
          if (kLanguageToggleVisible)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'en', label: Text('EN')),
                  ButtonSegment(value: 'tr', label: Text('TR')),
                ],
                selected: {currentLocale.languageCode},
                onSelectionChanged: (s) => ref.read(localeProvider.notifier).setLocale(Locale(s.first)),
              ),
            ),
          const Padding(padding: EdgeInsets.only(right: 12), child: ToneToggle()),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: FutureBuilder<InvitePublicInfo>(
              future: _infoFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 32),
                      const SizedBox(height: 12),
                      Text(toApiException(snapshot.error!).message, textAlign: TextAlign.center),
                    ],
                  );
                }
                return _JoinForm(inviteId: widget.inviteId, info: snapshot.data!);
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _JoinForm extends ConsumerStatefulWidget {
  const _JoinForm({required this.inviteId, required this.info});
  final String inviteId;
  final InvitePublicInfo info;

  @override
  ConsumerState<_JoinForm> createState() => _JoinFormState();
}

class _JoinFormState extends ConsumerState<_JoinForm> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  String? _errorMessage;
  bool _submitting = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  String _roleLabel(AppLocalizations l, String role) => switch (role) {
        'manager' => l.manager,
        'technician' => l.technician,
        _ => role,
      };

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      final result = await ref.read(teamRepositoryProvider).joinViaInvite(
            widget.inviteId,
            fullName: '${_firstName.text.trim()} ${_lastName.text.trim()}'.trim(),
            email: _email.text.trim(),
            password: _password.text,
          );
      await ref.read(authControllerProvider.notifier).setSession(result);
      if (mounted) context.go('/work-orders');
    } catch (e) {
      if (mounted) setState(() => _errorMessage = toApiException(e).message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.youAreJoining(widget.info.shopName, _roleLabel(l, widget.info.role)),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _firstName,
            decoration: InputDecoration(labelText: l.firstName),
            validator: (v) => (v == null || v.trim().isEmpty) ? l.required : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _lastName,
            decoration: InputDecoration(labelText: l.lastName),
            validator: (v) => (v == null || v.trim().isEmpty) ? l.required : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _email,
            decoration: InputDecoration(labelText: l.email),
            keyboardType: TextInputType.emailAddress,
            validator: (v) => (v == null || v.trim().isEmpty) ? l.emailRequired : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _password,
            decoration: InputDecoration(labelText: l.password, helperText: l.atLeast8Characters),
            obscureText: true,
            validator: (v) => (v == null || v.length < 8) ? l.passwordMinLength : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirmPassword,
            decoration: InputDecoration(labelText: l.confirmPassword),
            obscureText: true,
            validator: (v) => (v != _password.text) ? l.passwordsDoNotMatch : null,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l.joinAndCreateAccount),
          ),
        ],
      ),
    );
  }
}
