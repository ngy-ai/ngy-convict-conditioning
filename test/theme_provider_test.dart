import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngy_convict_conditioning/core/theme.dart';
import 'package:ngy_convict_conditioning/providers/theme_provider.dart';
import 'package:ngy_convict_conditioning/widgets/theme_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 用给定的本地存储内容搭一个容器（键名带 shared_preferences 的 flutter. 前缀）。
  Future<ProviderContainer> containerWith(Map<String, Object> stored) async {
    SharedPreferences.setMockInitialValues(stored);
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('默认跟随系统', () async {
    final container = await containerWith({});
    expect(container.read(themeModeProvider), ThemeMode.system);
  });

  test('读取上次保存的皮肤', () async {
    final container = await containerWith({'flutter.theme_mode': 'dark'});
    expect(container.read(themeModeProvider), ThemeMode.dark);
  });

  test('选择皮肤立即生效并写入本地，跟随系统时清除记录', () async {
    final container = await containerWith({});
    final prefs = container.read(sharedPreferencesProvider);

    await container.read(themeModeProvider.notifier).select(ThemeMode.light);
    expect(container.read(themeModeProvider), ThemeMode.light);
    expect(prefs.getString('theme_mode'), 'light');

    await container.read(themeModeProvider.notifier).select(ThemeMode.dark);
    expect(prefs.getString('theme_mode'), 'dark');

    await container.read(themeModeProvider.notifier).select(ThemeMode.system);
    expect(container.read(themeModeProvider), ThemeMode.system);
    expect(prefs.getString('theme_mode'), isNull);
  });

  test('本地存了无法识别的值时回退到跟随系统', () async {
    final container = await containerWith({'flutter.theme_mode': 'neon'});
    expect(container.read(themeModeProvider), ThemeMode.system);
  });

  testWidgets('在外观面板里点「深色」会立即生效、关闭面板并写入本地', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Center(
                child: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showThemePicker(context),
                    child: Text('当前皮肤：${ref.watch(themeModeProvider).name}'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('当前皮肤：system'), findsOneWidget);

    await tester.tap(find.text('当前皮肤：system'));
    await tester.pumpAndSettle();
    expect(find.text('外观'), findsOneWidget);
    expect(find.text('深色「夜铁」'), findsOneWidget);

    await tester.tap(find.text('深色「夜铁」'));
    await tester.pumpAndSettle();

    expect(find.text('外观'), findsNothing, reason: '选择后面板应关闭');
    expect(find.text('当前皮肤：dark'), findsOneWidget);
    expect(prefs.getString('theme_mode'), 'dark');
  });
}
