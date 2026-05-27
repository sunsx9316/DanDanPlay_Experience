## ADDED Requirements

### Requirement: 基类焦点动画
所有 UICollectionViewCell 和 UITableViewCell 的 tvOS 基类 SHALL 实现统一的焦点动画。

#### Scenario: CollectionViewCell 获得焦点
- **WHEN** 一个继承自 tvOS 基类的 CollectionViewCell 获得焦点
- **THEN** cell 在 0.2s 内缩放至 1.05x
- **AND** 添加系统外观的阴影效果

#### Scenario: CollectionViewCell 失去焦点
- **WHEN** 焦点从一个 CollectionViewCell 移开
- **THEN** cell 在 0.2s 内恢复原始大小和阴影

#### Scenario: TableViewCell 获得焦点
- **WHEN** 一个继承自 tvOS 基类的 TableViewCell 获得焦点
- **THEN** cell 背景色变为高亮色
- **AND** cell 内文字颜色变为白色

### Requirement: 焦点更新协调
所有 tvOS ViewController SHALL 正确实现 preferredFocusEnvironments，声明默认焦点视图。

#### Scenario: 页面首次加载焦点设置
- **WHEN** 一个页面首次加载完成
- **THEN** 焦点自动落在 preferredFocusEnvironments 返回的视图上

#### Scenario: 返回上级页面时恢复焦点
- **WHEN** 用户从子页面返回到上级页面
- **THEN** 焦点恢复到离开时的位置

### Requirement: 焦点引导布局
UICollectionView 的布局 SHALL 配置正确的焦点移动方向，避免焦点卡住。

#### Scenario: 焦点在网格中自由移动
- **WHEN** 用户在一个 3 列网格中移动焦点
- **THEN** 焦点可以在上下左右四个方向自由移动
- **AND** 焦点不会跳到非预期的 cell

### Requirement: 焦点循环
列表和网格的焦点移动 SHALL 支持可配置的边界行为（循环或停留）。

#### Scenario: 列表底部焦点下移
- **WHEN** 焦点在列表最后一项且用户继续向下移动
- **THEN** 焦点不移动（停留在最后一项）或根据配置循环到第一项

### Requirement: 不可聚焦元素
非交互元素（UILabel、UIImageView 装饰图等）SHALL 不参与焦点系统。

#### Scenario: 装饰元素不可聚焦
- **WHEN** 用户移动焦点
- **THEN** 非交互的装饰性元素永远不会获得焦点
