## ADDED Requirements

### Requirement: 设置页面列表
设置页 SHALL 使用 UITableView 展示设置项列表，支持焦点驱动导航。

#### Scenario: 设置页展示
- **WHEN** 用户进入设置页面
- **THEN** 以列表形式展示所有设置项
- **AND** 焦点默认落在第一个设置项上

### Requirement: 设置项导航
用户 SHALL 能点击设置项进入子设置页或触发操作。

#### Scenario: 进入子设置页
- **WHEN** 用户聚焦一个有子页面的设置项并点击
- **THEN** Push 到子设置页面

#### Scenario: 开关类型设置项
- **WHEN** 用户聚焦一个开关类型的设置项
- **THEN** 通过 Click 切换开关状态

### Requirement: 无分享功能
设置页 SHALL NOT 包含分享日志功能（UIActivityViewController 在 tvOS 不可用）。

#### Scenario: 设置页无分享按钮
- **WHEN** 用户浏览设置页
- **THEN** 不显示"分享日志"按钮

### Requirement: 外观设置
设置页 SHALL 支持主题色选择、字体大小等外观设置。

#### Scenario: 选择主题色
- **WHEN** 用户进入主题色设置页
- **THEN** 展示颜色选择网格，焦点可在颜色块之间移动
- **AND** 点击颜色块即时应用

### Requirement: 播放器内核设置仅 VLC
播放器内核设置 SHALL 仅显示 VLC 选项，MPV 不可选。

#### Scenario: 播放器内核设置展示
- **WHEN** 用户进入播放器内核设置
- **THEN** 仅显示 VLC 选项
- **AND** 不显示 MPV 选项
