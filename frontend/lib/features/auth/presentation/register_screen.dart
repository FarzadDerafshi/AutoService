import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/locale/locale_provider.dart';
import '../../../core/widgets/tone_toggle.dart';
import '../../../generated/app_localizations.dart';
import '../application/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shopNameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _shopNameController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _errorMessage = null);

    await ref.read(authControllerProvider.notifier).register(
          shopName: _shopNameController.text.trim(),
          fullName: _fullNameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

    final state = ref.read(authControllerProvider);
    if (state.hasError && mounted) {
      setState(() => _errorMessage = toApiException(state.error!).message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;
    final currentLocale = ref.watch(localeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.createYourShop),
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
                onSelectionChanged: (s) =>
                    ref.read(localeProvider.notifier).setLocale(Locale(s.first)),
              ),
            ),
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: ToneToggle(),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.createShopDescription, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _shopNameController,
                    decoration: InputDecoration(labelText: l.shopName),
                    validator: (v) => (v == null || v.trim().isEmpty) ? l.shopNameRequired : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _fullNameController,
                    decoration: InputDecoration(labelText: l.yourFullName),
                    validator: (v) => (v == null || v.trim().isEmpty) ? l.yourNameRequired : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(labelText: l.email),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => (v == null || v.trim().isEmpty) ? l.emailRequired : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(labelText: l.password, helperText: l.atLeast8Characters),
                    obscureText: true,
                    validator: (v) => (v == null || v.length < 8) ? l.passwordMinLength : null,
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: isLoading ? null : _submit,
                    child: isLoading
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(l.createShopAndAccount),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: isLoading ? null : () => context.pop(),
                    child: Text(l.backToLogin),
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
