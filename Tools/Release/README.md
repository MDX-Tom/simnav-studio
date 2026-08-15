# 公开发布封包 / Public release packaging

正式产品名称为 **SimNav Studio**，桌面图标短名称为 **SimNav**，副标题为
**Planning & Navigation for Flight Simulation**。发布工件统一使用
`SimNav-Studio-<version>-…` 文件名；内部 Xcode 工程、scheme、可执行文件、
与数据目录继续保留 `NavPlanner` 标识以兼容现有源码，Bundle Identifier 则为
`com.mdxtom.simnavstudio`。旧 Bundle Identifier 的沙盒数据不会自动迁移到新 App。

SimNav Studio 采用 UTM、Provenance 等开源项目常见的公开侧载边界：

- GitHub 面向的 iOS/iPadOS 工件关闭 Xcode code signing，并使用
  `-unsigned.ipa` 后缀。
- IPA 不含维护者证书、TeamIdentifier 或 provisioning profile。安装者必须
  通过 AltStore、SideStore、Sideloadly 或其他可信流程，使用自己的账号重签。
- Mac 本地候选只使用 `codesign --sign -` 的 ad-hoc 签名，不含证书 Authority
  或 TeamIdentifier；它没有 Developer ID 签名，也没有 notarize。
- 真实 development、distribution、Developer ID 和 App Store 凭据只能放在
  本机忽略文件或 CI secret storage，绝不能进入源码、GitHub xcarchive、原始日志
  或公开元数据。
- 已签名二进制会公开证书的非秘密身份信息。如果维护者不希望个人开发者身份
  对外可见，就不能发布个人证书签名的二进制。

## 本机私有签名

推荐运行自动配置脚本。它从本机有效 Apple Development 证书的 subject OU
读取 Team ID，并且不会打印身份值：

```bash
Tools/Signing/setup_local_signing.sh
```

目标文件已被 Git 忽略。工程 Debug/Release configuration 引用受跟踪的
`Config/CodeSigning.xcconfig`，后者通过 `#include?` 自动加载本机文件；因此
Xcode GUI 与命令行都能使用同一份本机签名，而仓库没有具体 Team ID。

如果自己的账号不能注册公开 Bundle Identifier，可只在本机覆盖：

```bash
Tools/Signing/setup_local_signing.sh \
  --bundle-id com.example.simnavstudio \
  --force
```

也可从 `Config/CodeSigning.local.xcconfig.example` 手工复制。不得把真实值写回
tracked public config 或 example。公开封包脚本会以命令行最高优先级显式关闭
签名，因此不会继承本机 Team、identity 或 profile。

若 Xcode 报告 profile 缺失或过期，请在 `Xcode > Settings > Accounts` 中刷新
Apple Account、证书与 profile，再重新运行助手。账号凭据只应存在于 Xcode 与
Keychain，不能写入 xcconfig、脚本或日志。

## 构建 public-safe 候选

每次构建 release 前，必须把拟随发行版分发的最新示例导航数据库放到：

```text
database/e_dfd_PMDG_release.s3db
```

根目录 `database/` 整体被 Git 忽略，GitHub 公开源码仓库不带数据库。不得用
`e_dfd_PMDG_local.s3db`、旧的 `NavPlanner/Resources/Database/navdata.sqlite`
或其他开发数据库替代 release 输入。脚本会拒绝缺少 release 数据库、
`PRAGMA quick_check` 不通过或缺少核心 PMDG 表的构建。

```bash
Tools/Release/build_public_release.sh
```

封包脚本会把上述文件临时复制为
`NavPlanner/Resources/Database/navdata.sqlite`，让 iOS 与 Mac Catalyst 构建都将
它作为 App 默认数据库；无论构建成功、失败或中断，脚本都会恢复构建前的本地
资源。同一个输入文件也会逐字节复制到 Web 包的
`app/NavPlanner/Resources/Database/navdata.sqlite`，由各平台启动器在首次启动时默认
激活。脚本会核对源文件、IPA、Mac App 与 Web 副本的 SHA-256，记录数据库大小、AIRAC
和 revision 到 manifest，并由独立审计再次验证三平台数据库一致且
`PRAGMA quick_check` 通过。

根目录 `releases/` 被 Git 忽略。每个不同版本都必须长期保留在独立的
`release-VERSION/` 目录中；生成新版本时，**严禁删除、移动、替换或覆盖其他既有版本**。
用户明确要求重建相同版本号时允许覆盖，但旧候选会一直保留到新候选完成全部构建和审计，
最终再用 Darwin `RENAME_SWAP` 原子交换；若目标版本此前不存在，则使用 `RENAME_EXCL`
原子排他重命名。这同时避免长构建期间出现目录缺口或同版本竞态。原始日志、DerivedData、
DMG staging 和其他构建中间产物只写入本次构建自己的
`releases/.navplanner-build-*` 临时目录，正常结束、失败或收到可捕获的中断信号时都会自动
删除。不得在仓库中重新创建或保留 `target/`，也不得在 `releases/` 下保存失败尝试、调试
App、截图、原始日志或其他非 `release-VERSION/` 项。

