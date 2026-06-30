## ADDED Requirements

### Requirement: 通过菜单打开主页窗口
系统 SHALL 在"功能"菜单中提供"主页"选项，点击后打开独立的主页窗口（600x800）。

#### Scenario: 首次打开主页
- **WHEN** 用户点击"功能 → 主页"菜单项，且当前无主页窗口
- **THEN** 系统创建 `HomePageNavigationWindowController`（含 Toolbar 后退/前进），展示 `HomePageViewController`，窗口居中显示

#### Scenario: 主页窗口已存在
- **WHEN** 用户点击"功能 → 主页"菜单项，且主页窗口已存在
- **THEN** 系统将该窗口置前（`makeKeyAndOrderFront`），不创建新窗口

#### Scenario: 导航栈操作
- **WHEN** 在主页子页面中点击 Toolbar "后退"按钮
- **THEN** 系统返回上一级页面（`popViewController`）
- **WHEN** 在返回后点击 Toolbar "前进"按钮
- **THEN** 系统前进到之前浏览的页面

### Requirement: 主页 Banner 轮播
系统 SHALL 在主页顶部展示 Banner 轮播区，支持自动滚动和手动浏览。

#### Scenario: Banner 自动滚动
- **WHEN** 主页加载完成且有多个 Banner
- **THEN** 系统每 8 秒自动切换到下一张 Banner，并更新页码指示器

#### Scenario: 鼠标悬停暂停
- **WHEN** 鼠标进入 Banner 区域
- **THEN** 自动滚动暂停
- **WHEN** 鼠标离开 Banner 区域
- **THEN** 自动滚动恢复

#### Scenario: 点击 Banner
- **WHEN** 用户点击当前显示的 Banner
- **THEN** 系统在默认浏览器中打开该 Banner 的链接 URL
