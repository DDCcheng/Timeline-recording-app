# 个人时间线笔记 — 设计文档

**日期：** 2026-03-17
**平台：** iOS 17+
**技术栈：** SwiftUI + SwiftData
**定位：** 纯个人使用，本地存储，无账户系统

---

## 1. 产品概述

类 X/Twitter 的个人时间线笔记应用。用户发布带图片和标签的笔记，按时间线倒序浏览。极简黑白风格，支持深色/浅色模式，纯本地存储，支持导出。

---

## 2. 核心功能

- **发布笔记**：Markdown 正文 + 最多4张图片 + 任意标签
- **时间线**：倒序列表，标签横向筛选栏，下拉搜索
- **搜索**：全文搜索 + 日期范围筛选 + 标签多选过滤
- **编辑**：编辑前自动保存历史快照，可查看历史版本
- **删除**：支持删除笔记（同步清理图片文件）
- **导出**：全部或当前筛选结果导出为 JSON 或 Markdown+图片 zip
- **外观**：跟随系统 / 强制深色 / 强制浅色（`@AppStorage` 持久化，`.preferredColorScheme` 注入根视图）

---

## 3. 数据模型（SwiftData）

### Note
```swift
@Model class Note {
    var id: UUID = UUID()
    var content: String = ""         // Markdown 格式正文
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    @Relationship(deleteRule: .cascade) var images: [NoteImage] = []
    @Relationship var tags: [Tag] = []
    @Relationship(deleteRule: .cascade) var editHistory: [EditRecord] = []

    init(content: String = "") {
        self.id = UUID()
        self.content = content
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
```

### NoteImage
```swift
@Model class NoteImage {
    var id: UUID = UUID()
    // fileName = "<id>.jpg"，完整路径为 Documents/images/<noteID>/<id>.jpg
    var order: Int = 0
    var createdAt: Date = Date()
    @Relationship(inverse: \Note.images) var note: Note?  // 显式声明反向引用

    init(order: Int) {
        self.id = UUID()
        self.order = order
        self.createdAt = Date()
    }

    var fileName: String { "\(id.uuidString).jpg" }
}
```

### Tag
```swift
@Model class Tag {
    @Attribute(.unique) var name: String   // 唯一约束，防止重复插入
    var createdAt: Date = Date()
    @Relationship(inverse: \Note.tags) var notes: [Note] = []

    init(name: String) {
        self.name = name
        self.createdAt = Date()
    }
}
```

### EditRecord
```swift
@Model class EditRecord {
    var id: UUID = UUID()
    var content: String = ""       // 历史版本 Markdown 内容
    var editedAt: Date = Date()
    var noteID: UUID               // 存储父 Note.id，供 #Predicate 过滤（避免可选链不支持问题）

    init(content: String, noteID: UUID) {
        self.id = UUID()
        self.content = content
        self.editedAt = Date()
        self.noteID = noteID
    }
}
```

**图片文件路径规则：** `Documents/images/<noteID>/<imageID>.jpg`
- `imageID` 即 `NoteImage.id.uuidString`，`fileName` 属性由 id 派生，不单独存储
- 图片压缩：JPEG quality 0.8，单张不超过 2MB
- 删除联动：笔记删除时 `cascade` 删除 `NoteImage` 记录，同时调用 `ImageStorageService.deleteImages(for: noteID)` 清理磁盘目录

**孤立标签清理：** 笔记删除后检查其关联 `Tag`，若 `tag.notes.isEmpty` 则一并删除该 Tag，保持自动补全列表干净。

---

## 4. 应用结构与导航

```
NavigationStack
└── TimelineView（唯一主界面）
    ├── .searchable → 触发 SearchOverlayView（见下）
    ├── TagFilterBar（标签横向滚动筛选栏）
    ├── List（替代 LazyVStack，原生支持滑动删除和上下文菜单）
    │   └── NoteCardView（每条笔记）
    └── 右下角浮动 + 按钮 → ComposeView(.sheet)

NavigationBar
├── 左：App 名称
└── 右：⋯ 菜单 → 导出 / 外观切换

// SearchOverlayView 展示机制：
// .searchable 仅提供文本框。日期/标签面板通过 TimelineView 顶部
// @State var isFilterExpanded: Bool 控制，点击工具栏"筛选"按钮切换显隐。
// 面板以条件渲染 VStack 插在 TagFilterBar 上方（不用 sheet，保持搜索状态可见）。
SearchFilterPanel（isFilterExpanded = true 时显示，VStack）
    ├── DatePicker × 2（"开始日期" / "结束日期"，.compact 样式）
    ├── 标签多选行（TagFilterBar 多选模式）
    └── "清除全部筛选"按钮

NoteCardView（点击）→ NoteDetailView(.navigationDestination)
    ├── 完整 Markdown 渲染内容
    ├── 图片区：1张全宽 / 2张各半宽 / 3-4张 2×N 网格（ImageGridView 复用）
    ├── 编辑按钮 → ComposeView(.sheet, 编辑模式)
    ├── 删除按钮（确认 Alert）
    └── 历史记录按钮 → EditHistoryView(.sheet)

ComposeView(.sheet)
    ├── Markdown TextEditor（编辑/预览 切换，@State var isPreview）
    ├── 图片选择区（已选图片横向滚动 + 添加按钮，最多4张总计）
    └── TagInputField（标签输入，带历史标签自动补全）

ExportView(.sheet，从 ⋯ 菜单触发）
    ├── 导出格式选择：JSON / Markdown+图片
    └── 导出范围：全部 / 当前筛选结果
```

