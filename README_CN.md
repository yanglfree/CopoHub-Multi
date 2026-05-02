# CopoHub

一款基于 **Flutter** 构建的功能完整的 GitHub 客户端，主要面向 **鸿蒙OS（HarmonyOS）** 和 **iOS** 平台。CopoHub 为用户提供流畅的移动端体验，支持浏览仓库、追踪趋势、阅读每日报告以及管理 GitHub 个人资料等功能。

## ✨ 功能特性

### 核心功能
- **GitHub OAuth 登录** — 支持标准 OAuth 授权流程及个人访问令牌（PAT）登录
- **首页仪表盘** — 5 标签底部导航：首页、发现、精选、通知、我的
- **仓库浏览器** — README 预览、代码树、Issues、提交记录、Releases、分支/Tag 切换
- **搜索** — 全局仓库与用户搜索
- **通知中心** — GitHub 通知收件箱，支持已读/未读管理

### 发现功能
- **Trending（热门）** — 日/周/月热门仓库，支持编程语言筛选
- **精选** — 算法推荐与人工精选仓库
- **每日报告** — AI 生成的 GitHub 每日趋势分析（支持中/英文）
- **仓库分析** — AI 驱动的仓库深度解析（技术栈、架构、优缺点等）

### 社交功能
- **用户主页** — 贡献热力图（8 种主题色）、置顶仓库/Top 仓库、组织、关注者/正在关注
- **关注/取消关注**、**Star/取消 Star** — 乐观 UI 更新 + 内存缓存
- **分享** — 通过系统原生分享面板分享仓库及用户主页

### Pro 会员
- 会员订阅管理，支持月度/年度/终身方案
- Glassmorphism 风格 + Bento Grid 布局的会员订阅页

### 实用功能
- **剪贴板检测** — 自动识别剪贴板中的 GitHub 仓库 URL，提供快速跳转
- **应用内更新** — 检测后端新版本并提示升级
- **创建仓库** — 直接在 App 内创建新的 GitHub 仓库
- **文件预览** — 内联代码查看器，支持语法高亮
- **Commit Diff 查看器** — 以文件为粒度展示差异详情及增删行数
- **深色模式** — 完整的深色/浅色主题，支持跟随系统切换
- **国际化（i18n）** — 中文（zh）与英文（en）双语支持

## 🏗 架构

```
flutter/lib/
├── api/                    # 网络层
│   ├── github_api_client   #   GitHub REST & GraphQL（dio、ETag 缓存、请求去重）
│   ├── daily_api_client    #   热门趋势 / 每日报告 / 仓库分析
│   ├── copohub_api_client  #   精选内容列表
│   ├── api_cache           #   基于 Hive 的磁盘 + 内存缓存
│   └── api_response        #   统一返回类型
├── models/                 # 数据模型（User、Repository、Issue、Commit 等）
├── pages/                  # 21 个页面模块
│   ├── dashboard/          #   首页信息流
│   ├── discover/           #   热门仓库探索
│   ├── featured/           #   精选推荐
│   ├── daily/              #   AI 每日报告
│   ├── repository/         #   仓库详情（5 个子 Tab）
│   ├── search/             #   全局搜索
│   ├── login/              #   OAuth & PAT 登录
│   ├── member/             #   Pro 会员订阅页
│   └── …                   #   commit、issue、file_viewer、profile、settings 等
├── services/               # 业务逻辑单例
│   ├── auth_service        #   登录状态机
│   ├── pro_member_service  #   订阅状态管理
│   ├── contribution_service#   贡献热力图数据
│   ├── clipboard_detector  #   GitHub URL 检测
│   ├── app_update_service  #   版本检测
│   ├── share_service       #   系统原生分享
│   ├── theme_service       #   主题持久化
│   └── sensitive_content_filter
├── providers/              # Riverpod 状态（auth、theme）
├── router/                 # GoRouter（鉴权守卫、Tab Shell）
├── components/             # 通用 UI 组件（markdown、骨架屏、弹窗等）
├── theme/                  # Material 3 浅色/深色主题（GitHub 风格色板）
├── l10n/                   # 本地化代理（zh、en）
└── utils/                  # 常量、错误信息、平台判断
```

### 主要依赖库

| 类别 | 库 |
|---|---|
| 状态管理 | `flutter_riverpod` |
| 路由 | `go_router` |
| 网络请求 | `dio` |
| 本地存储 | `shared_preferences`、`hive` |
| Markdown 渲染 | `flutter_markdown`、`flutter_highlight` |
| 图片缓存 | `cached_network_image` |
| WebView（OAuth） | `webview_flutter` |
| 国际化 | `intl`、`flutter_localizations` |
| 工具类 | `url_launcher`、`share_plus`、`path_provider` |

## 📱 支持平台

| 平台 | SDK | 状态 |
|---|---|---|
| **鸿蒙OS（HarmonyOS）** | HarmonyOS NEXT（API 15，SDK 5.0.3） | ✅ 主要平台 |
| **iOS** | iOS 12+ | ✅ 已支持 |
| **Android** | API 21+ | 🔧 构建就绪 |

> 代码库为**双工具链**兼容设计：上游 Flutter（iOS/Android）与 Flutter-OH（鸿蒙OS）均可编译。共享 Dart 代码避免使用仅在单一工具链上存在的 API。详见 `AGENTS.md` 中的兼容性规范。

### 鸿蒙OS 专属

`flutter/ohos/` 目录包含：
- **entry 模块** — `EntryAbility.ets`（应用生命周期）、原生 ArkTS 页面
- **平台插件** — `CopoHubClipboardPlugin`、`SharedPreferencesPlugin`、`PathProviderPlugin`
- **HAR** — 预编译的鸿蒙 Flutter 引擎（`flutter.har`）

## 🚀 快速开始

### 前置条件

- Flutter SDK `>=3.4.0 <4.0.0`
- 鸿蒙OS：DevEco Studio + Flutter-OH 工具链
- iOS：Xcode 15+
- GitHub OAuth App 凭据（已在 `constants.dart` 中配置）

### 构建与运行

```bash
# 克隆仓库
git clone https://github.com/yanglfree/CopoHub-Multi.git
cd CopoHub-Multi/flutter

# 安装依赖
flutter pub get

# 运行（iOS）
flutter run -d ios

# 运行（Android）
flutter run -d android
```

#### 鸿蒙OS

```bash
cd flutter/ohos

# 复制并配置签名信息
cp build-profile.example.json5 build-profile.json5
# 编辑 build-profile.json5，填入你的签名证书路径

# 构建 HAP
hvigorw assembleHap
```

## 🔧 配置说明

| 配置项 | 文件位置 |
|---|---|
| GitHub OAuth 凭据 | `lib/utils/constants.dart` |
| API 基础 URL | `lib/utils/constants.dart` |
| 鸿蒙OS 签名配置 | `ohos/build-profile.json5` |
| 应用版本号 | `pubspec.yaml` → `version` |

## 📄 许可证

本项目为私有项目，保留所有权利。

## 📬 联系方式

- 邮箱：youdroid2048@gmail.com
