import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/di/injector.dart';
import '../../../../shared/models/pet.dart';
import '../../data/breed_remote_data_source.dart';
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
  final List<XFile> _pickedPhotos = [];

  static const _maxPhotos = 6;

  // Breed: a creatable dropdown sourced from the backend catalogue for the
  // selected species, with an "add new" escape hatch for breeds not listed.
  late final TextEditingController _newBreedCtrl;
  String? _breed;
  List<String> _breeds = const [];
  bool _loadingBreeds = false;
  bool _addingNewBreed = false;

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
    _breed = pet?.breed;
    _newBreedCtrl = TextEditingController();
    _loadBreeds();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _locationCtrl.dispose();
    _newBreedCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final existing = widget.initialPet?.photos.length ?? 0;
    final remaining = _maxPhotos - existing - _pickedPhotos.length;
    if (remaining <= 0) return;
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(maxWidth: 1600, imageQuality: 85);
    if (picked.isEmpty) return;
    setState(() => _pickedPhotos.addAll(picked.take(remaining)));
  }

  Future<void> _loadBreeds() async {
    setState(() => _loadingBreeds = true);
    try {
      final breeds =
          await getIt<BreedRemoteDataSource>().fetchBreeds(_type.name);
      if (!mounted) return;
      setState(() => _breeds = breeds);
    } catch (_) {
      // Best-effort: the field still works as free text via "add new".
      if (!mounted) return;
      setState(() => _breeds = const []);
    } finally {
      if (mounted) setState(() => _loadingBreeds = false);
    }
  }

  void _onTypeChanged(PetType t) {
    setState(() {
      _type = t;
      // Different species → different breed list; reset the dropdown choice
      // (a typed custom breed is kept).
      if (!_addingNewBreed) _breed = null;
    });
    _loadBreeds();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final bio = _bioCtrl.text.trim();
    final location = _locationCtrl.text.trim();
    final pet = widget.initialPet;

    final breedRaw =
        _addingNewBreed ? _newBreedCtrl.text.trim() : (_breed ?? '');
    final breed = breedRaw.isEmpty ? null : breedRaw;
    final photoPaths = _pickedPhotos.map((x) => x.path).toList();

    if (pet == null) {
      context.read<PetBloc>().add(PetCreated(
            type: _type,
            gender: _gender,
            name: _nameCtrl.text.trim(),
            breed: breed,
            bio: bio.isEmpty ? null : bio,
            birthdate: _birthdate,
            locationName: location.isEmpty ? null : location,
            primaryPhotoUrl: null,
            photoFilePaths: photoPaths,
          ));
    } else {
      context.read<PetBloc>().add(PetUpdated(
            id: pet.id,
            type: _type,
            gender: _gender,
            name: _nameCtrl.text.trim(),
            breed: breed,
            clearBreed: breed == null && (pet.breed?.isNotEmpty ?? false),
            bio: bio.isEmpty ? null : bio,
            clearBio: bio.isEmpty && (pet.bio?.isNotEmpty ?? false),
            birthdate: _birthdate,
            clearBirthdate: _birthdate == null && pet.birthdate != null,
            locationName: location.isEmpty ? null : location,
            clearLocationName:
                location.isEmpty && (pet.locationName?.isNotEmpty ?? false),
            photoFilePaths: photoPaths,
          ));
    }
  }

  Widget _buildBreedField(BuildContext context) {
    if (_addingNewBreed) {
      return Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _newBreedCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Breed',
                hintText: 'Type your pet’s breed',
              ),
            ),
          ),
          IconButton(
            tooltip: 'Pick from the list instead',
            icon: const Icon(Icons.close),
            onPressed: () => setState(() {
              _addingNewBreed = false;
              _newBreedCtrl.clear();
            }),
          ),
        ],
      );
    }

    const addNewValue = '__add_new__';
    // Keep a typed custom breed selectable even if it isn't in the catalogue.
    final items = <String>{
      ..._breeds,
      if (_breed != null && _breed!.isNotEmpty) _breed!,
    }.toList();

    return DropdownButtonFormField<String>(
      initialValue: _breed,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Breed (optional)',
        suffixIcon: _loadingBreeds
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : null,
      ),
      items: [
        for (final b in items) DropdownMenuItem(value: b, child: Text(b)),
        const DropdownMenuItem(
          value: addNewValue,
          child: Text('➕ Add a new breed'),
        ),
      ],
      onChanged: (value) {
        if (value == addNewValue) {
          setState(() {
            _addingNewBreed = true;
            _newBreedCtrl.text = '';
          });
        } else {
          setState(() => _breed = value);
        }
      },
    );
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
                  onChanged: _onTypeChanged,
                ),
                const SizedBox(height: 12),
                _SegmentedGenderPicker(
                  value: _gender,
                  onChanged: (g) => setState(() => _gender = g),
                ),
                const SizedBox(height: 16),
                _buildBreedField(context),
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
                _PhotosField(
                  existing: widget.initialPet?.photos ?? const [],
                  picked: _pickedPhotos,
                  max: _maxPhotos,
                  onAdd: _pickPhotos,
                  onRemoveAt: (i) => setState(() => _pickedPhotos.removeAt(i)),
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

class _PhotosField extends StatelessWidget {
  const _PhotosField({
    required this.existing,
    required this.picked,
    required this.max,
    required this.onAdd,
    required this.onRemoveAt,
  });

  /// Photos already saved on the pet (edit mode) — shown read-only.
  final List<PetPhoto> existing;

  /// Newly picked photos, not yet uploaded.
  final List<XFile> picked;
  final int max;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemoveAt;

  @override
  Widget build(BuildContext context) {
    final total = existing.length + picked.length;
    final canAdd = total < max;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Photos ($total/$max)',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: existing.length + picked.length + (canAdd ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              if (i < existing.length) {
                return _Thumb(image: NetworkImage(existing[i].url));
              }
              final pickedIndex = i - existing.length;
              if (pickedIndex < picked.length) {
                return _Thumb(
                  image: FileImage(File(picked[pickedIndex].path)),
                  onRemove: () => onRemoveAt(pickedIndex),
                );
              }
              return _AddPhotoTile(onTap: onAdd);
            },
          ),
        ),
        if (picked.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 6),
            child: Text(
              'New photos upload after the pet is saved.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.image, this.onRemove});

  final ImageProvider image;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image(
            image: image,
            width: 96,
            height: 96,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: 96,
              height: 96,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.broken_image_outlined),
            ),
          ),
        ),
        if (onRemove != null)
          Positioned(
            top: 2,
            right: 2,
            child: InkResponse(
              onTap: onRemove,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(2),
                child: const Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: const Border.fromBorderSide(
            BorderSide(color: Color(0xFFF5EAD0)),
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined),
            SizedBox(height: 4),
            Text('Add', style: TextStyle(fontSize: 12)),
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
