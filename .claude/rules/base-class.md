# 基类派生规范

applyTo: "**/*.swift"

## 概述

项目中所有 `UIViewController` / `NSViewController` 和 `UIView` / `NSView` 子类必须从项目提供的基类派生，以确保统一的行为和样式管理。

三平台各自有独立的基类目录，**实现代码时优先查找并使用对应平台的基类**。

## 基类位置

```
iOS/AniXPlayer/Vendor/Base/
├── ViewController/
│   ├── ViewController.swift         # UIViewController 基类
│   └── NavigationController.swift   # UINavigationController 基类
└── View/
    ├── Button.swift                 # UIButton 基类
    ├── Label.swift                  # UILabel 基类
    ├── TextField.swift              # UITextField 基类
    ├── TableView.swift              # UITableView 基类
    ├── TableViewCell.swift          # UITableViewCell 基类
    ├── CollectionView.swift         # UICollectionView 基类
    ├── CollectionViewCell.swift     # UICollectionViewCell 基类
    ├── RefreshHeader.swift          # MJRefreshHeader 基类
    └── TableViewCell/               # 预置 Cell 子类

tvOS/AniXPlayer/Vendor/Base/
├── ViewController/
│   ├── ViewController.swift         # UIViewController 基类
│   └── NavigationController.swift   # UINavigationController 基类
└── View/
    ├── Button.swift                 # UIButton 基类（Focus Engine）
    ├── Label.swift                  # UILabel 基类（Focus Engine）
    ├── TextField.swift              # UITextField 基类
    ├── TableView.swift              # UITableView 基类
    ├── TableViewCell.swift          # UITableViewCell 基类（Focus Engine）
    ├── CollectionView.swift         # UICollectionView 基类
    ├── CollectionViewCell.swift     # UICollectionViewCell 基类（Focus Engine）
    └── SectionHeaderView.swift      # UITableViewHeaderFooterView 基类

Mac/AniXPlayer/Base/
├── ViewController/
│   ├── ViewController.swift         # NSViewController 基类
│   ├── WindowController.swift       # NSWindowController 基类
│   ├── NavigationProtocol.swift     # Navigation 协议
│   └── NavigationWindowController.swift  # 栈式导航窗口
├── View/
│   ├── BaseView.swift               # NSView 基类
│   ├── Button.swift                 # NSButton 基类
│   ├── Label.swift                  # NSTextField(label) 基类
│   ├── TextField.swift              # NSTextField(input) 基类
│   ├── ImageView.swift              # NSImageView 基类
│   ├── ScrollView.swift             # 泛型 NSScrollView 基类
│   ├── TableView.swift              # NSTableView 基类
│   ├── CollectionViewItem.swift     # NSCollectionViewItem 基类（nib 安全初始化）
│   ├── OutlineView.swift            # NSOutlineView 基类
│   ├── ThemedTableRowView.swift     # NSTableRowView 基类（hover/选中高亮）
│   └── TableViewCell/               # 预置 Cell 子类（xib 驱动）
└── Helper/                          # NSView/NSColor/NSFont 等扩展
```

## 三平台基类完整清单

### iOS（`iOS/AniXPlayer/Vendor/Base/`）

**ViewController 层：**

| 基类 | 继承自 | 关键特性 |
|------|--------|---------|
| `ViewController` | `UIViewController` | 背景色 `.backgroundColor`、返回按钮配置、deinit 打印 |
| `NavigationController` | `UINavigationController` | 背景色 `.backgroundColor`、返回图标着色 `.navItemColor` |

**View 层：**

| 基类 | 继承自 | 关键特性 |
|------|--------|---------|
| `Button` | `UIButton` | `contentSizeEdge` 扩大点击区域、`touchAreaEdgeInsets` |
| `Label` | `UILabel` | `padding` 扩展内边距、字体 `.ddp_normal`、颜色 `.textColor` |
| `TextField` | `UITextField` | 字体 `.ddp_normal`、颜色 `.textColor` |
| `TableView` | `UITableView` | 背景色 `.backgroundColor`、estimated 高度归零、section header top padding 归零 |
| `TableViewCell` | `UITableViewCell` | 选中背景 `.cellHighlightColor`、背景 `.backgroundColor` |
| `CollectionView` | `UICollectionView` | 背景色 `.backgroundColor` |
| `CollectionViewCell` | `UICollectionViewCell` | 选中背景 `.cellHighlightColor`、背景 `.clear` |
| `RefreshHeader` | `MJRefreshNormalHeader` | 随机刷新文案、隐藏最后更新时间 |

**TableViewCell 预置子类（均继承 `TableViewCell`）：**

| 基类 | 用途 |
|------|------|
| `TitleTableViewCell` | icon + 标题 |
| `TitleDetailTableViewCell` | 标题 + 副标题 |
| `TitleMoreTableViewCell` | 标题 + 右箭头 |
| `TitleDetailMoreTableViewCell` | 标题 + 副标题 + 右箭头 |
| `TitleDetailOpertationTableViewCell` | 标题 + 副标题 + 操作按钮 + loading |
| `SwitchTableViewCell` | 标题 + UISwitch |
| `SwitchDetailTableViewCell` | 标题 + 副标题 + UISwitch |
| `EditableTableViewCell` | 标题 + 自定义排序拖拽 |
| `SheetTableViewCell` | 标题 + 右值 + 右箭头（ActionSheet 入口） |
| `StepTableViewCell` | 标题 + UIStepper + 值 |
| `SliderTableViewCell` | 标题 + UISlider + 多值标签 |
| `TitleTableViewHeaderFooterView` | section header，`.ddp_large` 标题 + 毛玻璃背景 |

### tvOS（`tvOS/AniXPlayer/Vendor/Base/`）

