enum PetShape { small, medium, large }

extension PetShapeX on PetShape {
  String get value => name.toUpperCase();
  static PetShape fromValue(String? v) {
    switch (v) {
      case 'SMALL':
        return PetShape.small;
      case 'LARGE':
        return PetShape.large;
      default:
        return PetShape.medium;
    }
  }
}

class Pet {
  final String id;
  final String userId;
  final String petName;
  final int level;
  final int experiencePoints;
  final PetShape shape;
  final DateTime? updatedAt;

  Pet({
    required this.id,
    required this.userId,
    this.petName = 'Mam Nho',
    this.level = 1,
    this.experiencePoints = 0,
    this.shape = PetShape.medium,
    this.updatedAt,
  });

  /// XP needed to reach the next level (simple linear curve).
  int get xpForNextLevel => level * 100;
  double get levelProgress =>
      (experiencePoints % xpForNextLevel) / xpForNextLevel;

  factory Pet.fromMap(Map<String, dynamic> map) => Pet(
        id: map['id'],
        userId: map['user_id'],
        petName: map['pet_name'] ?? 'Mam Nho',
        level: map['level'] ?? 1,
        experiencePoints: map['experience_points'] ?? 0,
        shape: PetShapeX.fromValue(map['shape']),
        updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'pet_name': petName,
        'level': level,
        'experience_points': experiencePoints,
        'shape': shape.value,
        'updated_at': updatedAt?.toIso8601String(),
      };

  factory Pet.fromJson(Map<String, dynamic> json) => Pet(
        id: json['id'],
        userId: json['userId'],
        petName: json['petName'] ?? 'Mam Nho',
        level: json['level'] ?? 1,
        experiencePoints: json['experiencePoints'] ?? 0,
        shape: PetShapeX.fromValue(json['shape']),
        updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'petName': petName,
        'level': level,
        'experiencePoints': experiencePoints,
        'shape': shape.value,
        'updatedAt': updatedAt?.toIso8601String(),
      };

  Pet copyWith({String? petName, int? level, int? experiencePoints, PetShape? shape}) => Pet(
        id: id,
        userId: userId,
        petName: petName ?? this.petName,
        level: level ?? this.level,
        experiencePoints: experiencePoints ?? this.experiencePoints,
        shape: shape ?? this.shape,
        updatedAt: DateTime.now(),
      );
}
