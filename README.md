# 囚徒健身（Convict Conditioning）

一款记录「六艺」训练的跨平台健身 App，支持 Android、iOS 与 Windows 桌面。全部数据保存在
设备本地，无需注册账号，离线可用。

## 功能

- **六艺动作库**：俯卧撑、深蹲、引体向上、举腿、桥、倒立撑，每艺十式共 60 式，
  每式带动作要领与初/中/高三级晋级标准。
- **训练记录**：按天记录每个动作的组数与每组次数（倒立撑前几式为计时的秒数），
  支持从今日计划一键带入、手动添加动作、补录往期训练、编辑与删除记录。
- **训练计划**：内置三种经典模板，按你当前所在式自动解析出每天该练什么。
  - 新血：每周 3 练，六艺全练，适合入门；
  - 好习惯：每周 6 练，推类（俯卧撑、倒立撑、举腿）与拉类（引体、深蹲、桥）交替；
  - 老手：每周 6 练，每天专攻一艺，冲击最高标准；
  - 自定义：自选每周天数与要练的六艺。
- **进度与进阶**：六艺各自可查看十式阶梯、当前所在式、已达成标准与历史最佳；
  训练后若达到当前式的高级标准，会提示是否进阶到下一式。
- **统计**：训练次数、累计组数/次数、连续训练天数、近四周每日组数趋势、六艺训练量分布。
- **数据备份**：把训练记录、六艺进度与训练计划导出为 JSON 文件；换机或误删后选文件
  覆盖式恢复（恢复前会列出备份内容并二次确认）。
- **原书阅读**：内置《囚徒健身》EPUB，应用内直接解析与阅读——封面、目录、正文与插图，
  记住读到哪一节；六艺详情页的「书中指导」可直接跳到书里对应该式的那一节。
- **划线**：阅读时选中正文即浮出工具条——复制、马克笔、波浪线、直线（手机长按选中，
  桌面用鼠标拖选或双击选词，松手就出工具条）；划线存在本地，右上角「本章划线」
  列出本章全部划线，点一条跳回原文，也可以删掉。

## 技术栈

| 项目 | 选择 |
| --- | --- |
| 框架 | Flutter（单代码库编译 Android / iOS / Windows） |
| 状态管理 | Riverpod 3 |
| 本地存储 | sqflite（SQLite） |
| 路由 | go_router（底部导航用 StatefulShellRoute） |
| 图表 | fl_chart |
| 本地偏好 | shared_preferences（皮肤选择、阅读位置、阅读划线） |
| 文件对话框 | file_selector（备份导出/导入） |
| EPUB 解析 | archive（解 zip）+ xml（读 OPF/NCX）+ html（正文分块） |

## 皮肤

两套皮肤共用同一套设计语言（同源主色 + 同样的圆角与描边规则），只切换明暗：

| 皮肤 | 底色 | 卡片 | 主色 |
| --- | --- | --- | --- |
| 浅色「纸感」 | 牛皮纸暖白 `#F5F0EA` | 纯白 + 暖灰描边 | 铁锈红 `#A8431A` |
| 深色「夜铁」 | 暖黑 `#121011` | 铁灰 `#1B1817` | 亮铁锈橙 `#FF9E6B` |

默认跟随系统，也可以在首页右上角点皮肤图标，在外观面板里固定为其中一套；
选择记录在本地（`shared_preferences`），下次启动沿用。

颜色集中在 `lib/core/theme.dart` 的 `_Tokens` 中，页面层一律使用 `ColorScheme` 语义色，
新增页面无需判断明暗。皮肤偏好由 `lib/providers/theme_provider.dart` 管理。

## 目录结构

```
lib/
  core/          主题、路由、日期工具
  data/
    backup/      备份格式（JSON 编解码）与导出恢复、文件读写
    book/        EPUB 解析（元数据 / 目录 / 正文分节 / 插图）与六艺定位
    db/          SQLite 打开与建表
    models/      六艺、式、训练记录、训练计划等模型
    repositories/ 训练记录 / 进度 / 计划的读写
    seed/        六艺 60 式动作库与标准数据
  domain/        计划生成、进阶判定、统计计算（纯逻辑，可单测）
  providers/     Riverpod 状态（含皮肤偏好、阅读位置）
  features/      各页面：今日、记录、计划、六艺、统计、训练录入、原书阅读
  widgets/       通用组件（含皮肤选择面板）
test/
  domain_test.dart          动作库、进阶判定、统计与计划生成的单元测试
  repository_test.dart      数据库读写（用 sqflite ffi 跑在内存里）
  theme_provider_test.dart  皮肤偏好的读取、切换与持久化
  backup_test.dart          备份的导出、覆盖恢复与格式校验
  backup_files_test.dart    备份文件的保存 / 选取 / BOM 处理
  backup_flow_test.dart     备份页面的渲染与按钮行为
  book_asset_test.dart      EPUB 资产与解析依赖（archive / xml / html）的冒烟测试
  book_parser_test.dart     真实书档的元数据、目录、分节与插图解析
  book_locator_test.dart    六艺十式 → 书中章节小节的定位（含 60 式覆盖）
  book_reader_test.dart     封面/目录/正文渲染、小节跳转、选中划线、路由参数
  book_reading_position_test.dart  阅读位置的读取、写入与沿用
  book_highlight_test.dart  划线切分正文、存档编解码与本地保存
tool/
  app_icon/      应用图标母版与出图脚本（见「应用图标」一节）
```

## 运行

