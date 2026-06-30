## ADDED Requirements

### Requirement: 关注列表展示
系统 SHALL 使用 NSCollectionView 展示用户关注的番剧列表。

#### Scenario: 列表项展示
- **WHEN** 关注数据加载完成
- **THEN** 每个 item 显示：封面图、标题、评分、放送状态、最后观看时间

#### Scenario: 点击番剧
- **WHEN** 用户点击某个关注番剧 item
- **THEN** 系统 push 到该番剧的 `BangumiDetailViewController`

### Requirement: 未登录状态提示
系统 SHALL 在用户未登录时提示需要登录。

#### Scenario: 未登录时展示提示
- **WHEN** 用户未登录且进入关注页面
- **THEN** 页面显示"请先登录"提示，不发起网络请求

#### Scenario: 登录后自动刷新
- **WHEN** 用户登录后返回关注页面
- **THEN** 页面自动发起请求获取关注列表

### Requirement: 取消关注
系统 SHALL 支持在关注列表中取消关注番剧。

#### Scenario: 取消关注
- **WHEN** 用户点击已关注番剧的心形按钮
- **THEN** 系统调用取关 API，成功后从列表中移除该 item