新生成的最终公开候选包含三个正式平台：

- unsigned Universal IPA；
- ad-hoc Catalyst App 与未 notarize DMG；
- `web-bundle/SimNav-Studio-VERSION-web.zip` Local Web 部署 ZIP（解压根目录为
  `SimNav-Studio-VERSION-web/`，包含 macOS /
  Windows / Linux 启停脚本、单一 Web/Swift 源、固定 Dockerfile/Compose、内部
  manifest/checksums，以及与 Apple 工件相同的 release 数据库；不含用户数据）；
- 脱敏 manifest 和双语公开说明；
- SHA-256 checksums。

脚本在封包前核对 Web、Database 和 PrivacyInfo bundle parity，并在结束前强制
执行独立审计。IPA、DMG 与 Web 会带上逐字节相同的示例数据库；Web 审计会复验该数据库
与选定输入的 SHA-256、SQLite 完整性和 header 元数据，并复验唯一 UI/Swift core、每个文件
checksum、localhost 端口、非 root/read-only 容器边界。审计还会实际构建和启动 Linux Swift
镜像，确认首次启动自动激活内置数据库，再完成 shared tests、health、首页、Host 拒绝、
容器权限、真实 HTTP 数据库导入与容器重启持久化 smoke；同一镜像还会强制运行 SwiftNIO
transport，验证 Host、PMTiles Range、数据库导入与重启持久化。

Web 的受跟踪封包入口为：

```bash
Tools/LocalWeb/package_web_release.sh --output /tmp/SimNav-Web --build-macos-native \
  --database database/e_dfd_PMDG_release.s3db
Tools/LocalWeb/audit_web_release.sh /tmp/SimNav-Web \
  --expected-database database/e_dfd_PMDG_release.s3db --docker-smoke
```

正式 release build 会自动执行这两步并把 manifest schema 升级为 6，完成 Web package audit
后再将整个包写入 `web-bundle/SimNav-Studio-VERSION-web.zip`，且 ZIP 只能包含
`SimNav-Studio-VERSION-web/` 这一个顶层目录。顶层
`SHA256SUMS.txt` 严格只列 iOS IPA、macOS DMG 和 Web ZIP 三个下载工件；ZIP 内部仍保留
逐文件 package checksum。如要随 release 加入 Windows 原生 Swift server，
先从 `.github/workflows/local-web-windows.yml` 或 Windows 本机脚本得到已 smoke 的 bundle，
再设置 `SIMNAV_WINDOWS_NATIVE_BUNDLE=/path/to/bundle`。Windows 启动器发现 `.exe` 时会直接
运行其原生 SwiftNIO transport 与随包 Swift/SQLite runtime DLL，不要求用户安装 Swift，也不启动 Linux / WSL /
Docker；没有原生 bundle 时才使用 Docker Desktop 兜底。该 bundle 必须先在 Windows
完成 loopback、HTTP 数据库导入和 `.exe` 重启持久化 smoke。

也可独立复跑审计：

```bash
Tools/Release/audit_public_release.sh releases/release-0.1.2
```

审计遇到以下情况会失败：已跟踪或未跟踪但未忽略的公开源码含 signing
credential/具体 Development Team、IPA 内嵌 profile/signature、证书 Authority、
TeamIdentifier、开发者 home path、账号邮箱、原始日志、xcarchive、DMG 内 App
不一致或 checksum 不匹配。

## 正式商店或 notarized 分发

若以后需要正式签名，只能在受保护的 private CI 中从 encrypted secrets 临时导入
P12/profile/API key，不能输出内容或上传这些输入。job 完成后应删除临时 keychain
和 profile。只有维护者明确同意最终签名身份对外可见时，才能发布该签名二进制。

## 参考实现

- [UTM unsigned archive build](https://github.com/utmapp/UTM/blob/main/scripts/build_utm.sh)
- [UTM unsigned/fake-signed IPA packaging](https://github.com/utmapp/UTM/blob/main/scripts/package.sh)
- [UTM release workflow and private signing secrets](https://github.com/utmapp/UTM/blob/main/.github/workflows/build.yml)
- [UTM local signing configuration sample](https://github.com/utmapp/UTM/blob/main/CodeSigning.xcconfig.sample)
- [Provenance unsigned IPA workflow](https://github.com/Provenance-Emu/Provenance/blob/develop/.github/workflows/build.yml)
- [GitHub Actions encrypted secrets guidance](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets)