```bash
flutter pub get
flutter run                  # 连接设备或模拟器
flutter test                 # 运行单元测试
flutter run -d windows           # Windows 桌面（调试）
flutter build windows --release  # Windows 桌面发布包
flutter build apk --release      # Android 发布包
flutter build ios --release      # iOS（需在 macOS + Xcode 上执行）
```

### 在 Android 上运行（Windows）

Gradle 需要 **JDK 17+**；本机 `JAVA_HOME` 默认指向 Java 8，直接构建会在起步阶段失败（`Dependency requires at least JVM runtime version 11`）。把 Flutter 用的 JDK 指到本机的 JDK 17（只需设置一次）：

```powershell
flutter config --jdk-dir="E:\dev\ms-17.0.18"
```

也可以只在当前会话里临时覆盖：

```powershell
$env:JAVA_HOME = 'E:\dev\ms-17.0.18'
```

> JDK 必须是**完整版**（带 `jlink.exe`）。IDEA 自带的 `jbr` 等裁剪版会报 `jlink executable ... does not exist`；Java 26 则超出 Gradle 8.14 的支持范围。

启动模拟器并运行：

```powershell
flutter emulators                    # 列出本机模拟器
flutter emulators --launch pixel36   # 本机模拟器 id，已在运行可跳过
flutter devices                      # 确认设备已连接，如 emulator-5554
flutter run -d emulator-5554         # 运行，支持热重载
```

不用 `flutter run`、直接把 debug 包装到模拟器：

```powershell
flutter build apk --debug
adb -s emulator-5554 install -r build\app\outputs\flutter-apk\app-debug.apk
adb -s emulator-5554 shell am start -n com.ngy.ngy_zhuntifa_counter/.MainActivity
```

打包：

```bash
flutter build apk --release          # Android
flutter build appbundle --release    # Android（上架 Google Play）
flutter build ios --release          # iOS，需要在 macOS 上执行
```

> iOS 首次构建时 Flutter 会自动生成 `ios/Podfile` 并执行 `pod install`。

## 应用图标

图标是「鎏金徽章」：深墨底上一枚金色徽章——外圈细金环、内圈一圈念珠（其中六颗稍大，
暗合「六艺」），正中是金色「囚」。全部矢量式绘制：字形按实际墨迹居中缩放，比例不受
字体自带留白影响；所有平台尺寸都从同一张 1024 母版缩放，不放大小图、也不带水印。

```bash
python tool/app_icon/make_icon.py                   # 鎏金徽章（默认）
python tool/app_icon/make_icon.py --style flat       # 另一路配色：--variant rust / night
python tool/app_icon/make_icon.py --from 设计稿.png   # 用外部母版（正方形，建议 1024）
python tool/app_icon/make_icon.py --check            # 只校验三端图标
```

需要 Pillow（`pip install pillow`）。Android 侧同时生成自适应图标
（`mipmap-anydpi-v26` + 前景层 + 底色），徽章缩到 72/108 安全区，圆形裁切下不顶边。

## 发布

推 `v*` 标签即触发 GitHub Actions 自动构建 Android APK，并挂到 Releases 页供下载：

```bash
git tag v1.0.0
git push origin v1.0.0
```

标签触发的 versionName 取标签号（`v1.2.3` → `1.2.3`），versionCode 取工作流运行序号；
也可以在 Actions 页手动运行「发布构建」，手动运行只在当次运行的 Artifacts 里留存产物。
工作流见 `.github/workflows/release.yml`。

### 正式签名

release 包用正式 keystore 签名（为将来上架做准备）。签名参数从 `android/key.properties`
读取（该文件不入库）：本地构建时它指向仓库外的 keystore，CI 上由 Secrets 还原：

| Secret | 内容 |
| --- | --- |
| `KEYSTORE_BASE64` | keystore 文件的 base64 |
| `KEYSTORE_PASSWORD` | keystore 密码（store 与 key 同用） |
| `KEY_ALIAS` | 密钥别名 |

没有 `android/key.properties` 时构建会退回 debug 签名。keystore 与密码请离线备份，
丢失后无法对同一个包继续更新。

## 数据说明

- 各级标准（组 × 次数）参考《囚徒健身》给出的晋级标准，用于给出训练目标；
  实际训练量因人而异，训练录入时每一组的次数都可以按实际完成情况调整。
- 动作标准可在 `lib/data/seed/big_six_seed.dart` 中统一修改。
- 数据库文件为本地 `convict_conditioning.db`（Windows 位于 `%APPDATA%\<厂商>\<应用名>\`），
  卸载应用会一并删除，**换机或卸载前请先在首页右上角「数据备份」里导出**。
- 备份文件为 UTF-8 的 JSON，格式与版本号集中在 `lib/data/backup/backup_data.dart`；
  导入是覆盖式的（先清空再写入，同一事务），不会与现有数据合并。
- 阅读划线记在 `shared_preferences`（键 `book.highlights`，一段 JSON），只存「章 + 小节 +
  第几段 + 段内字符区间 + 样式」；区间以段落原文为坐标，不含正文首行缩进。
- 原书在启动后解析一次并常驻内存（约 8 MB）；书里夹的两页来源网站推广页
  （`ad_chapter*.xhtml`）解析时直接跳过。书的用词与动作库不完全一致
  （书里「平卧抬膝」＝动作库「平躺屈膝抬腿」），所以六艺与第几式按序号对应，
  入口处显示书里的小节名，便于对上号。

## 后续可扩展

- 每式自定义标准（覆盖内置参考值）
- 训练提醒通知
- 备份的合并导入、CSV 导出
- 自动定时备份到指定目录
- 动作示意图与视频
- 账号与云同步
