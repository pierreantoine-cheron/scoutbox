import 'dart:io';

void main(List<String> args) async {
  if (args.length != 1) {
    _printUsageAndExit();
  }

  final mode = args.single;
  if (!_isSupportedMode(mode)) {
    stderr.writeln('Unsupported bump mode: $mode');
    _printUsageAndExit(exitCode: 64);
  }

  final frontendDirectory = Directory.current;
  final pubspecFile = File('${frontendDirectory.path}/pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    stderr.writeln('Could not find pubspec.yaml in ${frontendDirectory.path}.');
    exit(1);
  }

  final pubspecContent = await pubspecFile.readAsString();
  final currentVersion = _parseVersion(pubspecContent);
  final nextVersion = currentVersion.bump(mode);
  final updatedContent = pubspecContent.replaceFirst(
    RegExp(r'^version:\s+.+$', multiLine: true),
    'version: ${nextVersion.pubspecValue}',
  );

  await pubspecFile.writeAsString(updatedContent);

  stdout.writeln(
    'Updated version: ${currentVersion.pubspecValue} -> ${nextVersion.pubspecValue}',
  );
  stdout.writeln('Building release APK...');

  try {
    await _runCommand(_flutterCommand, [
      'build',
      'apk',
      '--release',
      '--dart-define=SCOUTBOX_CHANNEL=beta',
    ], workingDirectory: frontendDirectory.path);
  } on ProcessException catch (error) {
    stderr.writeln('Failed to start Flutter build: ${error.message}');
    exit(1);
  }

  stdout.writeln('Build completed. Check build/app/outputs/apk/release/.');
}

Future<void> _runCommand(
  String executable,
  List<String> arguments, {
  required String workingDirectory,
}) async {
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    mode: ProcessStartMode.inheritStdio,
  );

  final exitCode = await process.exitCode;
  if (exitCode != 0) {
    stderr.writeln(
      'Command failed with exit code $exitCode: $executable ${arguments.join(' ')}',
    );
    exit(exitCode);
  }
}

String get _flutterCommand => Platform.isWindows ? 'flutter.bat' : 'flutter';

bool _isSupportedMode(String mode) =>
    mode == 'patch' || mode == 'minor' || mode == 'major';

Never _printUsageAndExit({int exitCode = 64}) {
  stderr.writeln('Usage: dart run tool/release.dart <patch|minor|major>');
  exit(exitCode);
}

_AppVersion _parseVersion(String pubspecContent) {
  final match = RegExp(
    r'^version:\s+(\d+)\.(\d+)\.(\d+)\+(\d+)$',
    multiLine: true,
  ).firstMatch(pubspecContent);
  if (match == null) {
    stderr.writeln(
      'Could not parse version from pubspec.yaml. Expected x.y.z+n.',
    );
    exit(1);
  }

  return _AppVersion(
    major: int.parse(match.group(1)!),
    minor: int.parse(match.group(2)!),
    patch: int.parse(match.group(3)!),
    build: int.parse(match.group(4)!),
  );
}

class _AppVersion {
  const _AppVersion({
    required this.major,
    required this.minor,
    required this.patch,
    required this.build,
  });

  final int major;
  final int minor;
  final int patch;
  final int build;

  String get name => '$major.$minor.$patch';

  String get pubspecValue => '$name+$build';

  _AppVersion bump(String mode) {
    switch (mode) {
      case 'patch':
        return _AppVersion(
          major: major,
          minor: minor,
          patch: patch + 1,
          build: build + 1,
        );
      case 'minor':
        return _AppVersion(
          major: major,
          minor: minor + 1,
          patch: 0,
          build: build + 1,
        );
      case 'major':
        return _AppVersion(
          major: major + 1,
          minor: 0,
          patch: 0,
          build: build + 1,
        );
    }

    stderr.writeln('Unsupported bump mode: $mode');
    exit(64);
  }
}
