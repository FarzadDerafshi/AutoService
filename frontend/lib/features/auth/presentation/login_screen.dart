import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/locale/locale_provider.dart';
import '../../../generated/app_localizations.dart';
import '../application/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _errorMessage = null);

    await ref.read(authControllerProvider.notifier).login(
          _emailController.text.trim(),
          _passwordController.text,
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
      body: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Image.asset('assets/branding/logo.png', height: 96),
                      const SizedBox(height: 8),
                      Text(l.appTitle, style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(labelText: l.email),
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        validator: (v) => (v == null || v.trim().isEmpty) ? l.emailRequired : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(labelText: l.password),
                        obscureText: true,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _submit(),
                        validator: (v) => (v == null || v.isEmpty) ? l.passwordRequired : null,
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
                            : Text(l.logIn),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: isLoading ? null : () => context.push('/register'),
                        child: Text(l.newShopCreateAccount),
                      ),
                      const SizedBox(height: 16),
                      // Language selector
                      Center(
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
                    ],
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
