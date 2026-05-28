import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../profile/presentation/pages/new_pet_page.dart';
import '../bloc/auth_bloc.dart';

/// Mandatory onboarding shown after a successful OTP verify until the user
/// has both a name and at least one pet. The router gate
/// (`_needsOnboarding` in router.dart) keeps the user here until done, so
/// this page only drives which step to show — it never decides when the
/// user is "done" (that's the server-derived gate).
class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  // 0 = profile (name/email), 1 = first pet.
  late int _step;

  @override
  void initState() {
    super.initState();
    // Resume from server state: if the name is already set (user quit after
    // step 0) jump straight to the pet step. The gate guarantees petsCount
    // is still 0 here, otherwise we wouldn't be on this page at all.
    final user = context.read<AuthBloc>().state.user;
    final hasName = (user?.name ?? '').trim().isNotEmpty;
    _step = hasName ? 1 : 0;
  }

  @override
  Widget build(BuildContext context) {
    if (_step == 0) {
      return _ProfileStep(onSaved: () => setState(() => _step = 1));
    }
    return NewPetPage(
      embedded: true,
      onSaved: () =>
          context.read<AuthBloc>().add(const AuthCheckRequested()),
    );
  }
}

class _ProfileStep extends StatefulWidget {
  const _ProfileStep({required this.onSaved});

  final VoidCallback onSaved;

  @override
  State<_ProfileStep> createState() => _ProfileStepState();
}

class _ProfileStepState extends State<_ProfileStep> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthBloc>().state.user;
    _nameCtrl = TextEditingController(text: user?.name ?? '');
    _emailCtrl = TextEditingController(text: user?.email ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailCtrl.text.trim();
    setState(() => _saving = true);
    context.read<AuthBloc>().add(AuthProfileUpdated(
          name: _nameCtrl.text.trim(),
          email: email.isEmpty ? null : email,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (prev, next) =>
          prev.user != next.user || prev.errorMessage != next.errorMessage,
      listener: (context, state) {
        if (!_saving) return;
        if (state.errorMessage != null) {
          setState(() => _saving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
          return;
        }
        // Name persisted — advance to the pet step. The router keeps us on
        // /register because petsCount is still 0.
        setState(() => _saving = false);
        widget.onSaved();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Welcome — your profile'),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Step 1 of 2',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Tell us who you are so other pet owners know who they’re talking to.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'How should other owners call you?',
                  ),
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.isEmpty) return 'Please enter your name';
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
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
