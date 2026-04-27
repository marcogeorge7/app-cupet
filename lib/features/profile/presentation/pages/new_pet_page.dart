import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/models/pet.dart';
import '../bloc/pet_bloc.dart';

class NewPetPage extends StatefulWidget {
  const NewPetPage({super.key});

  @override
  State<NewPetPage> createState() => _NewPetPageState();
}

class _NewPetPageState extends State<NewPetPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _photoUrlCtrl = TextEditingController();

  PetType _type = PetType.dog;
  PetGender _gender = PetGender.female;
  DateTime? _birthdate;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _locationCtrl.dispose();
    _photoUrlCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<PetBloc>().add(PetCreated(
          type: _type,
          gender: _gender,
          name: _nameCtrl.text.trim(),
          bio: _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
          birthdate: _birthdate,
          locationName: _locationCtrl.text.trim().isEmpty
              ? null
              : _locationCtrl.text.trim(),
          primaryPhotoUrl: _photoUrlCtrl.text.trim().isEmpty
              ? null
              : _photoUrlCtrl.text.trim(),
        ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PetBloc, PetState>(
      listenWhen: (prev, next) => prev.status != next.status,
      listener: (context, state) {
        if (state.status == PetStatus.ready && context.canPop()) {
          context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('New pet profile')),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('Step 1 — tell us about your pet',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                _SegmentedTypePicker(
                  value: _type,
                  onChanged: (t) => setState(() => _type = t),
                ),
                const SizedBox(height: 12),
                _SegmentedGenderPicker(
                  value: _gender,
                  onChanged: (g) => setState(() => _gender = g),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _bioCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Bio',
                    hintText: 'Loves long walks and treats…',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _locationCtrl,
                  decoration:
                      const InputDecoration(labelText: 'City / location'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _photoUrlCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Primary photo URL'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: Color(0xFFF5EAD0)),
                  ),
                  tileColor: Colors.white,
                  title: Text(_birthdate == null
                      ? 'Birthday (optional)'
                      : '${_birthdate!.toLocal()}'.split(' ')[0]),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                      initialDate:
                          _birthdate ?? DateTime.now().subtract(const Duration(days: 365)),
                    );
                    if (picked != null) setState(() => _birthdate = picked);
                  },
                ),
                const SizedBox(height: 24),
                BlocBuilder<PetBloc, PetState>(
                  builder: (context, state) {
                    final loading = state.status == PetStatus.loading;
                    return ElevatedButton(
                      onPressed: loading ? null : _submit,
                      child: loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save pet'),
                    );
                  },
                ),
                BlocBuilder<PetBloc, PetState>(
                  builder: (context, state) {
                    if (state.errorMessage == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        state.errorMessage!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentedTypePicker extends StatelessWidget {
  const _SegmentedTypePicker({required this.value, required this.onChanged});
  final PetType value;
  final ValueChanged<PetType> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<PetType>(
      segments: const [
        ButtonSegment(value: PetType.dog, label: Text('Dog'), icon: Text('🐶')),
        ButtonSegment(value: PetType.cat, label: Text('Cat'), icon: Text('🐱')),
        ButtonSegment(value: PetType.other, label: Text('Other'), icon: Text('🦜')),
      ],
      selected: {value},
      onSelectionChanged: (set) => onChanged(set.first),
    );
  }
}

class _SegmentedGenderPicker extends StatelessWidget {
  const _SegmentedGenderPicker({required this.value, required this.onChanged});
  final PetGender value;
  final ValueChanged<PetGender> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<PetGender>(
      segments: const [
        ButtonSegment(value: PetGender.female, label: Text('Female')),
        ButtonSegment(value: PetGender.male, label: Text('Male')),
      ],
      selected: {value},
      onSelectionChanged: (set) => onChanged(set.first),
    );
  }
}
