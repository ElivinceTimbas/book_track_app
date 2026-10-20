import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final lib = Directory('lib').absolute.uri;
  final feature = lib.resolve('features/reading/');
  const folders = {
    'presentation': ['pages', 'widgets', 'blocs'],
    'domain': ['entities', 'repositories', 'usecases'],
    'data': ['repositories', 'datasources', 'models'],
  };

  test('feature files live in their responsibility folders', () {
    for (final layer in folders.entries) {
      final directory = Directory.fromUri(feature.resolve('${layer.key}/'));
      final entries = directory.listSync();
      expect(entries.every((entry) => entry is Directory), isTrue);
      expect(
        entries.map(
          (entry) => entry.uri.pathSegments.where((s) => s.isNotEmpty).last,
        ),
        unorderedEquals(layer.value),
      );
      for (final entry in entries.cast<Directory>()) {
        expect(entry.listSync(recursive: true).whereType<File>(), isNotEmpty);
      }
    }
  });

  test('dependencies point inward and core DI owns concrete wiring', () {
    final imports = RegExp(
      r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
      multiLine: true,
    );
    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.uri.path.endsWith('.dart')) continue;
      final source = file.absolute.uri.toString();
      bool within(String path) =>
          source.startsWith(lib.resolve(path).toString());
      final pureDart =
          within('features/reading/domain/') ||
          within('core/errors/') ||
          within('core/utils/');
      for (final match in imports.allMatches(file.readAsStringSync())) {
        final import = match[1]!;
        final target = import.startsWith('package:book_track_app/')
            ? lib.resolve(import.substring('package:book_track_app/'.length))
            : file.absolute.uri.resolve(import);
        bool targets(String path) =>
            target.toString().startsWith(lib.resolve(path).toString());
        final reason = '${file.path} must not depend on $import';
        if (pureDart && target.scheme != 'file') {
          expect(
            import.startsWith('dart:') &&
                !{'dart:ui', 'dart:io'}.contains(import),
            isTrue,
            reason: reason,
          );
        }
        if (target.scheme == 'file') {
          if (within('core/') && !within('core/di/')) {
            expect(
              targets('core/') && !targets('core/di/'),
              isTrue,
              reason: reason,
            );
          }
          for (final layer in folders.keys) {
            if (!within('features/reading/$layer/')) continue;
            expect(
              targets('features/reading/$layer/') ||
                  targets('features/reading/domain/') ||
                  targets('core/errors/') ||
                  targets('core/utils/') ||
                  (layer == 'presentation' && targets('core/theme/')),
              isTrue,
              reason: reason,
            );
          }
          if (within('features/reading/domain/entities/') ||
              within('features/reading/domain/repositories/')) {
            expect(
              targets('features/reading/domain/usecases/'),
              isFalse,
              reason: reason,
            );
          }
        } else if (within('features/reading/presentation/')) {
          expect(
            RegExp(r'^package:(http|dio|xml|shared_preferences|share_plus)/')
                .hasMatch(import),
            isFalse,
            reason: reason,
          );
        }
      }
    }
  });
}
