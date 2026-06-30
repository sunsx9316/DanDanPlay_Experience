## ADDED Requirements

### Requirement: Banner 轮播展示
系统 SHALL 在主页顶部展示 Banner 轮播区，支持自动滚动、悬停暂停和点击跳转。

#### Scenario: Banner 自动滚动
- **WHEN** 主页加载完成且有多个 Banner
- **THEN** 系统每 8 秒自动切换到下一张 Banner，并更新页码指示器

#### Scenario: 鼠标悬停暂停
- **WHEN** 鼠标进入 Banner 区域
- **THEN** 自动滚动暂停
- **WHEN** 鼠标离开 Banner 区域
- **THEN** 自动滚动恢复

#### Scenario: 点击 Banner 打开链接
- **WHEN** 用户点击当前显示的 Banner
- **THEN** 系统在默认浏览器中打开该 Banner 的链接 URL

#### Scenario: 单 Banner 不自动滚动
- **WHEN** 主页只有一个 Banner
- **THEN** 系统不启动自动滚动定时器，不显示页码指示器

### Requirement: 页码指示器
系统 SHALL 在 Banner 底部显示页码指示器圆点。

#### Scenario: 页码同步
- **WHEN** Banner 切换到新页面
- **THEN** 页码指示器的当前页高亮更新
