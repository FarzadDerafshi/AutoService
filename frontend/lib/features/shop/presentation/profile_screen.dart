import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../application/shop_provider.dart';
import '../data/shop_profile_model.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final user = ref.watch(currentUserProvider);
    final canManage = user?.canManage ?? false;
    final shopAsync = ref.watch(shopProfileProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.profile)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Keyed on the user id so the form's controllers (populated once in
          // initState) get re-initialized once auth data actually resolves,
          // instead of staying blank forever if this screen is reached (e.g.
          // via a direct URL) before authControllerProvider finishes loading.
          _MyAccountCard(key: ValueKey(user?.id)),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: AsyncValueWidget<ShopProfile>(
                value: shopAsync,
                onRetry: () => ref.invalidate(shopProfileProvider),
                data: (profile) => _ShopDetailsForm(profile: profile, canManage: canManage),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class _MyAccountCard extends ConsumerStatefulWidget {
  const _MyAccountCard({super.key});

  @override
  ConsumerState<_MyAccountCard> createState() => _MyAccountCardState();
}

class _MyAccountCardState extends ConsumerState<_MyAccountCard> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullName;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _fullName = TextEditingController(text: ref.read(currentUserProvider)?.fullName ?? '');
  }

  @override
  void dispose() {
    _fullName.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(authControllerProvider.notifier).updateProfile(fullName: _fullName.text.trim());
      if (mounted) _showSnack(context, l.profileUpdated);
    } catch (e) {
      if (mounted) _showSnack(context, toApiException(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final user = ref.watch(currentUserProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.myAccount, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _fullName,
                decoration: InputDecoration(labelText: l.fullNameLabel),
                validator: (v) => (v == null || v.trim().isEmpty) ? l.required : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: user?.email ?? '',
                enabled: false,
                decoration: InputDecoration(labelText: l.email),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  FilledButton(onPressed: _saving ? null : _save, child: Text(l.save)),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () => showDialog(context: context, builder: (_) => const _ChangePasswordDialog()),
                    child: Text(l.changePassword),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();

  @override
  ConsumerState<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await ref.read(authControllerProvider.notifier).changePassword(
            currentPassword: _current.text,
            newPassword: _next.text,
          );
      if (mounted) {
        Navigator.of(context).pop();
        _showSnack(context, l.passwordChanged);
      }
    } catch (e) {
      if (mounted) _showSnack(context, toApiException(e).message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l.changePassword),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _current,
              obscureText: true,
              decoration: InputDecoration(labelText: l.currentPassword),
              validator: (v) => (v == null || v.isEmpty) ? l.required : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _next,
              obscureText: true,
              decoration: InputDecoration(labelText: l.newPassword),
              validator: (v) => (v == null || v.length < 8) ? l.passwordMinLength : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirm,
              obscureText: true,
              decoration: InputDecoration(labelText: l.confirmPassword),
              validator: (v) => (v != _next.text) ? l.passwordsDoNotMatch : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.cancel)),
        FilledButton(onPressed: _submitting ? null : _submit, child: Text(l.save)),
      ],
    );
  }
}

class _ShopDetailsForm extends ConsumerStatefulWidget {
  const _ShopDetailsForm({required this.profile, required this.canManage});
  final ShopProfile profile;
  final bool canManage;

  @override
  ConsumerState<_ShopDetailsForm> createState() => _ShopDetailsFormState();
}

class _ShopDetailsFormState extends ConsumerState<_ShopDetailsForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _taxId;
  late final TextEditingController _taxOffice;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  bool _saving = false;
  bool _uploadingLogo = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _name = TextEditingController(text: p.name);
    _taxId = TextEditingController(text: p.taxId ?? '');
    _taxOffice = TextEditingController(text: p.taxOffice ?? '');
    _phone = TextEditingController(text: p.phone ?? '');
    _email = TextEditingController(text: p.email ?? '');
    _address = TextEditingController(text: p.address ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _taxId.dispose();
    _taxOffice.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(shopProfileProvider.notifier).updateProfile({
        'name': _name.text.trim(),
        'taxId': _taxId.text.trim(),
        'taxOffice': _taxOffice.text.trim(),
        'phone': _phone.text.trim(),
        'email': _email.text.trim(),
        'address': _address.text.trim(),
      });
      if (mounted) _showSnack(context, l.shopUpdated);
    } catch (e) {
      if (mounted) _showSnack(context, toApiException(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickLogo() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    } catch (e) {
      if (mounted) _showSnack(context, toApiException(e).message);
      return;
    }
    final file = result?.files.single;
    if (file?.bytes == null) return;
    setState(() => _uploadingLogo = true);
    try {
      await ref.read(shopProfileProvider.notifier).uploadLogo(file!.bytes!, file.name);
    } catch (e) {
      if (mounted) _showSnack(context, toApiException(e).message);
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  Future<void> _removeLogo() async {
    setState(() => _uploadingLogo = true);
    try {
      await ref.read(shopProfileProvider.notifier).deleteLogo();
    } catch (e) {
      if (mounted) _showSnack(context, toApiException(e).message);
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final logoUrl = widget.profile.logoUrl;
    final canManage = widget.canManage;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.shopDetails, style: Theme.of(context).textTheme.titleLarge),
            if (!canManage) ...[
              const SizedBox(height: 4),
              Text(l.viewOnlyShopDetails, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: logoUrl != null
                      ? Image.network('$apiOrigin$logoUrl', fit: BoxFit.cover)
                      : Icon(Icons.storefront, color: Theme.of(context).disabledColor),
                ),
                const SizedBox(width: 16),
                if (canManage)
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: _uploadingLogo ? null : _pickLogo,
                          child: Text(l.uploadLogo),
                        ),
                        if (logoUrl != null)
                          OutlinedButton(
                            onPressed: _uploadingLogo ? null : _removeLogo,
                            child: Text(l.removeLogo),
                          ),
                      ],
                    ),
                  )
                else if (logoUrl == null)
                  Expanded(child: Text(l.noLogoUploaded)),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              enabled: canManage,
              decoration: InputDecoration(labelText: l.shopName),
              validator: (v) => (v == null || v.trim().isEmpty) ? l.required : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _taxId,
                    enabled: canManage,
                    decoration: InputDecoration(labelText: l.taxId),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _taxOffice,
                    enabled: canManage,
                    decoration: InputDecoration(labelText: l.taxOffice),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _phone,
                    enabled: canManage,
                    decoration: InputDecoration(labelText: l.phoneLabel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _email,
                    enabled: canManage,
                    decoration: InputDecoration(labelText: l.email),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _address,
              enabled: canManage,
              maxLines: 2,
              decoration: InputDecoration(labelText: l.addressLabel),
            ),
            if (canManage) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(onPressed: _saving ? null : _save, child: Text(l.save)),
              ),
            ],
        ],
      ),
    );
  }
}
