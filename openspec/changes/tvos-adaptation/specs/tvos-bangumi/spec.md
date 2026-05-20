## ADDED Requirements

### Requirement: 番剧详情页
番剧详情页 SHALL 展示番剧封面、简介、集数列表，支持焦点导航。

#### Scenario: 查看番剧详情
- **WHEN** 用户从首页或搜索结果进入番剧详情
- **THEN** 展示番剧封面图、标题、简介、标签
- **AND** 焦点默认为第一个可交互元素

### Requirement: 集数列表
番剧详情页 SHALL 展示集数列表，用户可通过焦点导航选择播放。

#### Scenario: 选择剧集播放
- **WHEN** 用户聚焦一集并点击
- **THEN** 开始播放该集

#### Scenario: 集数列表焦点滚动
- **WHEN** 集数较多超出屏幕
- **THEN** 焦点移动时列表自动滚动，保持焦点项可见

### Requirement: 匹配弹幕
番剧详情页 SHALL 提供弹幕匹配功能入口。

#### Scenario: 手动匹配弹幕
- **WHEN** 用户点击匹配按钮
- **THEN** 跳转到匹配页面（MatchsViewController）

### Requirement: 番剧搜索入口
番剧详情页 SHALL 提供返回搜索或返回首页的导航方式。

#### Scenario: Menu 按钮返回
- **WHEN** 用户按 Menu 按钮
- **THEN** 返回上一页面
