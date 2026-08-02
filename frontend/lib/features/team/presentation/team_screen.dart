import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api/api_client.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../../shop/application/shop_provider.dart';
import '../application/team_provider.dart';
import '../data/invite_model.dart';
import '../data/team_member_model.dart';

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class TeamScreen extends ConsumerWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final canManage = ref.watch(currentUserProvider)?.canManage ?? false;
    final membersAsync = ref.watch(teamMembersProvider);
    final invitesAsync = ref.watch(teamInvitesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.team)),
      floatingActionButton: canManage
          ? FloatingActionButton(
              onPressed: () => showDialog(context: context, builder: (_) => const _InviteDialog()),
              child: const Icon(Icons.person_add),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.members, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Card(
            child: AsyncValueWidget<List<TeamMember>>(
              value: membersAsync,
              onRetry: () => ref.invalidate(teamMembersProvider),
              data: (members) => Column(
                children: [
                  for (final member in members)
                    _MemberTile(member: member, canManage: canManage),
                ],
              ),
            ),
          ),
          if (canManage) ...[
            const SizedBox(height: 24),
            Text(l.pendingInvites, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Card(
              child: AsyncValueWidget<List<Invite>>(
                value: invitesAsync,
                onRetry: () => ref.invalidate(teamInvitesProvider),
                data: (invites) => Column(
                  children: [
                    for (final invite in invites) _InviteTile(invite: invite),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile({required this.member, required this.canManage});
  final TeamMember member;
  final bool canManage;

  String _roleLabel(AppLocalizations l, String role) => switch (role) {
        'owner' => l.owner,
        'manager' => l.manager,
        'technician' => l.technician,
        _ => role,
      };

  Future<void> _setActive(BuildContext context, WidgetRef ref, bool isActive) async {
    try {
      await ref.read(teamRepositoryProvider).setMemberActive(member.id, isActive);
      ref.invalidate(teamMembersProvider);
    } catch (e) {
      if (context.mounted) _showSnack(context, toApiException(e).message);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.confirmDeleteMemberTitle),
        content: Text(l.confirmDeleteMemberBody(member.fullName)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l.deleteMember)),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(teamRepositoryProvider).deleteMember(member.id);
      ref.invalidate(teamMembersProvider);
    } catch (e) {
      if (context.mounted) _showSnack(context, toApiException(e).message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final currentUserId = ref.watch(currentUserProvider)?.id;
    final manageable = canManage && member.role != 'owner' && member.id != currentUserId;

    return ListTile(
      title: Text(member.fullName),
      subtitle: Text('${member.email}  •  ${_roleLabel(l, member.role)}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Chip(
            label: Text(member.isActive ? l.active : l.inactive),
            visualDensity: VisualDensity.compact,
          ),
          if (manageable)
            PopupMenuButton<String>(
              onSelected: (action) {
                if (action == 'toggle') {
                  _setActive(context, ref, !member.isActive);
                } else if (action == 'delete') {
                  _delete(context, ref);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 'toggle', child: Text(member.isActive ? l.deactivate : l.reactivate)),
                PopupMenuItem(value: 'delete', child: Text(l.deleteMember)),
              ],
            ),
        ],
      ),
    );
  }
}

class _InviteTile extends ConsumerWidget {
  const _InviteTile({required this.invite});
  final Invite invite;

  String _statusLabel(AppLocalizations l) {
    if (invite.isRevoked) return l.inviteStatusRevoked;
    if (invite.isUsed) return l.inviteStatusUsed;
    if (invite.isExpired) return l.inviteStatusExpired;
    return l.inviteStatusPending;
  }

  String _roleLabel(AppLocalizations l) => switch (invite.role) {
        'manager' => l.manager,
        'technician' => l.technician,
        _ => invite.role,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    return ListTile(
      title: Text(_roleLabel(l)),
      subtitle: Text(_statusLabel(l)),
      trailing: invite.isPending
          ? TextButton(
              onPressed: () async {
                try {
                  await ref.read(teamRepositoryProvider).revokeInvite(invite.id);
                  ref.invalidate(teamInvitesProvider);
                } catch (e) {
                  if (context.mounted) _showSnack(context, toApiException(e).message);
                }
              },
              child: Text(l.revokeInviteAction),
            )
          : null,
    );
  }
}

class _InviteDialog extends ConsumerStatefulWidget {
  const _InviteDialog();

  @override
  ConsumerState<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends ConsumerState<_InviteDialog> {
  String _role = 'technician';
  int _expiresInHours = 72;
  bool _generating = false;
  Invite? _invite;

  Future<void> _generate() async {
    setState(() => _generating = true);
    try {
      final invite = await ref
          .read(teamRepositoryProvider)
          .createInvite(role: _role, expiresInHours: _expiresInHours);
      setState(() => _invite = invite);
      ref.invalidate(teamInvitesProvider);
    } catch (e) {
      if (mounted) _showSnack(context, toApiException(e).message);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  String _link() => '$appOrigin/#/join/${_invite!.id}';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final shopName = ref.watch(shopProfileProvider).valueOrNull?.name ?? '';

    return AlertDialog(
      title: Text(l.inviteTeamMember),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _invite == null
              ? [
                  Text(l.role, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(value: 'technician', label: Text(l.technician)),
                      ButtonSegment(value: 'manager', label: Text(l.manager)),
                    ],
                    selected: {_role},
                    onSelectionChanged: (s) => setState(() => _role = s.first),
                  ),
                  const SizedBox(height: 16),
                  Text(l.expiresIn, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  SegmentedButton<int>(
                    segments: [
                      ButtonSegment(value: 24, label: Text(l.hours24)),
                      ButtonSegment(value: 72, label: Text(l.days3)),
                      ButtonSegment(value: 168, label: Text(l.days7)),
                    ],
                    selected: {_expiresInHours},
                    onSelectionChanged: (s) => setState(() => _expiresInHours = s.first),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _generating ? null : _generate,
                    child: Text(l.generateInviteLink),
                  ),
                ]
              : [
                  Text(l.inviteLinkLabel, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  TextField(
                    readOnly: true,
                    controller: TextEditingController(text: _link()),
                    decoration: const InputDecoration(isDense: true),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _link()));
                          _showSnack(context, l.linkCopied);
                        },
                        icon: const Icon(Icons.copy, size: 16),
                        label: Text(l.copyLink),
                      ),
                      FilledButton.icon(
                        onPressed: () async {
                          final message = l.whatsAppInviteMessage(shopName, _link());
                          final url = 'https://wa.me/?text=${Uri.encodeComponent(message)}';
                          await launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');
                        },
                        icon: const Icon(Icons.share, size: 16),
                        label: Text(l.shareViaWhatsApp),
                      ),
                    ],
                  ),
                ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.cancel)),
      ],
    );
  }
}
