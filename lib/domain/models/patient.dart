/// Immutable patient summary shown in lists and detail panels.
class Patient {
  const Patient({
    required this.id,
    this.serverId,
    required this.name,
    required this.age,
    required this.gender,
    required this.status,
    required this.confidence,
    required this.lastVisit,
    required this.history,
  });

  final String id;

  /// Backend UUID. [id] remains the human-readable patient code used by the
  /// existing UI; clinical writes must use this server identifier.
  final String? serverId;
  final String name;
  final int age;
  final String gender;
  final String status;
  final int confidence;
  final String lastVisit;
  final List<String> history;

  Patient copyWith({
    String? id,
    String? serverId,
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
      serverId: serverId ?? this.serverId,
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
