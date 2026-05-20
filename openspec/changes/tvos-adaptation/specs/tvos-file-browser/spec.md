## ADDED Requirements

### Requirement: 文件浏览列表
文件浏览器 SHALL 使用 UITableView 展示文件列表，支持焦点驱动的上下导航。

#### Scenario: 浏览文件列表
- **WHEN** 用户进入文件浏览器
- **THEN** 展示当前目录的文件和子目录列表
- **AND** 焦点默认在第一项上

#### Scenario: 焦点上下移动
- **WHEN** 用户在文件列表中上下滑动 Siri Remote 触控板
- **THEN** 焦点在列表项之间上下移动

### Requirement: 进入子目录
用户 SHALL 能通过点击进入子目录。

#### Scenario: 进入子目录
- **WHEN** 用户聚焦一个目录项并点击
- **THEN** Push 到该目录的文件列表页面

### Requirement: 播放文件
用户 SHALL 能通过点击视频文件直接开始播放。

#### Scenario: 播放视频文件
- **WHEN** 用户聚焦一个视频文件并点击
- **THEN** 跳转到播放器页面开始播放该视频

### Requirement: 多文件源支持
文件浏览器 SHALL 支持本地文件、SMB、FTP、WebDAV 四种文件源。

#### Scenario: 切换文件源
- **WHEN** 用户在文件浏览界面选择不同的文件源
- **THEN** 展示对应协议的文件列表

### Requirement: 无 QR 码扫描功能
文件浏览器 SHALL NOT 包含 QR 码扫描或 PC 登录功能（tvOS 无摄像头）。

#### Scenario: 文件源选项中无 QR 相关入口
- **WHEN** 用户查看文件源选项
- **THEN** 不显示二维码扫描或 PC 登录按钮

### Requirement: 文件列表焦点动画
文件列表项获得焦点时 SHALL 展示视觉反馈（背景色高亮、文字颜色变化）。

#### Scenario: 文件项焦点获得
- **WHEN** 用户将焦点移动到一个文件项上
- **THEN** 该文件项背景色变为高亮色，文字颜色反色
- **AND** 列表自动滚动使该项完全可见
