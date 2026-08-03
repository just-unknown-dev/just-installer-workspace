import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:just_installer/just_installer.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'demo_server.dart';
import 'update_config.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'just_installer showcase',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
      home: const UpdateDemoPage(),
    );
  }
}

class UpdateDemoPage extends StatefulWidget {
  const UpdateDemoPage({super.key});

  @override
  State<UpdateDemoPage> createState() => _UpdateDemoPageState();
}

class _UpdateDemoPageState extends State<UpdateDemoPage> {
  JustInstaller? _installer;
  PackageInfo? _packageInfo;
  DemoUpdateServer? _devServer;
  UpdateState _state = const UpdateIdle();
  String? _initError;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final info = await PackageInfo.fromPlatform();

      Uri manifestUrl;
      Future<Map<String, String>> Function()? headersBuilder;
      if (githubReleaseHost.isConfigured) {
        manifestUrl = githubReleaseHost.manifestUrl;
        headersBuilder = githubReleaseHost.headersBuilder;
      } else {
        final versionCode = int.tryParse(info.buildNumber) ?? 1;
        _devServer = await DemoUpdateServer.start(currentVersionCode: versionCode);
        manifestUrl = _devServer!.manifestUrl;
      }

      final installer = JustInstaller(JustInstallerConfig(manifestUrl: manifestUrl, headersBuilder: headersBuilder));
      installer.updates.listen((state) => setState(() => _state = state));

      setState(() {
        _packageInfo = info;
        _installer = installer;
      });
    } catch (e) {
      setState(() => _initError = e.toString());
    }
  }

  @override
  void dispose() {
    _installer?.dispose();
    _devServer?.close();
    super.dispose();
  }

  void _checkForUpdate() {
    final info = _packageInfo!;
    _installer!.checkForUpdate(
      currentVersionCode: int.tryParse(info.buildNumber) ?? 1,
      currentVersion: info.version,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('just_installer showcase')),
      body: Center(child: Padding(padding: const EdgeInsets.all(24), child: _buildBody())),
    );
  }

  Widget _buildBody() {
    if (_initError != null) {
      return Text('Failed to start: $_initError', style: const TextStyle(color: Colors.red));
    }
    final installer = _installer;
    final info = _packageInfo;
    if (installer == null || info == null) {
      return const CircularProgressIndicator();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Current version: ${info.version} (build ${info.buildNumber})'),
        if (!githubReleaseHost.isConfigured)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Using the local dev server — fill in update_config.dart to\n'
              'point at a real GitHub Release.',
              textAlign: TextAlign.center,
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ),
        const SizedBox(height: 24),
        _buildStateView(installer),
      ],
    );
  }

  Widget _buildStateView(JustInstaller installer) {
    return switch (_state) {
      UpdateIdle() => ElevatedButton(onPressed: _checkForUpdate, child: const Text('Check for update')),
      UpdateChecking() => const CircularProgressIndicator(),
      UpdateUpToDate() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Up to date'),
          const SizedBox(height: 12),
          TextButton(onPressed: _checkForUpdate, child: const Text('Check again')),
        ],
      ),
      UpdateAvailable(:final manifest) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Update available: ${manifest.version}'),
          if (manifest.releaseNotes != null) ...[const SizedBox(height: 4), Text(manifest.releaseNotes!)],
          const SizedBox(height: 12),
          ElevatedButton(onPressed: installer.download, child: const Text('Download')),
        ],
      ),
      UpdateDownloading(:final progress) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 240, child: LinearProgressIndicator(value: progress.fraction)),
          const SizedBox(height: 8),
          Text('${(progress.fraction * 100).toStringAsFixed(1)}%'),
          TextButton(onPressed: installer.pauseDownload, child: const Text('Pause')),
        ],
      ),
      UpdatePaused(:final progress) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Paused at ${(progress.fraction * 100).toStringAsFixed(1)}%'),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: installer.download, child: const Text('Resume')),
          TextButton(onPressed: installer.cancelDownload, child: const Text('Cancel')),
        ],
      ),
      UpdateVerifying() => const Column(
        mainAxisSize: MainAxisSize.min,
        children: [CircularProgressIndicator(), SizedBox(height: 8), Text('Verifying...')],
      ),
      UpdateVerified() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Verified — ready to install'),
          const SizedBox(height: 12),
          if (defaultTargetPlatform == TargetPlatform.android)
            ElevatedButton(onPressed: installer.install, child: const Text('Install'))
          else ...[
            ElevatedButton(onPressed: installer.runDownloadedInstaller, child: const Text('Run installer')),
            const SizedBox(height: 4),
            TextButton(onPressed: installer.revealDownloadedFileInFolder, child: const Text('Reveal in folder')),
          ],
        ],
      ),
      UpdateInstalling(:final fraction) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 240, child: LinearProgressIndicator(value: fraction)),
          const SizedBox(height: 8),
          const Text('Installing...'),
        ],
      ),
      UpdateInstalled(:final installedVersion) => Text('Installed $installedVersion'),
      UpdateFailed(:final reason) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Failed: $reason', style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _checkForUpdate, child: const Text('Try again')),
        ],
      ),
    };
  }
}