**`List` vs `LazyVStack` 的选择：** 使用 `List` 以获得原生滑动删除（`.onDelete`）和上下文菜单（`.contextMenu`）支持，同时 `List` 本身已是懒加载，性能无差异。NoteCardView 通过 `.listRowSeparator(.hidden)` 和 `.listRowBackground(Color.clear)` 实现自定义卡片外观。

**删除联动说明：** 无论通过何种路径删除笔记（`NoteDetailView` 的删除按钮 或 `TimelineView` 的滑动删除 `.onDelete`），都必须执行以下三步：
1. `ImageStorageService.deleteImages(for: note.id)` — 清理磁盘图片目录
2. 检查关联 Tag，`tag.notes.isEmpty` 则删除孤立 Tag
3. `modelContext.delete(note)` — 删除 SwiftData 记录（cascade 自动删除 images/editHistory）
封装为 `NoteRepository.delete(_ note: Note, context: ModelContext)` 复用，两处调用同一方法。

---

## 5. 核心功能实现

### 5.1 Markdown 编辑与渲染
- 编辑：SwiftUI 原生 `TextEditor`
- 渲染：`(try? AttributedString(markdown: content, options: .init(interpretedSyntax: .inlinesOnlyPreservingWhitespace))) ?? AttributedString(content)`（`try?` + 纯文本兜底，避免崩溃）
- 编辑/预览通过 `@State var isPreview: Bool` 切换
- 存储：纯字符串，全文搜索用 `content.localizedCaseInsensitiveContains(keyword)`

### 5.2 图片处理
- 选择：`PHPickerViewController` 包装为 `UIViewControllerRepresentable`
  - 选择上限 = `max(0, 4 - existingImages.count)`，编辑时自动扣减已有图片数
- 存储：压缩后写入 `Documents/images/<noteID>/`
- 显示（卡片/详情复用 `ImageGridView`）：
  - 1张：全宽
  - 2张：各占一半，横向排列
  - 3-4张：2列网格
- 清理：笔记删除时调用 `ImageStorageService.deleteImages(for: noteID)` 删除整个 `<noteID>/` 目录
- 错误处理：图片写入失败时 alert 提示用户（"图片保存失败，请检查存储空间"）；读取时文件缺失则显示占位符图标

### 5.3 标签输入与自动补全
- `TagInputField`（`ComposeView` 内）从 `@Query var allTags: [Tag]` 获取所有标签
- 输入时过滤展示下拉候选列表（`localizedCaseInsensitiveContains`）
- 回车或点击候选项确认添加；标签不存在则创建新 `Tag`（利用 `@Attribute(.unique)` 防止重复）
- `TagFilterBar`（时间线顶部）展示所有 Tag 供单击快速过滤，与搜索条件联动

### 5.4 搜索与过滤

> **重要：** SwiftData `@Query(filter:)` 仅接受 `Predicate<T>`（宏类型），不接受 `NSPredicate`。
> 但 `#Predicate` 不支持关系遍历的 `ANY` 语义，因此搜索/过滤改用 `FetchDescriptor` + `modelContext.fetch()`，结果存入 `@State`。

```swift
// TimelineView 中
@State var notes: [Note] = []

// 触发时机：.onChange(of: searchText)、.onChange(of: selectedTags)、
//           .onChange(of: startDate)、.onChange(of: endDate)、.onAppear
func refreshNotes(context: ModelContext) {
    let predicate = PredicateBuilder.build(
        searchText: searchText,
        tags: selectedTags,
        startDate: startDate,
        endDate: endDate
    )
    var descriptor = FetchDescriptor<Note>(
        predicate: predicate,
        sortBy: [SortDescriptor(\Note.createdAt, order: .reverse)]
    )
    notes = (try? context.fetch(descriptor)) ?? []
}
```

`PredicateBuilder.build(...)` 内部使用 `NSPredicate`：
```swift
// 标签：ANY 语义
NSPredicate(format: "ANY tags.name IN %@", Array(tags))
// 全文（大小写不敏感）
NSPredicate(format: "content CONTAINS[cd] %@", searchText)
// 日期范围
NSPredicate(format: "createdAt >= %@ AND createdAt <= %@", startDate as CVarArg, endDate as CVarArg)
// 多条件 AND 组合
NSCompoundPredicate(andPredicateWithSubpredicates: activeClauses)
```

返回值为 `NSPredicate`，传入 `FetchDescriptor(predicate:)` 构造器（该构造器同时接受 `Predicate<T>` 和 `NSPredicate`）。

