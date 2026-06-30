## ADDED Requirements

### Requirement: 番剧详情多 section 展示
系统 SHALL 使用 NSCollectionView 以多 section 形式展示番剧详情。

#### Scenario: 信息头 section
- **WHEN** 番剧详情加载完成
- **THEN** 顶部 section 显示：封面大图、标题、评分、标签、关注按钮

#### Scenario: 剧集列表 section
- **WHEN** 番剧有剧集数据
- **THEN** 显示"剧集"入口，点击 push 到 `BangumiDetailEpisodeViewController`（NSTableView）

#### Scenario: 相关番剧 section
- **WHEN** 番剧有相关番剧数据
- **THEN** 以横向 NSCollectionView 展示相关番剧封面列表，点击 push 到对应 `BangumiDetailViewController`

#### Scenario: 相似番剧 section
- **WHEN** 番剧有相似番剧数据
- **THEN** 以横向 NSCollectionView 展示相似番剧封面列表，点击 push 到对应 `BangumiDetailViewController`

#### Scenario: 无数据 section 隐藏
- **WHEN** 相关番剧或相似番剧数据为空
- **THEN** 对应 section 不显示

### Requirement: 番剧元数据查看
系统 SHALL 支持查看番剧的完整元数据。

#### Scenario: 打开元数据
- **WHEN** 用户点击番剧信息头中的元数据入口
- **THEN** 系统 push 到 `BangumiDetailMetadataViewController`（NSTableView）

### Requirement: 剧集列表查看
系统 SHALL 支持查看番剧的剧集列表。

#### Scenario: 打开剧集列表
- **WHEN** 用户点击剧集入口
- **THEN** 系统 push 到 `BangumiDetailEpisodeViewController`，展示每集的标题和发布时间
