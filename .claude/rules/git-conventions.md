# Git 提交规范

遵循 [Conventional Commits](https://www.conventionalcommits.org/) 格式：

```
<type>(<scope>): <subject>

[optional body]

[optional footer(s)]
```

## 常用 type

| type | 说明 | 示例 |
|------|------|------|
| `feat` | 新功能 | `feat(player): 添加 MPV 播放器支持` |
| `fix` | 修复 bug | `fix(memory): 修复 MPVPlayerWrapper 内存泄漏` |
| `docs` | 文档更新 | `docs: 更新 README` |
| `style` | 代码格式（不影响功能） | `style: 格式化代码` |
| `refactor` | 重构（不修复问题不新功能） | `refactor(media): 抽取播放器工厂方法` |
| `perf` | 性能优化 | `perf: 优化播放列表加载` |
| `test` | 添加/修改测试 | `test: 添加播放器单元测试` |
| `chore` | 构建/工具/依赖更新 | `chore: 升级 VLCKit 到 3.6.0` |
| `opt` | 优化/小改进 | `opt: 简化日志输出` |
| `update` | 更新现有功能 | `update: 播放器内核选择UI` |

## scope（可选）

使用受影响的主要模块：

- `player` - 播放器相关
- `media` - 媒体处理
- `subtitle` - 字幕相关
- `ui` - 用户界面
- `build` - 构建相关
- `pod` - CocoaPods 依赖
- `memory` - 内存/性能相关

## 规则

1. **标题最多 72 字符**
2. **使用祈使语气**（"添加"而非"已添加"）
3. **scope 用小写**
4. **结尾不加句号**

## 提交示例

```
feat(player): 添加 MPV 播放器支持

- 实现 MPVMediaPlayerWrapper
- 添加 MPV.swift 类型安全 API
- 修复播放器内核循环引用问题

Closes #123
```

## Git Hook 自动配置

项目使用 `.githooks/` 目录管理 Git hooks，通过 Podfile 自动安装。

### 目录结构

```
DanDanPlay_Experience/
├── scripts/
│   └── install_hooks.sh      # 安装脚本
├── .githooks/
│   └── commit-msg            # 提交格式验证
├── iOS/
│   └── Podfile               # 调用安装脚本
└── Mac/
    └── Podfile
```

### 工作原理

1. `scripts/install_hooks.sh` 创建 `.git/hooks/commit-msg` 软链接
2. `Podfile post_install` 调用安装脚本
3. 用户 `pod install` 后自动生效，无需手动配置

### 验证方式

```bash
# 检查 hook 是否生效
ls -la .git/hooks/commit-msg
```