### 5.5 编辑历史
- 触发时机：`ComposeView` 保存时，若 `content != note.content`，先创建 `EditRecord(content: note.content, noteID: note.id)` 快照
- **保留策略：每条笔记最多保留 20 条**历史记录，保存快照后若超出则删除最早的一条：
  ```swift
  if note.editHistory.count > 20,
     let oldest = note.editHistory.min(by: { $0.editedAt < $1.editedAt }) {
      context.delete(oldest)
  }
  ```
- 查看：`EditHistoryView`（sheet），`@Query(filter: #Predicate<EditRecord> { $0.noteID == noteID }, sort: \EditRecord.editedAt, order: .reverse)` 查询（`noteID` 是值类型，`#Predicate` 可正常支持）

### 5.6 导出

**NoteDTO（JSON 导出结构）：**
```swift
struct NoteDTO: Codable {
    let id: String           // UUID string
    let content: String      // Markdown 正文
    let createdAt: String    // ISO8601 格式
    let updatedAt: String
    let tags: [String]       // Tag 名称数组
    let images: [String]     // 图片文件名数组（相对路径）
}
```

- **JSON**：`[NoteDTO]` → `JSONEncoder().encode()` → `ShareSheet`
- **Markdown + 图片**：每条笔记生成 `<yyyy-MM-dd_HHmmss>-<id_prefix>.md`（日期格式避免冒号，合法文件名），图片复制到 `images/` 子目录，使用 **ZIPFoundation**（唯一 SPM 第三方依赖）打包为 `.zip` 后 `ShareSheet` 分享
- 导出范围：有效筛选条件时导出筛选结果，否则导出全部

### 5.7 外观管理
```swift
// AppearanceManager.swift
enum AppearanceMode: String, CaseIterable {
    case system, light, dark

    var colorScheme: ColorScheme? {  // .preferredColorScheme 所需，nil = 跟随系统
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

class AppearanceManager: ObservableObject {
    @AppStorage("appearanceMode") var mode: AppearanceMode = .system
}

// SuperbrainApp.swift
@main struct SuperbrainApp: App {
    @StateObject var appearance = AppearanceManager()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(appearance.mode.colorScheme)
                .environmentObject(appearance)
        }
    }
}
```

---

## 6. 项目文件结构

```
SuperbrainApp/
├── App/
│   ├── SuperbrainApp.swift          // @main, ModelContainer, AppearanceManager 注入
│   └── AppearanceManager.swift      // @AppStorage 外观模式管理
├── Models/
│   ├── Note.swift
│   ├── NoteImage.swift
│   ├── Tag.swift
│   └── EditRecord.swift
├── Views/
│   ├── Timeline/
│   │   ├── TimelineView.swift
│   │   ├── NoteCardView.swift
│   │   ├── TagFilterBar.swift
│   │   └── SearchOverlayView.swift  // 日期/标签过滤扩展面板
│   ├── Compose/
│   │   ├── ComposeView.swift
│   │   └── TagInputField.swift
│   ├── Detail/
│   │   ├── NoteDetailView.swift
│   │   ├── ImageGridView.swift      // 卡片和详情页复用
│   │   └── EditHistoryView.swift
│   └── Export/
│       └── ExportView.swift
├── Services/
│   ├── ImageStorageService.swift    // 图片读写/删除/压缩，错误通过 Result<> 返回
│   ├── ExportService.swift          // JSON / Markdown zip 导出，NoteDTO 定义在此
│   └── NoteRepository.swift         // 封装删除逻辑（图片+孤立Tag+SwiftData），供多处复用
└── Utilities/
    └── PredicateBuilder.swift       // NSPredicate 动态构建
```

---

## 7. 关键技术决策

| 决策 | 选择 | 理由 |
|---|---|---|
| 最低系统版本 | iOS 17 | SwiftData 要求 |
| 富文本方案 | Markdown 字符串 | 无需 UITextView 包装，存储/搜索/导出天然简单 |
| 图片存储 | 文件系统 + id 派生文件名 | 避免存 Data 的内存问题；路径规则唯一确定 |
| 导航结构 | 单 NavigationStack + List | List 原生支持滑动删除，个人工具无需 TabView |
| 搜索/过滤 | FetchDescriptor + NSPredicate | @Query 不接受 NSPredicate；#Predicate 不支持 ANY 关系语义，FetchDescriptor 可接受 NSPredicate |
| 状态管理 | @Query（简单列表）+ @State + FetchDescriptor（搜索）| 无筛选时 @Query 驱动，有筛选时 FetchDescriptor + @State 存结果，无需 ViewModel 层 |
| 外观持久化 | @AppStorage + .preferredColorScheme | 纯 SwiftUI 方案，无需访问 UIWindow |
| Tag 唯一性 | @Attribute(.unique) | 数据库层保障，防止并发写入重复 Tag |

---

## 8. 不在范围内（YAGNI）

- iCloud 同步
- 多账户 / 多用户
- 推送通知 / 提醒
- 网络功能
- 第三方登录
- Widget / 快捷指令
