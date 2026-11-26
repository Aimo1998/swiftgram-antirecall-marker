# Swiftgram Anti-Recall Marker

给 Swiftgram 中**已被撤回（但被防撤回保留）的消息**添加「已撤回」标记。

> 需配合防撤回插件 `SwiftgramEnhancer`（KAlert 去卡密版）使用，因为它依赖 KAlert 写入的撤回消息 ID 列表。

## 项目结构

```
SwiftgramAntiRecallMarker/
├── Tweak.x                          # 核心代码
├── Makefile                         # theos 构建配置
├── control                          # 包信息
├── SwiftgramAntiRecallMarker.plist  # 注入过滤（app.swiftgram.ios）
└── .github/workflows/build.yml      # GitHub Actions 云端编译
```

## 用 GitHub Actions 云端编译（无需 Mac）

1. 注册/登录 GitHub（免费）
2. 新建一个**公共（public）**仓库
3. 把本项目所有文件上传到仓库（或用 GitHub Desktop / git 推送）
4. 进入仓库的 **Actions** 标签页
5. 点击左侧 **Build Tweak** → 右侧 **Run workflow** → 绿色按钮运行
6. 等 5~15 分钟，构建完成后在本次运行页面底部 **Artifacts** 下载 `SwiftgramAntiRecallMarker-deb`
7. 下载的 deb 用 Sileo / Zebra / dpkg 安装，然后 `killall -9 Swiftgram`

## 手动编译（如果你有 theos）

```sh
make clean
make package
# 产物在 packages/ 目录
```

## 安装与测试

```sh
dpkg -i com.example.swiftgramantirecallmarker_1.0.0_iphoneos-arm64.deb
killall -9 SpringBoard   # respring
```

测试：发一条消息 → 撤回 → 看那条消息气泡右上角是否出现橙色「已撤回」标签。

## 真机调试（重要）

Tweak.x 里已开启调试日志（`kDebugLog = YES`），没生效时看设备控制台：

```sh
# 越狱设备上实时看日志
log stream --predicate 'subsystem == "com.apple.SpringBoard"' 2>/dev/null | grep SGRecallMark
# 或
tail -f /var/log/syslog | grep SGRecallMark
```

日志会打印两类关键信息，请反馈给我：
1. `hooking <类名>` —— 确认 hook 到了哪个类（如果没打印，说明类名都不匹配，我加更多候选）
2. `node=... msgId=...` —— 消息 ID 是否被正确提取（如果 msgId 一直是 (null)，说明 KVC 路径不对，我改路径）

**最可能需要调整的地方**：`sg_extractMessageId` 里的 KVC 路径（`item.message.id` 等），因为 Swift 属性是否 @objc 暴露要真机实测才能确定。把日志里的 `msgId` 反馈给我，我立刻改对。

## 自定义标记样式

编辑 Tweak.x 里 `sg_addMark` 函数：
- 文字：`mark.text = @"已撤回"`
- 颜色：`mark.textColor = [UIColor systemOrangeColor]`
- 位置：`mark.topAnchor` / `mark.rightAnchor`（右上角，可改成 leftAnchor 等）
