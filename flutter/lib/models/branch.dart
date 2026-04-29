class Branch {
  final String name;
  final Map<String, dynamic>? commit;
  final bool protected;

  const Branch({
    required this.name,
    this.commit,
    this.protected = false,
  });

  factory Branch.fromJson(Map<String, dynamic> json) => Branch(
        name: json['name'] as String? ?? '',
        commit: json['commit'] as Map<String, dynamic>?,
        protected: json['protected'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Branch && other.name == name);

  @override
  int get hashCode => name.hashCode;
}

class Tag {
  final String name;
  final Map<String, dynamic>? commit;

  const Tag({required this.name, this.commit});

  factory Tag.fromJson(Map<String, dynamic> json) => Tag(
        name: json['name'] as String? ?? '',
        commit: json['commit'] as Map<String, dynamic>?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Tag && other.name == name);

  @override
  int get hashCode => name.hashCode;
}
