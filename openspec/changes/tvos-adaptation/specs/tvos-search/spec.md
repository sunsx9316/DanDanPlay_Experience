## ADDED Requirements

### Requirement: 搜索页面
搜索页面 SHALL 使用 UISearchContainerViewController 提供搜索功能，支持焦点导航。

#### Scenario: 搜索弹幕资源
- **WHEN** 用户在搜索框输入关键词并确认
- **THEN** 显示搜索结果列表
- **AND** 焦点自动移到第一个搜索结果上

### Requirement: 搜索结果列表
搜索结果 SHALL 以 UITableView 展示，每个结果项支持焦点聚焦。

#### Scenario: 搜索结果焦点导航
- **WHEN** 搜索结果列表展示
- **THEN** 用户可上下滑动切换焦点到不同结果项

#### Scenario: 选择搜索结果
- **WHEN** 用户聚焦一个搜索结果并点击
- **THEN** 跳转到番剧详情页

### Requirement: 搜索框焦点管理
搜索框 SHALL 正确参与焦点系统，支持焦点的进入和退出。

#### Scenario: 焦点进入搜索框
- **WHEN** 用户将焦点移动到搜索框
- **THEN** 搜索框获得焦点，激活文本输入（唤起系统键盘或等待 Siri Remote 听写）

#### Scenario: 焦点离开搜索框
- **WHEN** 用户按 Menu 或向下移动焦点
- **THEN** 搜索框失去焦点，焦点移到搜索结果列表
