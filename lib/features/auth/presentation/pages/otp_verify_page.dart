import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth_bloc.dart';

class OtpVerifyPage extends StatefulWidget {
  const OtpVerifyPage({super.key});

  @override
  State<OtpVerifyPage> createState() => _OtpVerifyPageState();
}

class _OtpVerifyPageState extends State<OtpVerifyPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _controller.text.trim();
    if (code.length != 6) return;
    _focusNode.unfocus();
    context.read<AuthBloc>().add(AuthOtpSubmitted(code));
  }

  String _channelHint(String? channel) {
    switch (channel) {
      case 'whatsapp':
        return 'Sent via WhatsApp';
      case 'sms':
        return 'Sent via SMS';
      case 'test':
        return 'Test mode — use the configured code';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify code')),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'We sent a code to',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                BlocBuilder<AuthBloc, AuthState>(
                  buildWhen: (a, b) =>
                      a.phoneNumber != b.phoneNumber ||
                      a.pending?.channel != b.pending?.channel,
                  builder: (context, state) {
                    final hint = _channelHint(state.pending?.channel);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          state.phoneNumber ?? '',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (hint.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            hint,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  maxLength: 6,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  onChanged: (v) {
                    if (v.length == 6) _submit();
                  },
                  decoration: const InputDecoration(
                    labelText: 'SMS code',
                    counterText: '',
                  ),
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                BlocBuilder<AuthBloc, AuthState>(
                  buildWhen: (a, b) => a.errorMessage != b.errorMessage,
                  builder: (context, state) {
                    if (state.errorMessage == null) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        state.errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),
                BlocBuilder<AuthBloc, AuthState>(
                  buildWhen: (a, b) => a.status != b.status,
                  builder: (context, state) {
                    final verifying =
                        state.status == AuthStatus.verifying;
                    return ElevatedButton(
                      onPressed: verifying ? null : _submit,
                      child: verifying
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            )
                          : const Text('Verify'),
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () =>
                      context.read<AuthBloc>().add(const AuthOtpCancelled()),
                  child: const Text('Use a different number'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
