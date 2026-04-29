class PinnedRepository {
  final String name;
  final String fullName;
  final String description;
  final int stargazerCount;
  final int forkCount;
  final String languageName;
  final String languageColor;

  const PinnedRepository({
    required this.name,
    required this.fullName,
    this.description = '',
    this.stargazerCount = 0,
    this.forkCount = 0,
    this.languageName = '',
    this.languageColor = '',
  });
}
