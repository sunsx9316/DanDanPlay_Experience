## ADDED Requirements

### Requirement: 播放器基本播放控制
播放器 SHALL 支持通过 Siri Remote 物理按钮控制播放/暂停。

#### Scenario: Click 按钮播放/暂停
- **WHEN** 用户按下 Siri Remote 的 Click（Select）按钮
- **THEN** 视频在播放和暂停状态之间切换

#### Scenario: Play/Pause 按钮播放/暂停
- **WHEN** 用户按下 Siri Remote 的 Play/Pause 按钮
- **THEN** 视频在播放和暂停状态之间切换

### Requirement: 播放器 Seek 控制
播放器 SHALL 支持通过 Siri Remote 触控板左右滑动进行进度 seek。

#### Scenario: 触控板右滑快进
- **WHEN** 用户在 Siri Remote 触控板上向右滑动
- **THEN** 视频进度向前跳转 10 秒

#### Scenario: 触控板左滑后退
- **WHEN** 用户在 Siri Remote 触控板上向左滑动
- **THEN** 视频进度向后跳转 10 秒

### Requirement: Seek 步长多档切换
播放器 SHALL 提供多档 seek 步长（10s / 30s / 60s），用户可切换。

#### Scenario: 切换 seek 步长
- **WHEN** 用户通过播放器设置切换 seek 步长
- **THEN** 后续 seek 操作使用新步长

### Requirement: 播放控制栏
播放器 SHALL 提供焦点驱动的播放控制栏，包含播放/暂停、快退、快进、设置、弹幕列表、弹幕开关按钮。

#### Scenario: 显示控制栏
- **WHEN** 用户在播放期间按下 Menu 按钮或轻触触控板
- **THEN** 控制栏在视频底部显示
- **AND** 默认焦点落在播放/暂停按钮上

#### Scenario: 焦点在控制按钮间移动
- **WHEN** 控制栏可见且用户按方向键左右
- **THEN** 焦点在按钮之间移动

#### Scenario: 控制栏自动隐藏
- **WHEN** 控制栏可见且用户 5 秒无操作
- **THEN** 控制栏自动隐藏

### Requirement: 播放器设置面板
播放器 SHALL 提供设置面板，以 TableView 列表形式展示设置项（播放内核、字幕、音轨、画面比例、弹幕设置等）。

#### Scenario: 打开设置面板
- **WHEN** 用户聚焦控制栏"设置"按钮并点击
- **THEN** 弹出全屏设置面板，展示设置项列表

#### Scenario: 导航设置项
- **WHEN** 设置面板打开且用户上下滑动
- **THEN** 焦点在设置项之间移动

#### Scenario: 选择设置项
- **WHEN** 用户聚焦一个设置项并点击
- **THEN** 进入对应的子设置页面

### Requirement: 长按倍速菜单
播放器 SHALL 支持长按 Siri Remote Click 按钮弹出倍速选择菜单。

#### Scenario: 长按弹出倍速菜单
- **WHEN** 用户长按 Click 按钮 1 秒
- **THEN** 弹出倍速选择菜单（1x, 1.5x, 2x, 4x）
- **AND** 用户可聚焦选择一个倍速

### Requirement: 弹幕显示
播放器 SHALL 在视频上叠加显示弹幕，使用与 iOS 相同的弹幕渲染引擎。

#### Scenario: 弹幕正常显示
- **WHEN** 播放有弹幕的视频
- **THEN** 弹幕在视频上方滚动显示
- **AND** 同屏弹幕数量不超过 tvOS 性能上限（默认 50 条）

### Requirement: Menu 按钮退出播放器
按下 Menu 按钮 SHALL 退出播放器，返回上一页面。

#### Scenario: Menu 按钮退出
- **WHEN** 用户在播放器页面按下 Menu 按钮
- **THEN** 播放器关闭，返回之前的页面

### Requirement: 播放器仅支持 VLC 内核
tvOS 播放器 SHALL 仅使用 VLC 播放内核，不支持 MPV。

#### Scenario: 播放内核固定为 VLC
- **WHEN** 检查播放器内核设置
- **THEN** 仅 VLC 可用，MPV 选项被隐藏
