import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injector.dart';
import '../../../../shared/models/country.dart';
import '../../data/country_remote_data_source.dart';
import '../bloc/auth_bloc.dart';

class PhoneInputPage extends StatefulWidget {
  const PhoneInputPage({super.key});

  @override
  State<PhoneInputPage> createState() => _PhoneInputPageState();
}

class _PhoneInputPageState extends State<PhoneInputPage> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  List<Country> _countries = kFallbackCountries;
  Country _selected = kFallbackCountries.first;

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  /// Pull the country list from the backend so the offered dial codes can
  /// change server-side without an app release. Falls back silently to the
  /// built-in list (already in state) if the request fails — login must not
  /// be blocked by a config fetch.
  Future<void> _loadCountries() async {
    try {
      final result =
          await getIt<CountryRemoteDataSource>().fetchCountries();
      if (!mounted || result.countries.isEmpty) return;
      setState(() {
        _countries = result.countries;
        _selected = _countries.firstWhere(
          (c) => c.iso == result.defaultIso,
          orElse: () => _countries.first,
        );
      });
    } catch (_) {
      // Keep the fallback list already in state.
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    _focusNode.unfocus();
    if (!_formKey.currentState!.validate()) return;

    final raw = _controller.text.trim();
    final String phone;
    if (raw.contains('+')) {
      // A fully-qualified international number is authoritative — send it
      // verbatim and let the backend canonicalise it. This keeps the
      // documented test-number / store-review login (enter +201021108644)
      // working regardless of the selected country.
      phone = raw;
    } else {
      // National entry: keep digits, drop a single trunk "0" (users type
      // 010… for an Egypt number; E.164 has no trunk prefix once the
      // country code is present).
      final national =
          raw.replaceAll(RegExp(r'[^0-9]'), '').replaceFirst(RegExp(r'^0'), '');
      final dialDigits = _selected.dialCode.replaceAll(RegExp(r'[^0-9]'), '');
      // If the typed number already carries the country code (e.g. a tester
      // pasted 201021108644 without the +), don't prepend it again.
      if (national.startsWith(dialDigits) &&
          national.length - dialDigits.length >= 6) {
        phone = '+$national';
      } else {
        phone = '${_selected.dialCode}$national';
      }
    }

    context.read<AuthBloc>().add(AuthOtpRequested(phone));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Image.asset(
                            'assets/icon/icon.png',
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Image.asset(
                          'assets/images/cupet_wordmark.png',
                          width: 220,
                          fit: BoxFit.contain,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),
                  Text(
                    "Hello Hooman!",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Drop your number and let’s find your pet’s soulmate.",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 32),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CountryDropdown(
                        countries: _countries,
                        selected: _selected,
                        onChanged: (c) => setState(() => _selected = c),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _controller,
                          focusNode: _focusNode,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.done,
                          autocorrect: false,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9+\s\-()]'),
                            ),
                          ],
                          onFieldSubmitted: (_) => _submit(),
                          decoration: const InputDecoration(
                            labelText: 'Phone number',
                            hintText: '10 1234 5678',
                          ),
                          validator: (v) {
                            final digits =
                                (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                            if (digits.length < 5) {
                              return 'Please enter a valid phone number.';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  BlocBuilder<AuthBloc, AuthState>(
                    buildWhen: (prev, curr) =>
                        prev.errorMessage != curr.errorMessage,
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
                    buildWhen: (prev, curr) => prev.status != curr.status,
                    builder: (context, state) {
                      final loading = state.status == AuthStatus.sendingOtp;
                      return ElevatedButton(
                        onPressed: loading ? null : _submit,
                        child: loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Send code'),
                      );
                    },
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

class _CountryDropdown extends StatelessWidget {
  const _CountryDropdown({
    required this.countries,
    required this.selected,
    required this.onChanged,
  });

  final List<Country> countries;
  final Country selected;
  final ValueChanged<Country> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      child: DropdownButtonFormField<Country>(
        initialValue: selected,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Code'),
        // Compact display once a country is picked: flag + dial code only.
        selectedItemBuilder: (context) => [
          for (final c in countries)
            Row(
              children: [
                Text(c.flag, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Text(c.dialCode),
              ],
            ),
        ],
        items: [
          for (final c in countries)
            DropdownMenuItem<Country>(
              value: c,
              child: Text(
                '${c.flag}  ${c.name} (${c.dialCode})',
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (c) {
          if (c != null) onChanged(c);
        },
      ),
    );
  }
}
