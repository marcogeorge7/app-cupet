import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _avatarCtrl;

  bool _saving = false;
  bool _deleting = false;
  String? _initialName;
  String? _initialEmail;
  String? _initialAvatar;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthBloc>().state.user;
    _initialName = user?.name ?? '';
    _initialEmail = user?.email ?? '';
    _initialAvatar = user?.avatarUrl ?? '';
    _nameCtrl = TextEditingController(text: _initialName);
    _emailCtrl = TextEditingController(text: _initialEmail);
    _avatarCtrl = TextEditingController(text: _initialAvatar);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _avatarCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final avatar = _avatarCtrl.text.trim();

    // Build a minimal patch: only send fields the user actually changed,
    // and use explicit clear flags to null out previously-set values.
    final event = AuthProfileUpdated(
      name: name != _initialName ? name : null,
      email: () {
        if (email == _initialEmail) return null;
        return email.isEmpty ? null : email;
      }(),
      clearEmail: email.isEmpty && (_initialEmail?.isNotEmpty ?? false),
      avatarUrl: () {
        if (avatar == _initialAvatar) return null;
        return avatar.isEmpty ? null : avatar;
      }(),
      clearAvatarUrl:
          avatar.isEmpty && (_initialAvatar?.isNotEmpty ?? false),
    );

    setState(() => _saving = true);
    context.read<AuthBloc>().add(event);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (prev, next) =>
          prev.user != next.user || prev.errorMessage != next.errorMessage,
      listener: (context, state) {
        if (_saving) {
          if (state.errorMessage != null) {
            setState(() => _saving = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!)),
            );
            return;
          }
          // Successful update: bloc swapped the user payload.
          setState(() => _saving = false);
          if (context.canPop()) context.pop();
          return;
        }
        if (_deleting) {
          // Failure: stay on the page and surface the error. On success the
          // bloc emits `unauthenticated` and the router redirects to /auth,
          // so there is nothing to do here.
          if (state.errorMessage != null) {
            setState(() => _deleting = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!)),
            );
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Edit profile')),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'How should other owners call you?',
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.isEmpty) return null;
                    if (value.length > 120) return 'Max 120 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Email (optional)',
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.isEmpty) return null;
                    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                        .hasMatch(value);
                    return ok ? null : 'Enter a valid email';
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _avatarCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Avatar URL (optional)',
                    hintText: 'https://…',
                  ),
                  keyboardType: TextInputType.url,
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.isEmpty) return null;
                    final uri = Uri.tryParse(value);
                    final ok = uri != null &&
                        uri.hasAbsolutePath &&
                        (uri.scheme == 'http' || uri.scheme == 'https');
                    return ok ? null : 'Enter a valid http(s) URL';
                  },
                ),
                const SizedBox(height: 12),
                _ReadOnlyField(
                  label: 'Phone',
                  value: context
                      .select<AuthBloc, String>((b) => b.state.user?.phone ?? '—'),
                  helper: 'Phone numbers can\u2019t be changed from the app.',
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save changes'),
                ),
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.delete_forever_outlined,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    'Delete account',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  subtitle: const Text(
                    'Permanently removes your profile, pets, matches and chats.',
                  ),
                  onTap: (_saving || _deleting) ? null : _confirmAndDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Account deletion (App Store Guideline 5.1.1(v)). Requires an explicit
  /// confirmation before anything is sent to the server. On success the bloc
  /// reaches the unauthenticated state and the router sends the user to /auth.
  Future<void> _confirmAndDelete() async {
    final authBloc = context.read<AuthBloc>();
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This permanently deletes your account, including your pets, '
          'matches and chats. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _deleting = true);
      authBloc.add(const AuthAccountDeleted());
    }
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({
    required this.label,
    required this.value,
    this.helper,
  });

  final String label;
  final String value;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        suffixIcon: const Icon(Icons.lock_outline, size: 18),
      ),
      child: Text(value),
    );
  }
}
