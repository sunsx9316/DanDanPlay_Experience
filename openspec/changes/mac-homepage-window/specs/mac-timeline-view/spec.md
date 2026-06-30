## ADDED Requirements

### Requirement: 星期 SegmentBar 切换
系统 SHALL 在时间表页面顶部展示星期选择栏，支持点击切换查看不同星期的新番。

#### Scenario: 显示星期选项
- **WHEN** 时间表数据加载完成
- **THEN** SegmentBar 显示有数据的星期（周日~周六），当前星期默认选中

#### Scenario: 点击切换星期
- **WHEN** 用户点击某个星期按钮
- **THEN** NSCollectionView 刷新为该星期的新番列表，SegmentBar 指示器动画移动到选中项

### Requirement: 新番列表展示
系统 SHALL 使用 NSCollectionView 展示当前选中星期的新番列表。

#### Scenario: 列表项展示
- **WHEN** 新番数据加载完成
- **THEN** 每个 item 显示：封面图、标题、评分、放送状态

#### Scenario: 点击番剧
- **WHEN** 用户点击某个番剧 item
- **THEN** 系统 push 到该番剧的 `BangumiDetailViewController`

### Requirement: 番剧关注/取关
系统 SHALL 支持在时间表列表中直接关注或取消关注番剧。

#### Scenario: 关注番剧
- **WHEN** 用户点击未关注番剧的心形按钮
- **THEN** 系统调用关注 API，成功后更新按钮状态，触发主页数据刷新回调

#### Scenario: 取消关注
- **WHEN** 用户点击已关注番剧的心形按钮
- **THEN** 系统调用取关 API，成功后更新按钮状态，触发主页数据刷新回调