**ViewController 层：**

| 基类 | 继承自 | 关键特性 |
|------|--------|---------|
| `ViewController` | `UIViewController` | `defaultFocusView` 焦点设置、背景 `.adaptiveBackground`、deinit 打印 |
| `NavigationController` | `UINavigationController` | 背景黑色、deinit 打印 |

**View 层：**

| 基类 | 继承自 | 关键特性 |
|------|--------|---------|
| `Button` | `UIButton` | Focus Engine：聚焦缩放 1.1x + 白色阴影 + `.mainColor` 边框 |
| `Label` | `UILabel` | Focus Engine：聚焦白色文字、非聚焦浅灰 |
| `TextField` | `UITextField` | 字体 `.ddp_normal`、白色文字、自适应背景 |
| `TableView` | `UITableView` | 背景 `.adaptiveBackground`、记住上次焦点 indexPath |
| `TableViewCell` | `UITableViewCell` | 圆角 16、自适应背景；Focus Engine：聚焦 `.mainColor` 4pt 边框（不调 super） |
| `CollectionView` | `UICollectionView` | 黑色背景、记住上次焦点 indexPath |
| `CollectionViewCell` | `UICollectionViewCell` | 透明背景；Focus Engine：聚焦缩放 1.05x + 白色阴影 |
| `SectionHeaderView` | `UITableViewHeaderFooterView` | section header，粗体标题 |

### Mac（`Mac/AniXPlayer/Base/`）

**ViewController / Window 层：**

| 基类 | 继承自 | 关键特性 |
|------|--------|---------|
| `ViewController` | `NSViewController` | Nib 按类名自动加载、无 Nib 时创建 500x500 空视图、deinit 打印、`weak var navigator: NavigationWindowController?` |
| `WindowController` | `NSWindowController` | Nib 自动加载、无 Nib 时程序化创建窗口（titled/closable/resizable）、`windowWillCloseCallBack` |
| `NavigationWindowController` | `WindowController` | 栈式导航（push/pop）、NSToolbar 后退按钮、`NavigationConfiguration` 结构体；入栈自动设置 `navigator` |

**协议：**

| 协议 | 用途 |
|------|------|
| `Navigation` | `pushViewController(_:)` / `popViewController()` |

**View 层：**

| 基类 | 继承自 | 关键特性 |
|------|--------|---------|
| `BaseView` | `NSView` | 自动 `wantsLayer = true` |
| `Button` | `NSButton` | 静态工厂 `custom()` 创建无边框按钮 |
| `PopUpButton` | `NSPopUpButton` | `contentTintColor = .mainColor` |
| `TextField` | `NSTextField` | 字体 `.ddp_normal`、颜色 `.textColor` |
| `Label` | `TextField` | 叠加 `isEditable=false`、`isBordered=false`、`drawsBackground=false` |
| `TextView` | `NSTextView` | `isEditable=false`、`isSelectable=true`、透明背景、`ddp_normal`/`textColor`、零内边距、禁止水平缩放、允许垂直缩放 |
| `ImageView` | `NSImageView` | 类型标识（空子类） |
| `ScrollView<ContainerView>` | `NSScrollView` | 泛型容器视图、覆盖式滚动条 |
| `TableView` | `NSTableView` | 类型标识（空子类） |
| `CollectionViewItem` | `NSCollectionViewItem` | `init(nibName:bundle:)` 传 `nil` 避免 nib 查找，统一走 `loadView()` |
| `OutlineView` | `NSOutlineView` | 自动 `headerView=nil`、`style=.sourceList` |
| `Slider` | `NSSlider` | `trackFillColor = .mainColor` |
| `CheckBox` | `NSButton` | checkbox 类型，`contentTintColor = .mainColor` |
| `ThemedTableRowView` | `NSTableRowView` | 悬停高亮（6% `.mainColor`）、选中高亮（12%-24% `.mainColor`）+ `enableRowHoverTracking()` |

**TableViewCell 预置子类（纯代码，均继承 `NSView`）：**

| 基类 | 用途 |
|------|------|
| `TitleTableViewCell` | 单行标题 |
| `TitleDetailTableViewCell` | 标题 + 副标题 |
| `SheetTableViewCell` | 标题 + NSPopUpButton |
| `SwitchTableViewCell` | 标题 + CheckBox |
| `SwitchDetailTableViewCell` | 标题 + 副标题 + CheckBox |
| `StepTableViewCell` | 标题 + NSStepper + 值 |
| `SliderTableViewCell` | 标题 + NSSlider + 多值标签 |

## 使用规则

```swift
// 推荐 — 继承项目基类
class HomePageViewController: ViewController { }

class PlayButton: Button { }

class TitleLabel: Label { }

// 不推荐 — 直接继承系统类
class HomePageViewController: UIViewController { }

class PlayButton: UIButton { }
```

**实现新代码时的检查顺序**：

1. 先查上面表格中对应平台是否有匹配的基类
2. 有则继承基类，无则继承系统类
3. 新增基类后更新本文档

## 为什么必须使用基类

1. **统一样式**：背景色、字体等全局样式统一管理
2. **调试便利**：基类提供统一的 deinit 打印，便于排查内存问题
3. **功能复用**：导航栏配置、Focus Engine 特效等公共逻辑只需实现一次
4. **便于扩展**：后续新增全局特性只需修改基类

## 新增基类

如果现有基类不满足需求，可在对应平台目录下新增：

```
iOS/tvOS:
  Vendor/Base/View/NewComponent.swift
  Vendor/Base/ViewController/NewViewController.swift

Mac:
  Base/View/NewComponent.swift
  Base/ViewController/NewViewController.swift
```

新增后更新本文档的清单部分。
