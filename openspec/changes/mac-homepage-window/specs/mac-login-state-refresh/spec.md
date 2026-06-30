## ADDED Requirements

### Requirement: 登录状态变化刷新主页
系统 SHALL 在登录状态变化时自动刷新主页功能入口和关注数据。

#### Scenario: 登录后显示"我的关注"入口
- **WHEN** 用户登录成功（`Preferences.shared.loginInfo` 变化）
- **THEN** 主页功能入口区显示"我的关注"按钮，并重新拉取主页数据

#### Scenario: 登出后隐藏"我的关注"入口
- **WHEN** 用户退出登录（`Preferences.shared.loginInfo` 置 nil）
- **THEN** 主页功能入口区隐藏"我的关注"按钮，并重新拉取主页数据

### Requirement: 关注页面响应登录状态
系统 SHALL 在关注页面可见时检查登录状态。

#### Scenario: 登录后进入关注页面
- **WHEN** 用户在已登录状态下进入关注页面（`viewWillAppear`）
- **THEN** 页面自动发起请求获取关注列表

#### Scenario: 未登录时进入关注页面
- **WHEN** 用户在未登录状态下进入关注页面
- **THEN** 页面显示"请先登录"提示，不发起网络请求
