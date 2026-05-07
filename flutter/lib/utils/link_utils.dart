import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../router/app_router.dart';

// ---------------------------------------------------------------------------
// Link action types
// ---------------------------------------------------------------------------

sealed class LinkAction {}

class OpenExternal extends LinkAction {
  OpenExternal(this.uri);
  final Uri uri;
}

class PushRepository extends LinkAction {
  PushRepository({required this.owner, required this.repo});
  final String owner;
  final String repo;
}

class PushFileViewer extends LinkAction {
  PushFileViewer({
    required this.owner,
    required this.repo,
    required this.path,
    required this.branch,
    this.fileName,
  });
  final String owner;
  final String repo;
  final String path;
  final String branch;
  final String? fileName;
}

class PushIssue extends LinkAction {
  PushIssue({required this.owner, required this.repo, required this.number});
  final String owner;
  final String repo;
  final int number;
}

class PushUserProfile extends LinkAction {
  PushUserProfile({required this.username});
  final String username;
}

// ---------------------------------------------------------------------------
// Resolution logic
// ---------------------------------------------------------------------------

/// Given an already-resolved absolute URL string (from `_resolveReadmeUrl`),
/// returns the appropriate [LinkAction], or `null` if the link should be
/// silently ignored (e.g. empty / unparseable).
///
/// Rules:
/// - mailto:           → mail app (OpenExternal)
/// - github.com /owner/repo                             → PushRepository
/// - github.com /owner/repo/blob/<branch>/<path...>     → PushFileViewer
/// - github.com /owner/repo/issues/<number>             → PushIssue
/// - github.com other paths                             → OpenExternal (browser)
/// - Any other http/https                               → OpenExternal (browser)
LinkAction? resolveLinkAction(String resolvedHref) {
  if (resolvedHref.isEmpty) return null;
  final uri = Uri.tryParse(resolvedHref);
  if (uri == null) return null;

  final scheme = uri.scheme.toLowerCase();

  // mailto → external mail app
  if (scheme == 'mailto') return OpenExternal(uri);

  if (scheme != 'http' && scheme != 'https') return null;

  final host = uri.host.toLowerCase();
  final isGitHub = host == 'github.com' || host == 'www.github.com';

  if (!isGitHub) return OpenExternal(uri);

  // GitHub URL — examine path segments (filter empty strings from leading /)
  final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();

  if (segs.isEmpty) return OpenExternal(uri);

  // /username — single segment that is not a reserved GitHub path
  if (segs.length == 1) {
    const reservedPaths = {
      'login', 'logout', 'signup', 'join', 'explore', 'marketplace',
      'features', 'pricing', 'about', 'topics', 'collections', 'events',
      'sponsors', 'orgs', 'settings', 'notifications', 'search',
      'new', 'import', 'organizations', 'contact', 'security',
    };
    final segment = segs[0].toLowerCase();
    if (reservedPaths.contains(segment)) return OpenExternal(uri);
    return PushUserProfile(username: segs[0]);
  }

  final owner = segs[0];
  final repo = segs[1];

  // /owner/repo — exact repo root
  if (segs.length == 2) {
    return PushRepository(owner: owner, repo: repo);
  }

  final thirdSeg = segs[2];

  // /owner/repo/blob/<branch>/path... → file viewer
  if (thirdSeg == 'blob' && segs.length >= 5) {
    final branch = segs[3];
    final filePath = segs.sublist(4).join('/');
    final fileName = filePath.contains('/')
        ? filePath.substring(filePath.lastIndexOf('/') + 1)
        : filePath;
    return PushFileViewer(
      owner: owner,
      repo: repo,
      path: filePath,
      branch: branch,
      fileName: fileName.isEmpty ? null : fileName,
    );
  }

  // /owner/repo/issues/<number> → issue detail
  if (thirdSeg == 'issues' && segs.length == 4) {
    final number = int.tryParse(segs[3]);
    if (number != null) {
      return PushIssue(owner: owner, repo: repo, number: number);
    }
  }

  // All other GitHub paths → external browser
  return OpenExternal(uri);
}

// ---------------------------------------------------------------------------
// Dispatch helper
// ---------------------------------------------------------------------------

/// Resolves [resolvedHref] to a [LinkAction] and executes it.
/// [context] must be mounted. Safe to call from async callbacks.
Future<void> dispatchLinkAction(
  BuildContext context,
  String resolvedHref,
) async {
  final action = resolveLinkAction(resolvedHref);
  if (action == null) return;

  switch (action) {
    case OpenExternal(:final uri):
      try {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        // Fall back to platformDefault on platforms that don't support
        // externalApplication (e.g. some HarmonyOS builds).
        if (!launched) {
          await launchUrl(uri, mode: LaunchMode.platformDefault);
        }
      } catch (_) {
        // Silently ignore: user may not have an app registered for the scheme
      }

    case PushRepository(:final owner, :final repo):
      if (context.mounted) {
        context.push('/repository/$owner/$repo');
      }

    case PushFileViewer(
        :final owner,
        :final repo,
        :final path,
        :final branch,
        :final fileName,
      ):
      if (context.mounted) {
        context.push(
          AppRoutes.fileViewer,
          extra: {
            'owner': owner,
            'repo': repo,
            'path': path,
            'branch': branch,
            if (fileName != null) 'fileName': fileName,
          },
        );
      }

    case PushIssue(:final owner, :final repo, :final number):
      if (context.mounted) {
        context.push('/issue/$owner/$repo/$number');
      }

    case PushUserProfile(:final username):
      if (context.mounted) {
        context.push('/user/$username');
      }
  }
}
