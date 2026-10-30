# Customize Finder Icon

[English](README.md) · [简体中文](README.zh-CN.md)

一个精简的 Codex 技能：根据 Finder 图标参考图和文字描述生成自定义图标，预览并确认后，在本地替换 macOS 文件或文件夹图标，同时备份原图标，便于恢复。

**参考图 → 选择方向 → 生图 → 确认 → 替换。** 无需安装第三方换装应用。

## 工作方式

1. 使用你提供的参考图，或提取目标当前的 Finder 图标。
2. 没有明确风格时，先提供 **3 个文字方向**，简述造型、材质和配色，等你选择后才生图。已有明确偏好，或明确说“你决定”时，直接继续。
3. 使用 Codex 内置生图工具生成一张透明图片。默认采用**正面视角、清晰的文件夹轮廓、左上标签、透明背景、四周留白、无文字**；普通文件则沿用参考图的文件轮廓。
4. 展示成品并按反馈修改。选择设计方向，不等于授权替换实际图标。
5. 你确认成品和目标路径后，Swift 脚本备份原图标、调用 `NSWorkspace.setIcon` 并检查自定义图标标记；Codex 再提取应用后的图标检查效果。

遵循奥卡姆剃刀原则：一张参考图、一段描述、一张成品、一次确认后的替换。

## 环境要求

- macOS，具有 AppKit 和可用的 Swift 工具链（用 `xcrun --find swift` 检查）。
- Codex 环境提供内置 `image_gen` 生图工具。工具是否可用取决于运行环境，本仓库不提供生图服务。
- 对目标文件或文件夹具有写入权限。

图标脚本无需 Python 依赖、API Key 或网络连接。**生图不是离线操作**，使用 Codex 的图片服务；本流程不要求另配 API Key，但仍受现有 Codex 访问权限及用量限制约束。内置工具不可用时，不应擅自切换到付费 API 或其他模型。

## 安装

克隆到个人 Codex 技能目录。若目标目录已存在，先检查内容，不要直接覆盖。

```sh
mkdir -p "${CODEX_HOME:-$HOME/.codex}/skills"
git clone https://github.com/liaocaoxuezhe/Customize-Finder-Icon.git \
  "${CODEX_HOME:-$HOME/.codex}/skills/finder-icon"
```

如果未立即显示，可新开一个 Codex 对话。技能名称为 **`finder-icon`**，与仓库名称不同。技能指令目前使用中文，项目默认 README 为英文。

## 在 Codex 中使用

```text
用 $finder-icon 给 /absolute/path/to/My Folder 设计图标。
我还没有风格偏好，先给我几个文字方向，选定后再生图，确认成品后再替换。
```

也可以明确指定方向：

```text
用 $finder-icon 给 /absolute/path/to/My Folder 制作黄色乐高积木风格的
文件夹图标，正面视角、透明背景。先展示成品，等我确认后再替换。
```

支持提供自己的参考图。生成图片与备份应放在仓库之外；备份清单会记录目标的绝对路径。

## 直接使用脚本

在仓库根目录执行，将示例路径替换为完整绝对路径。**直接调用 CLI 会立即执行**；确认步骤由 Codex 技能负责，脚本本身不弹出确认提示。

```sh
# 导出 Finder 当前外观为 1024 × 1024 透明 PNG。
# 输出的父目录必须存在；不会覆盖同名文件。
swift scripts/finder_icon.swift reference \
  "/absolute/path/to/My Folder" "/absolute/path/to/reference.png"

# 备份并替换。备份目录必须是目标之外的新目录，且父目录已存在。
swift scripts/finder_icon.swift set \
  "/absolute/path/to/My Folder" "/absolute/path/to/icon.png" \
  "/absolute/path/to/backups/change-001"

# 恢复到该次备份保存的外观。
swift scripts/finder_icon.swift restore \
  "/absolute/path/to/My Folder" "/absolute/path/to/backups/change-001"
```

推荐真正带透明通道的 PNG，也接受 macOS 能解码的图片。脚本拒绝符号链接目标和 `.app` 等包目录；只更改图标，不修改文件内容。

备份包含 `state.json`，原先存在自定义图标时还包含 `previous.tiff`。恢复时会还原自定义外观，或在原先使用系统默认图标时移除自定义图标。备份是外观快照，**不是原始资源分支的逐字节归档**。恢复要求目标仍位于记录的路径。写入失败时保留备份，不使用 `sudo` 或手工删除元数据强行处理。

## 测试

在 macOS 上用 Python 3.9+ 运行，测试仅使用标准库：

```sh
python3 test/test_roundtrip.py
```

测试编译 Swift 工具、自行生成 PNG，并在 `test/` 内创建临时目标。覆盖文件与文件夹、中文路径、自定义与默认图标恢复、内容保留及无效输入拒绝。不调用生图服务，不修改真实工作目录。

## 隐私与提交内容

仓库只包含技能、Swift 源码、文档和测试。不要提交 API Key、`.env`、个人图片、备份或个人路径。`.gitignore` 排除常见本地产物，但不能替代提交前检查。提供给生图工具的参考图由当前 Codex 图片服务处理；本地 Swift 脚本不发送网络请求。

## 许可证

[MIT](LICENSE)。许可证适用于本仓库代码和文档，不覆盖第三方素材、商标或用户提供的参考图。本项目独立开发，并非 Apple 或 OpenAI 官方产品。
