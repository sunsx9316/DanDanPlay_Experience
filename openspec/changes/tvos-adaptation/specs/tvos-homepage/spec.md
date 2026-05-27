## ADDED Requirements

### Requirement: 首页焦点驱动网格布局
首页 SHALL 使用 UICollectionView 展示功能入口，支持焦点导航。

#### Scenario: 首页展示功能入口
- **WHEN** 用户打开应用
- **THEN** 首页以网格布局展示功能入口（继续播放、番剧、文件浏览、搜索等）
- **AND** 默认焦点落在第一个功能入口上

#### Scenario: 焦点在入口间移动
- **WHEN** 用户使用 Siri Remote 触控板上下左右滑动
- **THEN** 焦点在网格中的入口之间移动，移动方向与用户输入一致

### Requirement: 继续播放区域
首页 SHALL 展示"继续播放"区域，显示最近播放的番剧列表，支持焦点导航。

#### Scenario: 点击继续播放项
- **WHEN** 用户在"继续播放"区域聚焦到一个番剧并点击
- **THEN** 跳转到播放器页面，从上次播放位置继续

### Requirement: 番剧时间表入口
首页 SHALL 提供番剧时间表（Timeline）入口，展示每日更新的番剧列表。

#### Scenario: 进入时间表
- **WHEN** 用户聚焦点击时间表入口
- **THEN** 跳转到番剧时间表页面（TimelineViewController）

### Requirement: 收藏入口
首页 SHALL 提供收藏夹入口，展示用户关注的番剧列表。

#### Scenario: 进入收藏夹
- **WHEN** 用户聚焦点击收藏入口
- **THEN** 跳转到收藏页面（FavoriteViewController）

### Requirement: 首页焦点动画
首页入口项获得焦点时 SHALL 展示视觉反馈（缩放至 1.05x、添加阴影、标题浮起）。

#### Scenario: 焦点获得动画
- **WHEN** 用户将焦点移动到一个功能入口上
- **THEN** 该入口执行 0.2s 缩放动画至 1.05x
- **AND** 显示阴影效果
- **AND** 焦点离开后恢复原始状态
