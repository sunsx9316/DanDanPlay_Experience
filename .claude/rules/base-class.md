# 基类派生规范

applyTo: "**/*.swift"

## 概述

项目中所有 `UIViewController` 和 `UIView` 子类必须从项目提供的基类派生，以确保统一的行为和样式管理。

## 基类位置

```
iOS/AniXPlayer/Vendor/Base/
├── ViewController/
│   └── ViewController.swift      # ViewController 基类
└── View/
    ├── Button.swift               # Button 基类
    ├── Label.swift                # Label 基类
    ├── TableView.swift            # TableView 基类
    ├── TableViewCell/             # TableViewCell 相关
    ├── CollectionView.swift       # CollectionView 基类
    ├── CollectionViewCell.swift   # CollectionViewCell 基类
    └── ...
```

## ViewController 派生规则

所有 ViewController 必须继承自 `ViewController`（项目基类）：

```swift
// 推荐
class HomeViewController: ViewController {
    // ...
}

// 不推荐
class HomeViewController: UIViewController {
    // ...
}
```

**ViewController 基类特性：**
- 自动设置背景色为 `.backgroundColor`
- 配置导航栏返回按钮（点击返回根控制器）
- 提供 deinit 调试打印

## View 派生规则

根据视图类型使用对应的基类：

### iOS

| 视图类型 | 基类 | 文件位置 |
|---------|------|---------|
| UIButton | Button | `Vendor/Base/View/Button.swift` |
| UILabel | Label | `Vendor/Base/View/Label.swift` |
| UITableView | TableView | `Vendor/Base/View/TableView.swift` |
| UITableViewCell | TableViewCell 相关 | `Vendor/Base/View/TableViewCell/*.swift` |
| UICollectionView | CollectionView | `Vendor/Base/View/CollectionView.swift` |
| UICollectionViewCell | CollectionViewCell | `Vendor/Base/View/CollectionViewCell.swift` |
| UITextField | TextField | `Vendor/Base/View/TextField.swift` |
| RefreshHeader | RefreshHeader | `Vendor/Base/View/RefreshHeader.swift` |

### Mac

| 视图类型 | 基类 | 文件位置 |
|---------|------|---------|
| NSButton | Button | `Base/View/Button.swift` |
| NSTextField (label) | Label | `Base/View/Label.swift` |
| NSTextField (input) | TextField | `Base/View/TextField.swift` |
| NSTableView | TableView | `Base/View/TableView.swift` |
| NSOutlineView | OutlineView | `Base/View/OutlineView.swift` |
| NSImageView | ImageView | `Base/View/ImageView.swift` |

```swift
// 推荐
class PlayButton: Button {
    // ...
}

// 推荐
class TitleLabel: Label {
    // ...
}

// 不推荐
class PlayButton: UIButton {
    // ...
}
```

## 已有基类一览

### ViewController

- `ViewController` → `UIViewController`

### View

- `Button` → `UIButton`
- `Label` → `UILabel`
- `TextField` → `UITextField`
- `TableView` → `UITableView`
- `CollectionView` → `UICollectionView`
- `CollectionViewCell` → `UICollectionViewCell`
- `RefreshHeader` → `MJRefreshHeader`

### TableViewCell（位于 `TableViewCell/` 目录）

- `TableViewCell` → `UITableViewCell`
- `TitleTableViewCell` → `TableViewCell`
- `TitleDetailTableViewCell` → `TableViewCell`
- `TitleMoreTableViewCell` → `TableViewCell`
- `SwitchTableViewCell` → `TableViewCell`
- `SwitchDetailTableViewCell` → `TableViewCell`
- `EditableTableViewCell` → `TableViewCell`
- `SheetTableViewCell` → `TableViewCell`
- `StepTableViewCell` → `TableViewCell`
- `SliderTableViewCell` → `TableViewCell`
- `TitleDetailMoreTableViewCell` → `TableViewCell`
- `TitleDetailOpertationTableViewCell` → `TableViewCell`

### Mac View（位于 `Mac/AniXPlayer/Base/View/`）

- `Button` → `NSButton`
- `Label` → `NSTextField`
- `TextField` → `NSTextField`
- `TableView` → `NSTableView`
- `OutlineView` → `NSOutlineView`
- `ImageView` → `NSImageView`
- `TitleTableViewHeaderFooterView` → `UITableViewHeaderFooterView`

## 为什么必须使用基类

1. **统一样式**：背景色、字体等全局样式统一管理
2. **调试便利**：基类提供统一的 deinit 打印，便于排查内存问题
3. **功能复用**：导航栏配置等公共逻辑只需实现一次
4. **便于扩展**：后续新增全局特性只需修改基类

## 新增基类

如果现有基类不满足需求，可在对应分类目录下新增：

```
Vendor/Base/View/
    └── NewComponent.swift    # 新增基类

Vendor/Base/ViewController/
    └── NewViewController.swift
```

新增后更新本文档的「已有基类一览」部分。
