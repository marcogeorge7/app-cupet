import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../shared/models/pet.dart';
import '../bloc/pet_bloc.dart';

class NewPetPage extends StatefulWidget {
  const NewPetPage({
    super.key,
    this.initialPet,
    this.embedded = false,
    this.onSaved,
  });

  /// When non-null the page renders as an "Edit pet profile" form pre-filled
  /// with the given pet. When null it acts as the original create flow.
  final Pet? initialPet;

  /// When true the page is hosted inside the onboarding flow: instead of
  /// popping on a successful save it invokes [onSaved] so the caller can
  /// advance the registration cycle.
  final bool embedded;

  /// Called after a successful save when [embedded] is true.
  final VoidCallback? onSaved;

  @override
  State<NewPetPage> createState() => _NewPetPageState();
}

class _NewPetPageState extends State<NewPetPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _bioCtrl;
  late final TextEditingController _locationCtrl;

  late PetType _type;
  late PetGender _gender;
  DateTime? _birthdate;
  XFile? _pickedPhoto;

  bool get _isEdit => widget.initialPet != null;

  @override
  void initState() {
    super.initState();
    final pet = widget.initialPet;
    _nameCtrl = TextEditingController(text: pet?.name ?? '');
    _bioCtrl = TextEditingController(text: pet?.bio ?? '');
    _locationCtrl = TextEditingController(text: pet?.locationName ?? '');
    _type = pet?.type ?? PetType.dog;
    _gender = pet?.gender ?? PetGender.female;
    _birthdate = pet?.birthdate;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() => _pickedPhoto = picked);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final bio = _bioCtrl.text.trim();
    final location = _locationCtrl.text.trim();
    final pet = widget.initialPet;

    if (pet == null) {
      context.read<PetBloc>().add(PetCreated(
            type: _type,
            gender: _gender,
            name: _nameCtrl.text.trim(),
            bio: bio.isEmpty ? null : bio,
            birthdate: _birthdate,
            locationName: location.isEmpty ? null : location,
            primaryPhotoUrl: null,
            photoFilePath: _pickedPhoto?.path,
          ));
    } else {
      context.read<PetBloc>().add(PetUpdated(
            id: pet.id,
            type: _type,
            gender: _gender,
            name: _nameCtrl.text.trim(),
            bio: bio.isEmpty ? null : bio,
            clearBio: bio.isEmpty && (pet.bio?.isNotEmpty ?? false),
            birthdate: _birthdate,
            clearBirthdate: _birthdate == null && pet.birthdate != null,
            locationName: location.isEmpty ? null : location,
            clearLocationName:
                location.isEmpty && (pet.locationName?.isNotEmpty ?? false),
            photoFilePath: _pickedPhoto?.path,
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PetBloc, PetState>(
      listenWhen: (prev, next) => prev.status != next.status,
      listener: (context, state) {
        if (state.status != PetStatus.ready) return;
        if (widget.embedded) {
          widget.onSaved?.call();
        } else if (context.canPop()) {
          context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEdit ? 'Edit pet profile' : 'New pet profile'),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  _isEdit
                      ? 'Update ${widget.initialPet!.name}\u2019s profile'
                      : 'Step 1 — tell us about your pet',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
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
                _PhotoPickerTile(
                  picked: _pickedPhoto,
                  existingPhotoUrl: widget.initialPet?.primaryPhotoUrl,
                  onPick: _pickPhoto,
                  onClear: () => setState(() => _pickedPhoto = null),
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
                          : Text(_isEdit ? 'Save changes' : 'Save pet'),
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

class _PhotoPickerTile extends StatelessWidget {
  const _PhotoPickerTile({
    required this.picked,
    required this.onPick,
    required this.onClear,
    this.existingPhotoUrl,
  });

  final XFile? picked;
  final String? existingPhotoUrl;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: Color(0xFFF5EAD0)),
    );
    if (picked == null) {
      if (existingPhotoUrl != null) {
        return Material(
          shape: shape,
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    existingPhotoUrl!,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox(
                      width: 64,
                      height: 64,
                      child: Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Current primary photo',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: onPick,
                  child: const Text('Replace'),
                ),
              ],
            ),
          ),
        );
      }
      return ListTile(
        shape: shape,
        tileColor: Colors.white,
        leading: const Icon(Icons.image_outlined),
        title: const Text('Add a primary photo'),
        subtitle: const Text('Tap to pick from gallery'),
        onTap: onPick,
      );
    }
    return Material(
      shape: shape,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(picked!.path),
                width: 64,
                height: 64,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Photo ready — uploads after the pet is saved.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: onClear,
            ),
          ],
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
