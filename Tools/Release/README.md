# 公开发布封包 / Public release packaging

NavPlanner 采用 UTM、Provenance 等开源项目常见的公开侧载边界：

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
  --bundle-id com.example.NavPlanner \
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
资源。最终 IPA 与 DMG 内的路径均为 `Database/navdata.sqlite`。脚本还会核对
源文件、IPA 与 Mac App 的 SHA-256，记录数据库大小和 AIRAC 到 manifest，并由
独立审计再次验证两端数据库一致且 `PRAGMA quick_check` 通过。

根目录 `releases/` 被 Git 忽略，并且只允许长期保留一个
`release-VERSION/` 候选目录。脚本拒绝覆盖既有候选；原始日志、DerivedData、
DMG staging 和其他构建中间产物只写入 `releases/.navplanner-build-*` 临时目录，
正常结束、失败或收到可捕获的中断信号时都会自动删除。不得在仓库中重新创建或保留 `target/`，
也不得在 `releases/` 下保存旧候选、失败尝试、调试 App、截图或原始日志。

最终公开候选只包含：

- unsigned Universal IPA；
- ad-hoc Catalyst App 与未 notarize DMG；
- 脱敏 manifest 和双语公开说明；
- SHA-256 checksums。

脚本在封包前核对 Web、Database 和 PrivacyInfo bundle parity，并在结束前强制
执行独立审计。IPA 与 DMG 会带上该示例数据库，构建成功证明文件完整性与封包一致性。

也可独立复跑审计：

```bash
Tools/Release/audit_public_release.sh releases/release-0.1.0
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
