## 项目现状与基线
- 现有代码：SwiftUI+SwiftData 模板，单目标 App。
  - 数据模型仅 `Item(timestamp: Date)`，SwiftData 已配置：`iCost/iCost/iCostApp.swift:13–23` 与 `iCost/iCost/ContentView.swift:11–14`、`iCost/iCost/Item.swift:11–18`。
- 配置：最低版本 `iOS 18.0`（`iCost.xcodeproj/project.pbxproj:253,310`），Swift 版本为 `5.0`（`iCost.xcodeproj/project.pbxproj:166,196`）。
- 能力：`CloudKit` 已在 `entitlements` 开启但未配置容器（`iCost/iCost/iCost.entitlements:7–12`）。`Info.plist` 开启远程通知后台（`iCost/iCost/Info.plist:5–8`）。

## 总体架构（MVVM）
- 模块划分：
  - `Voice`（录音、波形、语音识别）
  - `Networking`（Alamofire 常规调用；`URLSession` 后台上传）
  - `Persistence`（SwiftData 模型/查询）、`Encryption`（CryptoKit+Keychain）
  - `Sync`（SwiftData ↔ CloudKit 同步与冲突处理）
  - `Calendar`（月视图+每日总额）、`Charts`（趋势折线+类别饼图）
  - `Auth`（Face ID/Touch ID）、`Widget`（今日消费）、`Theme`（暗黑/明亮）
- 目录建议：`Models/ ViewModels/ Views/ Services/ Utils/ Widgets/ Resources/ Tests/ UITests/ PerformanceTests/`。

## 数据模型设计（SwiftData）
- `Bill`：`id(UUID)·amount(Decimal)·category(Category)·timestamp(Date)·note(String?)·audioURL(URL?)·transcript(String?)·syncStatus(SyncStatus)·updatedAt(Date)·isDeleted(Bool)`。
- `Category`：枚举（餐饮、交通、娱乐、购物、日用、医疗、教育、其他），支持自定义映射表。
- 索引与约束：为 `timestamp`、`category` 建索引；`updatedAt` 驱动同步策略。
- 迁移：移除 `Item`，迁移到 `Bill`；保留 `ModelContainer`，追加 `.cloudKit` 配置。

## 语音账单记录（UI/录音/识别）
- 录音界面：录音按钮、状态指示（就绪/录制中/处理/失败）、倒计时 60s。
- 录制：`AVAudioEngine`+`AVAudioSession`，`installTap` 获取缓冲绘制波形；启用 `isMeteringEnabled` 或能量值采样。
- 时长限制：`Timer`/`Task.sleep` 控制 60s 自动停止。
- 识别：`Speech`（`SFSpeechRecognizer`）本地/在线识别，权限申请与错误处理；将文本解析为金额/类别/备注（正则与 NLP 规则）。
- 无障碍：语音状态的 VoiceOver 提示；录音波形提供视觉反馈。

## 异步语音处理（并发与后台传输）
- 并发：采用 `Swift Concurrency`（`async/await`）+ `OperationQueue` 对上传/解析排队执行。
- 进度指示：使用 `URLSessionTaskDelegate` 报告 `uploadProgress`，UI 绑定到 `ViewModel` 进度。
- 后台传输：`URLSessionConfiguration.background(withIdentifier:)` 专用于音频文件上传；完成回调通过 `AppDelegate` 的 `handleEventsForBackgroundURLSession`。
- 自动重试：最多 3 次，指数退避（500ms、2s、5s），对 `5xx/网络错误` 生效；显式停止在 `4xx`。
- Alamofire 使用：非后台请求（如拉取分类、统计）通过 `Session` 管理；后台上传走原生 `URLSession`，两者统一由 `NetworkingService` 抽象。

## 数据持久化与加密
- 持久化：SwiftData 存储 `Bill`；音频文件存储于 `Application Support/Audio/`。
- 加密：
  - 音频与敏感备注使用 `CryptoKit.AES.GCM` 加密。
  - 密钥管理：`Keychain` 存储对称密钥（随机生成，旋转策略可选）。
  - 读写层封装：`EncryptedFileStore`（透明加解密），SwiftData 仅保存加密后的文件路径与元数据。

## iCloud 同步与冲突解决
- SwiftData+CloudKit：`ModelContainer` 使用 `.cloudKit(.private)`，启用自动同步。
- 冲突策略：基于 `updatedAt` 的 LWW（Last-Write-Wins），并保留冲突副本到 `BillConflict` 表以供审计与回滚。
- 失败恢复：记录 `syncStatus = .pending/.failed/.synced`，后台重试与用户手动触发。
- 容器配置：为 `iCost` 配置私有容器 ID，`entitlements` 更新。

## 日历界面（月视图）
- UI：自定义月历（`LazyVGrid` 7×5/6），顶部月份标题，左右滑动手势切换月份。
- 数据：按日聚合 `sum(amount)`，显示每日总额；点击进入当日明细（列表）。
- 性能：使用 `@Query` 带谓词按当前月份范围过滤，避免全表扫描。

## 数据可视化（Charts）
- 趋势折线：`Charts` 的 `LineMark`，支持周/月/年时间范围切换。
- 类别饼图：使用 `SectorMark`（iOS 17+）展示各类别占比；支持选择高亮与图例。
- 导出：`ImageRenderer` 将图表视图输出为 PNG；利用 `PDFKit`/`UIGraphicsPDFRenderer` 输出为 PDF；支持分享与文件保存。

## 其他要求实现
- 暗黑/明亮：SwiftUI 动态适配，颜色集支持两套外观；图表与日历遵循系统外观与对比度。
- Face ID/Touch ID：`LocalAuthentication.LAContext` 进行解锁，失败提供 PIN 备用；应用进入前台时二次校验可选。
- Widget：`WidgetKit` 展示今日消费总额；数据共享通过 `App Groups` 的共享存储或轻量快照；时间线策略每小时刷新与重要事件推送。
- App Store 审核：完善 `Info.plist` 隐私权限说明（麦克风、语音识别、Face ID、网络等），不收集非必要数据；离线可用。

## 网络与接口（示例 API）
- 上传音频：`POST /api/v1/voice/upload`（`multipart/form-data`：`file`、`duration`、`locale`）→ 返回 `transcript`、`confidence`、`entities`（`amount`、`category`、`note`）。
- 同步账单：`POST /api/v1