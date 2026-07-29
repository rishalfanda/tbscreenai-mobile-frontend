/// Immutable patient summary shown in lists and detail panels.
class Patient {
  const Patient({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
    required this.status,
    required this.confidence,
    required this.lastVisit,
    required this.history,
  });

  final String id;
  final String name;
  final int age;
  final String gender;
  final String status;
  final int confidence;
  final String lastVisit;
  final List<String> history;

  Patient copyWith({
    String? id,
    String? name,
    int? age,
    String? gender,
    String? status,
    int? confidence,
    String? lastVisit,
    List<String>? history,
  }) {
    return Patient(
      id: id ?? this.id,
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      status: status ?? this.status,
      confidence: confidence ?? this.confidence,
      lastVisit: lastVisit ?? this.lastVisit,
      history: history ?? this.history,
    );
  }
}
