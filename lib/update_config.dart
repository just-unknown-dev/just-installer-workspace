/// GitHub-Releases-facing configuration for the showcase app.
///
/// This file is the ONLY place that knows about a specific hosting backend
/// (repo owner/name, token) — `just_installer` itself never hardcodes any
/// of this, it only ever receives a `manifestUrl` + `headersBuilder` via
/// `JustInstallerConfig`. Swapping hosting backends is a change here, never
/// a package change.
///
/// Uses the stable `.../releases/latest/download/<asset-name>` URL pattern:
/// it always resolves to the newest published release and avoids both the
/// rate-limited GitHub REST API and `raw.githubusercontent.com` caching lag.
class GitHubReleaseHost {
  const GitHubReleaseHost({required this.owner, required this.repo, this.token});

  final String owner;
  final String repo;

  /// Only needed for a private repo — sent as `Authorization: Bearer $token`,
  /// which GitHub honors for private release-asset downloads.
  final String? token;

  bool get isConfigured => owner.isNotEmpty && repo.isNotEmpty;

  Uri get manifestUrl => Uri.parse('https://github.com/$owner/$repo/releases/latest/download/manifest.json');

  Future<Map<String, String>> Function()? get headersBuilder =>
      token == null ? null : () async => {'Authorization': 'Bearer $token'};
}

/// Fill these in once you've published a GitHub Release containing
/// `manifest.json` + an update artifact (see the README's "Publishing a
/// real demo release" section). Left blank by default, so the app falls
/// back to the bundled local dev server (see `demo_server.dart`) — that's a
/// dev-loop convenience, not a second hosting backend to maintain.
const githubReleaseHost = GitHubReleaseHost(owner: '', repo: '');
