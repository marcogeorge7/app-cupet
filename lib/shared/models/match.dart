import 'package:equatable/equatable.dart';

import 'pet.dart';

class PetMatch extends Equatable {
  const PetMatch({
    required this.id,
    required this.petA,
    required this.petB,
    required this.conversationId,
    required this.createdAt,
  });

  final int id;
  final Pet petA;
  final Pet petB;
  final int? conversationId;
  final DateTime createdAt;

  factory PetMatch.fromJson(Map<String, dynamic> json) => PetMatch(
        id: json['id'] as int,
        petA: Pet.fromJson(json['pet_a'] as Map<String, dynamic>),
        petB: Pet.fromJson(json['pet_b'] as Map<String, dynamic>),
        conversationId: json['conversation_id'] as int?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Pet otherPetFor(int userId) =>
      petA.userId == userId ? petB : petA;

  @override
  List<Object?> get props => [id, petA, petB, conversationId, createdAt];
}
