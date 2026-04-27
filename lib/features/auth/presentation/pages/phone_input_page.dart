import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/widgets/cupet_logo.dart';
import '../bloc/auth_bloc.dart';

class PhoneInputPage extends StatefulWidget {
  const PhoneInputPage({super.key});

  @override
  State<PhoneInputPage> createState() => _PhoneInputPageState();
}

class _PhoneInputPageState extends State<PhoneInputPage> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context
        .read<AuthBloc>()
        .add(AuthOtpRequested(_controller.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            final loading = state.status == AuthStatus.sendingOtp;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    const Center(child: CupetLogo()),
                    const SizedBox(height: 48),
                    Text(
                      "Hey there!",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Enter your phone number to find a mate for your fluffball.",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _controller,
                      keyboardType: TextInputType.phone,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Phone number',
                        hintText: '+1 555 123 4567',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().length < 6) {
                          return 'Please enter a valid phone number.';
                        }
                        if (!v.trim().startsWith('+')) {
                          return 'Include country code, e.g. +1...';
                        }
                        return null;
                      },
                    ),
                    if (state.errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        state.errorMessage!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: loading ? null : _submit,
                      child: loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Send code'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
