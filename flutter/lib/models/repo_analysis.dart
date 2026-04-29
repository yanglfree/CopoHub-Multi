/// Mirrors HarmonyOS RepoAnalysis.ets
class RepoAnalysis {
  final int id;
  final int repoId;
  final String owner;
  final String name;

  // AI analysis content
  final String analysisTitle;
  final String analysisContentZh;
  final String analysisContentEn;
  final String analysisSummary;
  final Map<String, dynamic> keyFeatures;
  final Map<String, dynamic> techStack;
  final Map<String, dynamic> useCases;

  // AI metadata
  final String aiProvider;
  final String aiModel;
  final int tokensUsed;
  final int generationTimeMs;

  // Status: draft | published | archived | failed
  final String status;

  final String createdAt;
  final String updatedAt;

  // Nested repo info
  final RepoAnalysisRepository? repository;

  const RepoAnalysis({
    required this.id,
    required this.repoId,
    required this.owner,
    required this.name,
    this.analysisTitle = '',
    this.analysisContentZh = '',
    this.analysisContentEn = '',
    this.analysisSummary = '',
    this.keyFeatures = const {},
    this.techStack = const {},
    this.useCases = const {},
    this.aiProvider = '',
    this.aiModel = '',
    this.tokensUsed = 0,
    this.generationTimeMs = 0,
    this.status = 'draft',
    this.createdAt = '',
    this.updatedAt = '',
    this.repository,
  });

  factory RepoAnalysis.fromJson(Map<String, dynamic> json) {
    final repo = json['repository'] as Map<String, dynamic>?;
    return RepoAnalysis(
      id: json['id'] as int? ?? 0,
      repoId: json['repo_id'] as int? ?? 0,
      owner: json['owner'] as String? ?? '',
      name: json['name'] as String? ?? '',
      analysisTitle: json['analysis_title'] as String? ?? '',
      analysisContentZh: json['analysis_content_zh'] as String? ?? '',
      analysisContentEn: json['analysis_content_en'] as String? ?? '',
      analysisSummary: json['analysis_summary'] as String? ?? '',
      keyFeatures:
          (json['key_features'] as Map<String, dynamic>?) ?? const {},
      techStack: (json['tech_stack'] as Map<String, dynamic>?) ?? const {},
      useCases: (json['use_cases'] as Map<String, dynamic>?) ?? const {},
      aiProvider: json['ai_provider'] as String? ?? '',
      aiModel: json['ai_model'] as String? ?? '',
      tokensUsed: json['tokens_used'] as int? ?? 0,
      generationTimeMs: json['generation_time_ms'] as int? ?? 0,
      status: json['status'] as String? ?? 'draft',
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
      repository: repo != null ? RepoAnalysisRepository.fromJson(repo) : null,
    );
  }

  /// Returns Chinese content if available, falls back to English.
  String get analysisContent =>
      analysisContentZh.isNotEmpty ? analysisContentZh : analysisContentEn;

  bool get isPublished => status == 'published';
  bool get isGenerating => status == 'draft';
  bool get isFailed => status == 'failed';

  int get stars => repository?.stars ?? 0;
  String get language => repository?.language ?? '';
  String get description => repository?.description ?? '';
  String get githubUrl =>
      repository?.url.isNotEmpty == true
          ? repository!.url
          : 'https://github.com/$owner/$name';
}

class RepoAnalysisRepository {
  final String owner;
  final String name;
  final String description;
  final String language;
  final int stars;
  final int forks;
  final String url;

  const RepoAnalysisRepository({
    this.owner = '',
    this.name = '',
    this.description = '',
    this.language = '',
    this.stars = 0,
    this.forks = 0,
    this.url = '',
  });

  factory RepoAnalysisRepository.fromJson(Map<String, dynamic> json) =>
      RepoAnalysisRepository(
        owner: json['owner'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        language: json['language'] as String? ?? '',
        stars: json['stars'] as int? ?? 0,
        forks: json['forks'] as int? ?? 0,
        url: json['url'] as String? ?? '',
      );
}
