/// Representation of an anatomical muscle group in the Gym Module.
class Muscle {
  final String id;
  final String name;
  final String anatomyRegion;
  final String muscleGroup;

  const Muscle({
    required this.id,
    required this.name,
    required this.anatomyRegion,
    required this.muscleGroup,
  });

  factory Muscle.fromMap(Map<String, dynamic> map) {
    return Muscle(
      id: map['id'] as String,
      name: map['name'] as String,
      anatomyRegion: map['anatomy_region'] as String,
      muscleGroup: map['muscle_group'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'anatomy_region': anatomyRegion,
      'muscle_group': muscleGroup,
    };
  }
}

/// Binding between a muscle structure and a 3D GLB mesh node.
class MuscleMeshBinding {
  final String id;
  final String muscleId;
  final String meshId;
  final String side; // 'left', 'right', 'both'

  const MuscleMeshBinding({
    required this.id,
    required this.muscleId,
    required this.meshId,
    required this.side,
  });

  factory MuscleMeshBinding.fromMap(Map<String, dynamic> map) {
    return MuscleMeshBinding(
      id: map['id'] as String,
      muscleId: map['muscle_id'] as String,
      meshId: map['mesh_id'] as String,
      side: map['side'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'muscle_id': muscleId,
      'mesh_id': meshId,
      'side': side,
    };
  }
}
