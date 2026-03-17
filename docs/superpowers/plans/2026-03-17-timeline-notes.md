# 个人时间线笔记 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 构建一个类 X/Twitter 风格的 iOS 个人时间线笔记应用，支持 Markdown 正文、多图、标签、搜索、编辑历史和导出。

**Architecture:** SwiftData 存储所有结构化数据（笔记、标签、历史），图片以 JPEG 文件形式存于 Documents/images/，仅在 SwiftData 中存 UUID 引用。单 NavigationStack 导航，无 TabView，@Query + 内存过滤驱动视图更新。

**Tech Stack:** Swift 5.9+, SwiftUI, SwiftData (iOS 17+), XCTest, ZIPFoundation (SPM), PHPickerViewController

---

> ⚠️ **前置条件：macOS + Xcode 15+**
> 本计划需在 macOS 环境下执行。`xcodebuild` 命令均在 macOS Terminal 运行。用 `xcrun simctl list devices` 查看可用模拟器，根据实际情况替换 `name=iPhone 16`。

---

## 文件清单

| 文件 | 职责 |
|---|---|
| `project.yml` | xcodegen 项目配置，含 ZIPFoundation SPM 依赖 |
| `Superbrain/App/SuperbrainApp.swift` | @main 入口，ModelContainer，AppearanceManager 注入 |
| `Superbrain/App/AppearanceManager.swift` | 外观模式 @AppStorage 持久化 |
| `Superbrain/Models/Note.swift` | SwiftData Note 模型 |
| `Superbrain/Models/NoteImage.swift` | SwiftData NoteImage 模型，fileName 由 id 派生 |
| `Superbrain/Models/Tag.swift` | SwiftData Tag 模型，@Attribute(.unique) |
| `Superbrain/Models/EditRecord.swift` | SwiftData EditRecord 模型 |
| `Superbrain/Services/ImageStorageService.swift` | 图片读写/删除/压缩，Result<> 错误返回 |
| `Superbrain/Services/ExportService.swift` | NoteDTO，JSON/Markdown+zip 导出 |
| `Superbrain/Utilities/PredicateBuilder.swift` | NSPredicate 动态构建（全文/日期/标签） |
| `Superbrain/Views/Timeline/TimelineView.swift` | 主界面：List + searchable + 浮动 + 按钮 |
| `Superbrain/Views/Timeline/NoteCardView.swift` | 时间线单条笔记卡片 |
| `Superbrain/Views/Timeline/TagFilterBar.swift` | 标签横向滚动快速筛选栏 |
| `Superbrain/Views/Timeline/SearchOverlayView.swift` | 日期/标签过滤扩展面板 |
| `Superbrain/Views/Compose/ComposeView.swift` | 新建/编辑笔记 sheet，note 参数区分模式 |
| `Superbrain/Views/Compose/TagInputField.swift` | 标签输入 + 历史自动补全 |
| `Superbrain/Views/Detail/NoteDetailView.swift` | 笔记详情页 |
| `Superbrain/Views/Detail/ImageGridView.swift` | 1/2/3-4 张图片自适应网格，卡片和详情复用 |
| `Superbrain/Views/Detail/EditHistoryView.swift` | 编辑历史列表 sheet |
| `Superbrain/Views/Export/ExportView.swift` | 导出格式和范围选择 |
| `SuperbrainTests/ImageStorageServiceTests.swift` | ImageStorageService 单元测试 |
| `SuperbrainTests/ExportServiceTests.swift` | ExportService 单元测试 |
| `SuperbrainTests/PredicateBuilderTests.swift` | PredicateBuilder 单元测试 |

---

### Task 1: 项目初始化（xcodegen）

**Files:**
- Create: `project.yml`
- Create: 目录结构

- [ ] **Step 1: 安装 xcodegen（如未安装）**

```bash
brew install xcodegen
```

- [ ] **Step 2: 创建目录结构**

```bash
mkdir -p Superbrain/App Superbrain/Models Superbrain/Services Superbrain/Utilities
mkdir -p Superbrain/Views/Timeline Superbrain/Views/Compose
mkdir -p Superbrain/Views/Detail Superbrain/Views/Export
mkdir -p SuperbrainTests
```

- [ ] **Step 3: 写入 project.yml**

```yaml
name: Superbrain
options:
  bundleIdPrefix: com.personal
  deploymentTarget:
    iOS: "17.0"
  createIntermediateGroups: true
targets:
  Superbrain:
    type: application
    platform: iOS
    sources: [Superbrain]
    settings:
      base:
        SWIFT_VERSION: 5.9
        PRODUCT_BUNDLE_IDENTIFIER: com.personal.superbrain
        MARKETING_VERSION: 1.0.0
        CURRENT_PROJECT_VERSION: 1
        INFOPLIST_KEY_NSPhotoLibraryUsageDescription: "选择图片附加到笔记"
        INFOPLIST_KEY_UIApplicationSceneManifest_Generation: true
        INFOPLIST_KEY_UILaunchScreen_Generation: true
    dependencies:
      - package: ZIPFoundation
  SuperbrainTests:
    type: bundle.unit-test
    platform: iOS
    sources: [SuperbrainTests]
    dependencies:
      - target: Superbrain
packages:
  ZIPFoundation:
    url: https://github.com/weichsel/ZIPFoundation
    from: 0.9.19
```

- [ ] **Step 4: 生成 Xcode 项目**

```bash
xcodegen generate
```

Expected: `Superbrain.xcodeproj` 生成成功，无错误

- [ ] **Step 5: 创建临时入口文件验证编译**

```swift
// Superbrain/App/SuperbrainApp.swift
import SwiftUI

@main
struct SuperbrainApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Hello, Superbrain!")
        }
    }
}
```

- [ ] **Step 6: 编译验证**

```bash
xcodebuild build \
  -scheme Superbrain \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  CODE_SIGNING_ALLOWED=NO | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 7: 初始提交**

```bash
git init
git add project.yml Superbrain/ SuperbrainTests/
git commit -m "feat: initialize Xcode project with xcodegen"
```

---

### Task 2: SwiftData 数据模型

**Files:**
- Create: `Superbrain/Models/Note.swift`
- Create: `Superbrain/Models/NoteImage.swift`
- Create: `Superbrain/Models/Tag.swift`
- Create: `Superbrain/Models/EditRecord.swift`
- Modify: `Superbrain/App/SuperbrainApp.swift`

- [ ] **Step 1: 写 Note.swift**

```swift
// Superbrain/Models/Note.swift
import Foundation
import SwiftData

@Model
final class Note {
    var id: UUID = UUID()
    var content: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \NoteImage.note)
    var images: [NoteImage] = []

    @Relationship
    var tags: [Tag] = []

    @Relationship(deleteRule: .cascade, inverse: \EditRecord.note)
    var editHistory: [EditRecord] = []

    init(content: String = "") {
        self.id = UUID()
        self.content = content
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
```

- [ ] **Step 2: 写 NoteImage.swift**

```swift
// Superbrain/Models/NoteImage.swift
import Foundation
import SwiftData

@Model
final class NoteImage {
    var id: UUID = UUID()
    var order: Int = 0
    var createdAt: Date = Date()
    var note: Note?

    /// 文件名由 id 派生，完整路径：Documents/images/<noteID>/<fileName>
    var fileName: String { "\(id.uuidString).jpg" }

    init(order: Int) {
        self.id = UUID()
        self.order = order
        self.createdAt = Date()
    }
}
```

- [ ] **Step 3: 写 Tag.swift**

```swift
// Superbrain/Models/Tag.swift
import Foundation
import SwiftData

@Model
final class Tag {
    @Attribute(.unique) var name: String
    var createdAt: Date = Date()

    @Relationship(inverse: \Note.tags)
    var notes: [Note] = []

    init(name: String) {
        self.name = name
        self.createdAt = Date()
    }
}
```

- [ ] **Step 4: 写 EditRecord.swift**

```swift
// Superbrain/Models/EditRecord.swift
import Foundation
import SwiftData

@Model
final class EditRecord {
    var id: UUID = UUID()
    var content: String = ""
    var editedAt: Date = Date()
    var note: Note?

    init(content: String, note: Note) {
        self.id = UUID()
        self.content = content
        self.editedAt = Date()
        self.note = note
    }
}
```

- [ ] **Step 5: 更新 SuperbrainApp.swift 接入 ModelContainer**

```swift
// Superbrain/App/SuperbrainApp.swift
import SwiftUI
import SwiftData

@main
struct SuperbrainApp: App {
    let modelContainer: ModelContainer = {
        let schema = Schema([Note.self, NoteImage.self, Tag.self, EditRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        return try! ModelContainer(for: schema, configurations: [config])
    }()

    var body: some Scene {
        WindowGroup {
            Text("Models loaded")
                .modelContainer(modelContainer)
        }
    }
}
```

- [ ] **Step 6: 编译验证**

```bash
xcodebuild build \
  -scheme Superbrain \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  CODE_SIGNING_ALLOWED=NO | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 7: 提交**

```bash
git add Superbrain/Models/ Superbrain/App/SuperbrainApp.swift
git commit -m "feat: add SwiftData models (Note, NoteImage, Tag, EditRecord)"
```

---

### Task 3: ImageStorageService（TDD）

**Files:**
- Create: `Superbrain/Services/ImageStorageService.swift`
- Create: `SuperbrainTests/ImageStorageServiceTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
// SuperbrainTests/ImageStorageServiceTests.swift
import XCTest
@testable import Superbrain

final class ImageStorageServiceTests: XCTestCase {
    var sut: ImageStorageService!
    var testNoteID: UUID!

    override func setUp() {
        super.setUp()
        sut = ImageStorageService(baseURL: FileManager.default.temporaryDirectory)
        testNoteID = UUID()
    }

    override func tearDown() {
        sut.deleteImages(for: testNoteID)
        super.tearDown()
    }

    func test_saveAndLoad_roundtrip() {
        let image = UIImage(systemName: "star.fill")!
        let imageID = UUID()

        let result = sut.save(image: image, imageID: imageID, noteID: testNoteID)
        XCTAssertNoThrow(try result.get())

        let loaded = sut.load(imageID: imageID, noteID: testNoteID)
        XCTAssertNotNil(loaded)
    }

    func test_delete_removesDirectory() {
        let image = UIImage(systemName: "star.fill")!
        let imageID = UUID()
        _ = sut.save(image: image, imageID: imageID, noteID: testNoteID)

        sut.deleteImages(for: testNoteID)

        let loaded = sut.load(imageID: imageID, noteID: testNoteID)
        XCTAssertNil(loaded)
    }

    func test_loadMissingFile_returnsNil() {
        let result = sut.load(imageID: UUID(), noteID: testNoteID)
        XCTAssertNil(result)
    }
}
```

- [ ] **Step 2: 运行测试，确认编译失败**

```bash
xcodebuild test \
  -scheme Superbrain \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  -only-testing:SuperbrainTests/ImageStorageServiceTests \
  CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|Build FAILED"
```

Expected: 编译错误（`ImageStorageService` 未定义）

- [ ] **Step 3: 实现 ImageStorageService**

```swift
// Superbrain/Services/ImageStorageService.swift
import UIKit

final class ImageStorageService {
    private let baseURL: URL

    init(baseURL: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]) {
        self.baseURL = baseURL
    }

    // MARK: - Public API

    @discardableResult
    func save(image: UIImage, imageID: UUID, noteID: UUID) -> Result<Void, Error> {
        let dirURL = directoryURL(for: noteID)
        do {
            try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
            let fileURL = dirURL.appendingPathComponent("\(imageID.uuidString).jpg")
            let quality: CGFloat = image.jpegData(compressionQuality: 0.8).map {
                $0.count > 2 * 1024 * 1024 ? 0.5 : 0.8
            } ?? 0.8
            guard let data = image.jpegData(compressionQuality: quality) else {
                return .failure(ImageStorageError.compressionFailed)
            }
            try data.write(to: fileURL, options: .atomic)
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    func load(imageID: UUID, noteID: UUID) -> UIImage? {
        let fileURL = directoryURL(for: noteID)
            .appendingPathComponent("\(imageID.uuidString).jpg")
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    func deleteImages(for noteID: UUID) {
        try? FileManager.default.removeItem(at: directoryURL(for: noteID))
    }

    // MARK: - Private

    private func directoryURL(for noteID: UUID) -> URL {
        baseURL.appendingPathComponent("images").appendingPathComponent(noteID.uuidString)
    }
}

enum ImageStorageError: LocalizedError {
    case compressionFailed
    var errorDescription: String? { "图片压缩失败" }
}
```

- [ ] **Step 4: 运行测试，确认通过**

```bash
xcodebuild test \
  -scheme Superbrain \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  -only-testing:SuperbrainTests/ImageStorageServiceTests \
  CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "passed|failed"
```

Expected: `Test Suite 'ImageStorageServiceTests' passed`

- [ ] **Step 5: 提交**

```bash
git add Superbrain/Services/ImageStorageService.swift SuperbrainTests/ImageStorageServiceTests.swift
git commit -m "feat: add ImageStorageService with TDD (save/load/delete)"
```

---

### Task 4: PredicateBuilder（TDD）

**Files:**
- Create: `Superbrain/Utilities/PredicateBuilder.swift`
- Create: `SuperbrainTests/PredicateBuilderTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
// SuperbrainTests/PredicateBuilderTests.swift
import XCTest
@testable import Superbrain

final class PredicateBuilderTests: XCTestCase {
    func test_emptyBuilder_returnsNil() {
        XCTAssertNil(PredicateBuilder().build())
    }

    func test_whitespaceText_returnsNil() {
        XCTAssertNil(PredicateBuilder().withText("   ").build())
    }

    func test_textFilter_containsKeyword() {
        let predicate = PredicateBuilder().withText("hello").build()
        XCTAssertNotNil(predicate)
        XCTAssertTrue(predicate!.predicateFormat.contains("hello"))
    }

    func test_dateRange_generatesPredicate() {
        let start = Date(timeIntervalSinceNow: -86400)
        let end = Date()
        let predicate = PredicateBuilder().withDateRange(start: start, end: end).build()
        XCTAssertNotNil(predicate)
    }

    func test_emptyTagSet_returnsNil() {
        XCTAssertNil(PredicateBuilder().withTags([]).build())
    }

    func test_tagFilter_generatesPredicate() {
        let predicate = PredicateBuilder().withTags(["工作"]).build()
        XCTAssertNotNil(predicate)
    }

    func test_multipleConditions_usesAND() {
        let predicate = PredicateBuilder()
            .withText("test")
            .withTags(["工作"])
            .build()
        XCTAssertNotNil(predicate)
        XCTAssertTrue(predicate!.predicateFormat.contains("AND"))
    }
}
```

- [ ] **Step 2: 运行测试，确认失败**

```bash
xcodebuild test \
  -scheme Superbrain \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  -only-testing:SuperbrainTests/PredicateBuilderTests \
  CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|Build FAILED"
```

- [ ] **Step 3: 实现 PredicateBuilder**

```swift
// Superbrain/Utilities/PredicateBuilder.swift
import Foundation

/// 构建 NSPredicate 用于 Note 查询。
/// 说明：SwiftData #Predicate 不支持 ANY 语义的关系遍历，
/// 统一使用 NSPredicate，在 TimelineView 中 fetch-all 后内存过滤。
final class PredicateBuilder {
    private var predicates: [NSPredicate] = []

    @discardableResult
    func withText(_ text: String) -> Self {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return self }
        predicates.append(NSPredicate(format: "content CONTAINS[cd] %@", text))
        return self
    }

    @discardableResult
    func withDateRange(start: Date?, end: Date?) -> Self {
        var parts: [NSPredicate] = []
        if let start { parts.append(NSPredicate(format: "createdAt >= %@", start as NSDate)) }
        if let end   { parts.append(NSPredicate(format: "createdAt <= %@", end as NSDate)) }
        if !parts.isEmpty {
            predicates.append(NSCompoundPredicate(andPredicateWithSubpredicates: parts))
        }
        return self
    }

    @discardableResult
    func withTags(_ tagNames: Set<String>) -> Self {
        guard !tagNames.isEmpty else { return self }
        predicates.append(NSPredicate(format: "ANY tags.name IN %@", tagNames as CVarArg))
        return self
    }

    func build() -> NSPredicate? {
        guard !predicates.isEmpty else { return nil }
        return predicates.count == 1
            ? predicates[0]
            : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }
}
```

- [ ] **Step 4: 运行测试，确认通过**

```bash
xcodebuild test \
  -scheme Superbrain \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  -only-testing:SuperbrainTests/PredicateBuilderTests \
  CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "passed|failed"
```

Expected: `Test Suite 'PredicateBuilderTests' passed`

- [ ] **Step 5: 提交**

```bash
git add Superbrain/Utilities/PredicateBuilder.swift SuperbrainTests/PredicateBuilderTests.swift
git commit -m "feat: add PredicateBuilder for dynamic NSPredicate construction"
```

---

### Task 5: AppearanceManager + App 入口（最终版）

**Files:**
- Create: `Superbrain/App/AppearanceManager.swift`
- Modify: `Superbrain/App/SuperbrainApp.swift`
- Create: `Superbrain/Views/Timeline/TimelineView.swift`（占位）

- [ ] **Step 1: 写 AppearanceManager.swift**

```swift
// Superbrain/App/AppearanceManager.swift
import SwiftUI

enum AppearanceMode: String, CaseIterable {
    case system, light, dark

    var label: String {
        switch self {
        case .system: return "跟随系统"
        case .light:  return "浅色"
        case .dark:   return "深色"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

final class AppearanceManager: ObservableObject {
    @AppStorage("appearanceMode") var mode: AppearanceMode = .system {
        willSet { objectWillChange.send() }
    }
}
```

- [ ] **Step 2: 写 TimelineView 占位**

```swift
// Superbrain/Views/Timeline/TimelineView.swift
import SwiftUI

struct TimelineView: View {
    var body: some View {
        NavigationStack {
            Text("Timeline - coming soon")
                .navigationTitle("Superbrain")
        }
    }
}
```

- [ ] **Step 3: 更新 SuperbrainApp.swift（最终版）**

```swift
// Superbrain/App/SuperbrainApp.swift
import SwiftUI
import SwiftData

@main
struct SuperbrainApp: App {
    @StateObject private var appearance = AppearanceManager()

    let modelContainer: ModelContainer = {
        let schema = Schema([Note.self, NoteImage.self, Tag.self, EditRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        return try! ModelContainer(for: schema, configurations: [config])
    }()

    var body: some Scene {
        WindowGroup {
            TimelineView()
                .modelContainer(modelContainer)
                .environmentObject(appearance)
                .preferredColorScheme(appearance.mode.colorScheme)
        }
    }
}
```

- [ ] **Step 4: 编译验证**

```bash
xcodebuild build \
  -scheme Superbrain \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  CODE_SIGNING_ALLOWED=NO | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: 提交**

```bash
git add Superbrain/App/ Superbrain/Views/Timeline/TimelineView.swift
git commit -m "feat: add AppearanceManager and wire app entry point"
```

---

### Task 6: ImageGridView（共享组件）

**Files:**
- Create: `Superbrain/Views/Detail/ImageGridView.swift`

- [ ] **Step 1: 实现 ImageGridView**

```swift
// Superbrain/Views/Detail/ImageGridView.swift
import SwiftUI

/// 自适应图片网格：1张全宽 / 2张各半宽 / 3-4张 2列网格
/// NoteCardView 和 NoteDetailView 共同复用
struct ImageGridView: View {
    let images: [UIImage]
    var maxHeight: CGFloat = 200

    var body: some View {
        switch images.count {
        case 1:
            singleImage(images[0])
        case 2:
            HStack(spacing: 2) {
                imageCell(images[0])
                imageCell(images[1])
            }
            .frame(height: maxHeight)
        case 3, 4:
            let rows = images.chunked(into: 2)
            VStack(spacing: 2) {
                ForEach(rows.indices, id: \.self) { i in
                    HStack(spacing: 2) {
                        ForEach(rows[i], id: \.self) { img in
                            imageCell(img)
                        }
                    }
                }
            }
            .frame(maxHeight: maxHeight * CGFloat((images.count + 1) / 2))
        default:
            EmptyView()
        }
    }

    private func singleImage(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: maxHeight)
            .clipped()
            .cornerRadius(8)
    }

    private func imageCell(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .clipped()
            .cornerRadius(6)
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
```

- [ ] **Step 2: 编译验证**

```bash
xcodebuild build \
  -scheme Superbrain \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  CODE_SIGNING_ALLOWED=NO | tail -5
```

- [ ] **Step 3: 提交**

```bash
git add Superbrain/Views/Detail/ImageGridView.swift
git commit -m "feat: add ImageGridView shared component"
```

---

### Task 7: NoteCardView + TagFilterBar

**Files:**
- Create: `Superbrain/Views/Timeline/NoteCardView.swift`
- Create: `Superbrain/Views/Timeline/TagFilterBar.swift`

- [ ] **Step 1: 实现 NoteCardView**

```swift
// Superbrain/Views/Timeline/NoteCardView.swift
import SwiftUI

struct NoteCardView: View {
    let note: Note
    let imageStorageService: ImageStorageService

    @State private var loadedImages: [UIImage] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Markdown 渲染（最多5行截断）
            let attributed = (try? AttributedString(
                markdown: note.content,
                options: .init(interpretedSyntax: .inlinesOnlyPreservingWhitespace)
            )) ?? AttributedString(note.content)
            Text(attributed)
                .lineLimit(5)

            // 图片网格
            if !loadedImages.isEmpty {
                ImageGridView(images: loadedImages, maxHeight: 160)
            }

            // 标签行
            if !note.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(note.tags.sorted(by: { $0.name < $1.name }), id: \.name) { tag in
                            Text("#\(tag.name)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // 时间戳
            Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .onAppear { loadImages() }
    }

    private func loadImages() {
        loadedImages = note.images
            .sorted(by: { $0.order < $1.order })
            .compactMap { imageStorageService.load(imageID: $0.id, noteID: note.id) }
    }
}
```

- [ ] **Step 2: 实现 TagFilterBar**

```swift
// Superbrain/Views/Timeline/TagFilterBar.swift
import SwiftUI
import SwiftData

struct TagFilterBar: View {
    @Query(sort: \Tag.name) private var allTags: [Tag]
    @Binding var selectedTag: String?

    var body: some View {
        if !allTags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip(label: "全部", tagName: nil)
                    ForEach(allTags, id: \.name) { tag in
                        chip(label: "#\(tag.name)", tagName: tag.name)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
        }
    }

    @ViewBuilder
    private func chip(label: String, tagName: String?) -> some View {
        let isSelected = selectedTag == tagName
        Button(action: { selectedTag = isSelected ? nil : tagName }) {
            Text(label)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(isSelected ? Color.primary : Color.secondary.opacity(0.15))
                .foregroundStyle(isSelected ? Color(uiColor: .systemBackground) : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 3: 编译验证**

```bash
xcodebuild build \
  -scheme Superbrain \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  CODE_SIGNING_ALLOWED=NO | tail -5
```

- [ ] **Step 4: 提交**

```bash
git add Superbrain/Views/Timeline/NoteCardView.swift Superbrain/Views/Timeline/TagFilterBar.swift
git commit -m "feat: add NoteCardView and TagFilterBar"
```

---

### Task 8: TimelineView（完整）+ SearchOverlayView

**Files:**
- Create: `Superbrain/Views/Timeline/SearchOverlayView.swift`
- Modify: `Superbrain/Views/Timeline/TimelineView.swift`

> 注意：TimelineView 此时引用 ComposeView、NoteDetailView、ExportView，这些尚未实现。
> 先以 `Text("coming soon")` 占位替换对应 sheet 内容，后续 Task 9-11 实现后再删除占位。

- [ ] **Step 1: 实现 SearchOverlayView**

```swift
// Superbrain/Views/Timeline/SearchOverlayView.swift
import SwiftUI

struct SearchOverlayView: View {
    @Binding var startDate: Date?
    @Binding var endDate: Date?
    @Binding var selectedTags: Set<String>
    let allTagNames: [String]
    let onClear: () -> Void

    @State private var tempStart = Date()
    @State private var tempEnd = Date()
    @State private var useStartDate = false
    @State private var useEndDate = false

    var body: some View {
        List {
            Section("日期范围") {
                Toggle("开始日期", isOn: $useStartDate)
                if useStartDate {
                    DatePicker("", selection: $tempStart, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .onChange(of: tempStart) { startDate = tempStart }
                }
                Toggle("结束日期", isOn: $useEndDate)
                if useEndDate {
                    DatePicker("", selection: $tempEnd, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .onChange(of: tempEnd) { endDate = tempEnd }
                }
            }

            Section("标签") {
                ForEach(allTagNames, id: \.self) { name in
                    let isSelected = selectedTags.contains(name)
                    Button {
                        if isSelected { selectedTags.remove(name) }
                        else { selectedTags.insert(name) }
                    } label: {
                        HStack {
                            Text("#\(name)")
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark").foregroundStyle(.blue)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }

            Section {
                Button("清除全部筛选", role: .destructive) {
                    useStartDate = false
                    useEndDate = false
                    selectedTags = []
                    onClear()
                }
            }
        }
        .onChange(of: useStartDate) { if !useStartDate { startDate = nil } }
        .onChange(of: useEndDate) { if !useEndDate { endDate = nil } }
    }
}
```

- [ ] **Step 2: 实现完整 TimelineView（含占位 sheet）**

```swift
// Superbrain/Views/Timeline/TimelineView.swift
import SwiftUI
import SwiftData

struct TimelineView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appearance: AppearanceManager

    @State private var searchText = ""
    @State private var selectedTag: String?
    @State private var startDate: Date?
    @State private var endDate: Date?
    @State private var selectedTags: Set<String> = []
    @State private var showCompose = false
    @State private var showSearchOverlay = false
    @State private var showExport = false

    @Query(sort: \Tag.name) private var allTags: [Tag]
    private let imageStorageService = ImageStorageService()

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    TagFilterBar(selectedTag: $selectedTag)
                    noteList
                }

                // 浮动 + 按钮
                Button { showCompose = true } label: {
                    Image(systemName: "plus")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.primary)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
                .padding(20)
            }
            .navigationTitle("Superbrain")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .searchable(text: $searchText, prompt: "搜索笔记")
            .sheet(isPresented: $showCompose) {
                // Task 9 实现后替换为 ComposeView()
                Text("ComposeView - coming soon")
            }
            .sheet(isPresented: $showExport) {
                // Task 11 实现后替换为 ExportView(notes: filteredNotes)
                Text("ExportView - coming soon")
            }
            .sheet(isPresented: $showSearchOverlay) {
                NavigationStack {
                    SearchOverlayView(
                        startDate: $startDate,
                        endDate: $endDate,
                        selectedTags: $selectedTags,
                        allTagNames: allTags.map(\.name),
                        onClear: { startDate = nil; endDate = nil }
                    )
                    .navigationTitle("筛选")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("完成") { showSearchOverlay = false }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var noteList: some View {
        let notes = filteredNotes
        if notes.isEmpty {
            ContentUnavailableView(
                "还没有笔记",
                systemImage: "note.text",
                description: Text("点击右下角 + 开始记录")
            )
        } else {
            List {
                ForEach(notes) { note in
                    NavigationLink(value: note) {
                        NoteCardView(note: note, imageStorageService: imageStorageService)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
                .onDelete(perform: deleteNotes)
            }
            .listStyle(.plain)
            .navigationDestination(for: Note.self) { note in
                // Task 10 实现后替换为 NoteDetailView(note: note, ...)
                Text("NoteDetailView - coming soon")
            }
        }
    }

    private var filteredNotes: [Note] {
        let all = (try? modelContext.fetch(
            FetchDescriptor<Note>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        )) ?? []

        let predicate = PredicateBuilder()
            .withText(searchText)
            .withDateRange(start: startDate, end: endDate)
            .withTags(selectedTags.isEmpty ? (selectedTag.map { [$0] } ?? []) : selectedTags)
            .build()

        guard let nsPredicate = predicate else { return all }
        return all.filter { nsPredicate.evaluate(with: $0) }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button { showSearchOverlay = true } label: {
                    Label("筛选", systemImage: "line.3.horizontal.decrease.circle")
                }
                Button { showExport = true } label: {
                    Label("导出", systemImage: "square.and.arrow.up")
                }
                Divider()
                ForEach(AppearanceMode.allCases, id: \.self) { mode in
                    Button { appearance.mode = mode } label: {
                        Label(mode.label, systemImage: modeIcon(mode))
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    private func modeIcon(_ mode: AppearanceMode) -> String {
        switch mode {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max"
        case .dark:   return "moon"
        }
    }

    private func deleteNotes(at offsets: IndexSet) {
        let notes = filteredNotes
        for index in offsets {
            let note = notes[index]
            imageStorageService.deleteImages(for: note.id)
            for tag in note.tags where tag.notes.count <= 1 {
                modelContext.delete(tag)
            }
            modelContext.delete(note)
        }
        try? modelContext.save()
    }
}
```

- [ ] **Step 3: 编译验证**

```bash
xcodebuild build \
  -scheme Superbrain \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  CODE_SIGNING_ALLOWED=NO | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: 提交**

```bash
git add Superbrain/Views/Timeline/
git commit -m "feat: implement TimelineView (search, filter, delete) and SearchOverlayView"
```

---

### Task 9: ComposeView + TagInputField

**Files:**
- Create: `Superbrain/Views/Compose/TagInputField.swift`
- Create: `Superbrain/Views/Compose/ComposeView.swift`

- [ ] **Step 1: 实现 TagInputField**

```swift
// Superbrain/Views/Compose/TagInputField.swift
import SwiftUI
import SwiftData

struct TagInputField: View {
    @Binding var selectedTags: [Tag]
    @Query(sort: \Tag.name) private var allTags: [Tag]
    @Environment(\.modelContext) private var modelContext

    @State private var inputText = ""
    @State private var showSuggestions = false

    private var suggestions: [Tag] {
        guard !inputText.isEmpty else { return [] }
        return allTags.filter {
            $0.name.localizedCaseInsensitiveContains(inputText) && !selectedTags.contains($0)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 已选标签
            if !selectedTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(selectedTags, id: \.name) { tag in
                            HStack(spacing: 3) {
                                Text("#\(tag.name)").font(.subheadline)
                                Button {
                                    selectedTags.removeAll { $0.name == tag.name }
                                } label: {
                                    Image(systemName: "xmark.circle.fill").font(.caption)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(Capsule())
                        }
                    }
                }
            }

            // 输入框
            HStack {
                Image(systemName: "tag").foregroundStyle(.secondary)
                TextField("添加标签...", text: $inputText)
                    .autocorrectionDisabled()
                    .onSubmit { confirmTag() }
                    .onChange(of: inputText) { showSuggestions = !inputText.isEmpty }
            }

            // 候选列表
            if showSuggestions && !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(suggestions, id: \.name) { tag in
                        Button { addTag(tag) } label: {
                            Text("#\(tag.name)")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                        }
                        .foregroundStyle(.primary)
                        Divider()
                    }
                }
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(8)
            }
        }
    }

    private func confirmTag() {
        let name = inputText.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        if let existing = allTags.first(where: {
            $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame
        }) {
            addTag(existing)
        } else {
            let newTag = Tag(name: name)
            modelContext.insert(newTag)
            addTag(newTag)
        }
    }

    private func addTag(_ tag: Tag) {
        guard !selectedTags.contains(tag) else { return }
        selectedTags.append(tag)
        inputText = ""
        showSuggestions = false
    }
}
```

- [ ] **Step 2: 实现 ComposeView**

```swift
// Superbrain/Views/Compose/ComposeView.swift
import SwiftUI
import SwiftData
import PhotosUI

struct ComposeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// nil = 新建模式，non-nil = 编辑模式
    var note: Note? = nil

    private let imageStorageService = ImageStorageService()

    @State private var content = ""
    @State private var selectedTags: [Tag] = []
    @State private var isPreview = false
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var newImages: [UIImage] = []
    @State private var removedImageIDs: Set<UUID> = []
    @State private var existingImages: [UIImage] = []
    @State private var showImageError = false

    private var remainingSlots: Int {
        let existing = (note?.images.count ?? 0) - removedImageIDs.count
        return max(0, 4 - existing - newImages.count)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isPreview { previewContent } else { editContent }
            }
            .navigationTitle(note == nil ? "新建笔记" : "编辑笔记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button(isPreview ? "编辑" : "预览") { isPreview.toggle() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("发布") { save() }
                        .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .fontWeight(.bold)
                }
            }
            .alert("图片保存失败", isPresented: $showImageError) {
                Button("好") {}
            } message: {
                Text("请检查存储空间后重试")
            }
        }
        .onAppear { loadExistingNote() }
    }

    // MARK: - Edit Mode

    @ViewBuilder
    private var editContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                TextEditor(text: $content)
                    .frame(minHeight: 150)
                    .padding(4)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))

                imageSection
                Divider()
                TagInputField(selectedTags: $selectedTags)
                    .padding(.horizontal, 4)
            }
            .padding()
        }
    }

    // MARK: - Preview Mode

    @ViewBuilder
    private var previewContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                let attributed = (try? AttributedString(
                    markdown: content,
                    options: .init(interpretedSyntax: .inlinesOnlyPreservingWhitespace)
                )) ?? AttributedString(content)
                Text(attributed)
                    .frame(maxWidth: .infinity, alignment: .leading)

                let allImages = existingImages + newImages
                if !allImages.isEmpty { ImageGridView(images: allImages) }
            }
            .padding()
        }
    }

    // MARK: - Image Section

    @ViewBuilder
    private var imageSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // 已有图片（编辑模式）
                ForEach((note?.images ?? []).sorted(by: { $0.order < $1.order }), id: \.id) { img in
                    if !removedImageIDs.contains(img.id) {
                        existingThumbnail(img)
                    }
                }

                // 新选图片
                ForEach(newImages.indices, id: \.self) { i in
                    newThumbnail(at: i)
                }

                // 添加按钮
                if remainingSlots > 0 {
                    PhotosPicker(
                        selection: $pickerItems,
                        maxSelectionCount: remainingSlots,
                        matching: .images
                    ) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.15))
                            .frame(width: 80, height: 80)
                            .overlay(Image(systemName: "plus").foregroundStyle(.secondary))
                    }
                    .onChange(of: pickerItems) { loadPickerItems() }
                }
            }
        }
    }

    private func existingThumbnail(_ img: NoteImage) -> some View {
        let uiImage = note.flatMap { imageStorageService.load(imageID: img.id, noteID: $0.id) }
        return ZStack(alignment: .topTrailing) {
            Group {
                if let ui = uiImage {
                    Image(uiImage: ui).resizable().scaledToFill()
                } else {
                    Color.secondary.opacity(0.3)
                        .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
                }
            }
            .frame(width: 80, height: 80).clipped().cornerRadius(8)

            Button { removedImageIDs.insert(img.id) } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
            .padding(4)
        }
    }

    private func newThumbnail(at index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: newImages[index])
                .resizable().scaledToFill()
                .frame(width: 80, height: 80).clipped().cornerRadius(8)

            Button { newImages.remove(at: index) } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
            .padding(4)
        }
    }

    // MARK: - Logic

    private func loadExistingNote() {
        guard let note else { return }
        content = note.content
        selectedTags = note.tags
        existingImages = note.images
            .sorted(by: { $0.order < $1.order })
            .compactMap { imageStorageService.load(imageID: $0.id, noteID: note.id) }
    }

    private func loadPickerItems() {
        Task {
            var loaded: [UIImage] = []
            for item in pickerItems {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    loaded.append(img)
                }
            }
            await MainActor.run {
                newImages.append(contentsOf: loaded)
                pickerItems = []
            }
        }
    }

    private func save() {
        let targetNote: Note

        if let existing = note {
            // 编辑模式：保存历史快照
            if existing.content != content {
                let record = EditRecord(content: existing.content, note: existing)
                modelContext.insert(record)
                // 超出 20 条时删除最旧的
                let sorted = existing.editHistory.sorted(by: { $0.editedAt < $1.editedAt })
                if sorted.count >= 20, let oldest = sorted.first {
                    modelContext.delete(oldest)
                }
            }
            existing.content = content
            existing.updatedAt = Date()
            existing.tags = selectedTags
            // 删除被移除的图片记录
            for imgID in removedImageIDs {
                if let img = existing.images.first(where: { $0.id == imgID }) {
                    let imgDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        .appendingPathComponent("images")
                        .appendingPathComponent(existing.id.uuidString)
                        .appendingPathComponent(img.fileName)
                    try? FileManager.default.removeItem(at: imgDir)
                    modelContext.delete(img)
                }
            }
            targetNote = existing
        } else {
            // 新建模式
            let newNote = Note(content: content)
            newNote.tags = selectedTags
            modelContext.insert(newNote)
            targetNote = newNote
        }

        // 保存新图片
        let startOrder = (targetNote.images.map(\.order).max() ?? -1) + 1
        for (i, img) in newImages.enumerated() {
            let noteImage = NoteImage(order: startOrder + i)
            modelContext.insert(noteImage)
            let result = imageStorageService.save(image: img, imageID: noteImage.id, noteID: targetNote.id)
            if case .failure = result {
                showImageError = true
                modelContext.delete(noteImage)
                continue
            }
            targetNote.images.append(noteImage)
        }

        try? modelContext.save()
        dismiss()
    }
}
```

- [ ] **Step 3: 将 TimelineView 中的 ComposeView 占位替换为真实实现**

在 `TimelineView.swift` 中，将：
```swift
// Task 9 实现后替换为 ComposeView()
Text("ComposeView - coming soon")
```
替换为：
```swift
ComposeView()
```

- [ ] **Step 4: 编译验证**

```bash
xcodebuild build \
  -scheme Superbrain \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  CODE_SIGNING_ALLOWED=NO | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: 提交**

```bash
git add Superbrain/Views/Compose/ Superbrain/Views/Timeline/TimelineView.swift
git commit -m "feat: add ComposeView (new/edit mode, image picker, tag input)"
```

---

### Task 10: NoteDetailView + EditHistoryView

**Files:**
- Create: `Superbrain/Views/Detail/NoteDetailView.swift`
- Create: `Superbrain/Views/Detail/EditHistoryView.swift`

- [ ] **Step 1: 实现 NoteDetailView**

```swift
// Superbrain/Views/Detail/NoteDetailView.swift
import SwiftUI

struct NoteDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let note: Note
    let imageStorageService: ImageStorageService

    @State private var showEdit = false
    @State private var showHistory = false
    @State private var showDeleteAlert = false
    @State private var loadedImages: [UIImage] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Markdown 渲染
                let attributed = (try? AttributedString(
                    markdown: note.content,
                    options: .init(interpretedSyntax: .inlinesOnlyPreservingWhitespace)
                )) ?? AttributedString(note.content)
                Text(attributed)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // 图片
                if !loadedImages.isEmpty {
                    ImageGridView(images: loadedImages, maxHeight: 240)
                }

                // 标签
                if !note.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(note.tags.sorted(by: { $0.name < $1.name }), id: \.name) { tag in
                                Text("#\(tag.name)")
                                    .font(.subheadline)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.secondary.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                // 时间信息
                VStack(alignment: .leading, spacing: 4) {
                    Text("创建于 \(note.createdAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption).foregroundStyle(.secondary)
                    if note.updatedAt > note.createdAt {
                        Text("编辑于 \(note.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if !note.editHistory.isEmpty {
                    Button { showHistory = true } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                }
                Button { showEdit = true } label: {
                    Image(systemName: "pencil")
                }
                Button { showDeleteAlert = true } label: {
                    Image(systemName: "trash").foregroundStyle(.red)
                }
            }
        }
        .sheet(isPresented: $showEdit) { ComposeView(note: note) }
        .sheet(isPresented: $showHistory) { EditHistoryView(note: note) }
        .alert("删除笔记", isPresented: $showDeleteAlert) {
            Button("删除", role: .destructive) { deleteNote() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作无法撤销")
        }
        .onAppear { loadImages() }
    }

    private func loadImages() {
        loadedImages = note.images
            .sorted(by: { $0.order < $1.order })
            .compactMap { imageStorageService.load(imageID: $0.id, noteID: note.id) }
    }

    private func deleteNote() {
        imageStorageService.deleteImages(for: note.id)
        for tag in note.tags where tag.notes.count <= 1 {
            modelContext.delete(tag)
        }
        modelContext.delete(note)
        try? modelContext.save()
        dismiss()
    }
}
```

- [ ] **Step 2: 实现 EditHistoryView**

```swift
// Superbrain/Views/Detail/EditHistoryView.swift
import SwiftUI

struct EditHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    let note: Note

    @State private var selectedRecord: EditRecord?

    private var sortedHistory: [EditRecord] {
        note.editHistory.sorted(by: { $0.editedAt > $1.editedAt })
    }

    var body: some View {
        NavigationStack {
            List(sortedHistory, id: \.id) { record in
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.editedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text(record.content)
                        .lineLimit(2)
                }
                .onTapGesture { selectedRecord = record }
            }
            .navigationTitle("历史版本")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .sheet(item: $selectedRecord) { record in
                NavigationStack {
                    ScrollView {
                        let attributed = (try? AttributedString(
                            markdown: record.content,
                            options: .init(interpretedSyntax: .inlinesOnlyPreservingWhitespace)
                        )) ?? AttributedString(record.content)
                        Text(attributed)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                    .navigationTitle(record.editedAt.formatted(date: .abbreviated, time: .shortened))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("关闭") { selectedRecord = nil }
                        }
                    }
                }
            }
        }
    }
}

extension EditRecord: Identifiable {}
```

- [ ] **Step 3: 将 TimelineView 中 NoteDetailView 占位替换为真实实现**

在 `TimelineView.swift` 中，将：
```swift
// Task 10 实现后替换为 NoteDetailView(note: note, ...)
Text("NoteDetailView - coming soon")
```
替换为：
```swift
NoteDetailView(note: note, imageStorageService: imageStorageService)
```

- [ ] **Step 4: 编译验证**

```bash
xcodebuild build \
  -scheme Superbrain \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  CODE_SIGNING_ALLOWED=NO | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: 提交**

```bash
git add Superbrain/Views/Detail/ Superbrain/Views/Timeline/TimelineView.swift
git commit -m "feat: add NoteDetailView and EditHistoryView"
```

---

### Task 11: ExportService（TDD）+ ExportView

**Files:**
- Create: `Superbrain/Services/ExportService.swift`
- Create: `SuperbrainTests/ExportServiceTests.swift`
- Create: `Superbrain/Views/Export/ExportView.swift`

- [ ] **Step 1: 写失败测试**

```swift
// SuperbrainTests/ExportServiceTests.swift
import XCTest
@testable import Superbrain

final class ExportServiceTests: XCTestCase {
    func test_toDTO_mapsContent() {
        let note = Note(content: "**Hello** world")
        let dto = ExportService.toDTO(note: note)
        XCTAssertEqual(dto.content, "**Hello** world")
        XCTAssertTrue(dto.tags.isEmpty)
        XCTAssertTrue(dto.images.isEmpty)
    }

    func test_exportJSON_producesValidJSON() throws {
        let note = Note(content: "Test note")
        let data = try ExportService.exportJSON(notes: [note])
        let decoded = try JSONDecoder().decode([ExportService.NoteDTO].self, from: data)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].content, "Test note")
    }

    func test_exportJSON_multipleNotes() throws {
        let notes = [Note(content: "A"), Note(content: "B")]
        let data = try ExportService.exportJSON(notes: notes)
        let decoded = try JSONDecoder().decode([ExportService.NoteDTO].self, from: data)
        XCTAssertEqual(decoded.count, 2)
    }
}
```

- [ ] **Step 2: 运行测试，确认失败**

```bash
xcodebuild test \
  -scheme Superbrain \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  -only-testing:SuperbrainTests/ExportServiceTests \
  CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|Build FAILED"
```

- [ ] **Step 3: 实现 ExportService**

```swift
// Superbrain/Services/ExportService.swift
import Foundation
import ZIPFoundation

enum ExportService {
    struct NoteDTO: Codable {
        let id: String
        let content: String
        let createdAt: String
        let updatedAt: String
        let tags: [String]
        let images: [String]    // 图片文件名
    }

    static func toDTO(note: Note) -> NoteDTO {
        let fmt = ISO8601DateFormatter()
        return NoteDTO(
            id: note.id.uuidString,
            content: note.content,
            createdAt: fmt.string(from: note.createdAt),
            updatedAt: fmt.string(from: note.updatedAt),
            tags: note.tags.map(\.name).sorted(),
            images: note.images.sorted(by: { $0.order < $1.order }).map(\.fileName)
        )
    }

    static func exportJSON(notes: [Note]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(notes.map { toDTO(note: $0) })
    }

    static func exportMarkdownZip(notes: [Note], imageService: ImageStorageService) throws -> URL {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("superbrain-export-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withFullDate]

        for note in notes.sorted(by: { $0.createdAt < $1.createdAt }) {
            let dateStr = fmt.string(from: note.createdAt)
            let idPrefix = String(note.id.uuidString.prefix(8))
            var md = note.content + "\n\n"
            if !note.tags.isEmpty {
                md += "**Tags:** " + note.tags.map { "#\($0.name)" }.joined(separator: " ") + "\n"
            }
            md += "**Created:** \(note.createdAt.formatted())\n"

            // 复制图片
            let sortedImages = note.images.sorted(by: { $0.order < $1.order })
            for img in sortedImages {
                let noteImgDir = tmp.appendingPathComponent("images")
                    .appendingPathComponent(note.id.uuidString)
                try? FileManager.default.createDirectory(at: noteImgDir, withIntermediateDirectories: true)
                if let ui = imageService.load(imageID: img.id, noteID: note.id),
                   let data = ui.jpegData(compressionQuality: 0.8) {
                    try? data.write(to: noteImgDir.appendingPathComponent(img.fileName))
                    md += "![\(img.fileName)](images/\(note.id.uuidString)/\(img.fileName))\n"
                }
            }

            let mdURL = tmp.appendingPathComponent("\(dateStr)-\(idPrefix).md")
            try md.write(to: mdURL, atomically: true, encoding: .utf8)
        }

        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("superbrain-\(UUID().uuidString).zip")
        try FileManager.default.zipItem(at: tmp, to: zipURL)
        try? FileManager.default.removeItem(at: tmp)
        return zipURL
    }
}
```

- [ ] **Step 4: 运行测试，确认通过**

```bash
xcodebuild test \
  -scheme Superbrain \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  -only-testing:SuperbrainTests/ExportServiceTests \
  CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "passed|failed"
```

Expected: `Test Suite 'ExportServiceTests' passed`

- [ ] **Step 5: 实现 ExportView（含全部 / 当前筛选 切换）**

```swift
// Superbrain/Views/Export/ExportView.swift
import SwiftUI

struct ExportView: View {
    @Environment(\.dismiss) private var dismiss

    let filteredNotes: [Note]   // 当前时间线筛选结果
    let allNotes: [Note]        // 全部笔记（从 TimelineView 传入）

    private let imageService = ImageStorageService()

    enum ExportFormat: String, CaseIterable {
        case json = "JSON"
        case markdown = "Markdown + 图片 (.zip)"
    }

    enum ExportScope: String, CaseIterable {
        case filtered = "当前筛选结果"
        case all = "全部笔记"
    }

    @State private var format: ExportFormat = .json
    @State private var scope: ExportScope = .all
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var shareURL: URL?
    @State private var showShare = false

    private var notesToExport: [Note] {
        scope == .all ? allNotes : filteredNotes
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("导出范围") {
                    Picker("范围", selection: $scope) {
                        ForEach(ExportScope.allCases, id: \.self) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("导出格式") {
                    Picker("格式", selection: $format) {
                        ForEach(ExportFormat.allCases, id: \.self) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section {
                    Text("将导出 \(notesToExport.count) 条笔记")
                        .foregroundStyle(.secondary)
                }

                if let error = exportError {
                    Section {
                        Text(error).foregroundStyle(.red)
                    }
                }

                Section {
                    Button(action: doExport) {
                        if isExporting {
                            HStack {
                                ProgressView().padding(.trailing, 8)
                                Text("导出中...")
                            }
                        } else {
                            Text("开始导出")
                        }
                    }
                    .disabled(isExporting || notesToExport.isEmpty)
                }
            }
            .navigationTitle("导出")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .sheet(isPresented: $showShare) {
                if let url = shareURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    private func doExport() {
        isExporting = true
        exportError = nil
        Task {
            do {
                let url: URL
                switch format {
                case .json:
                    let data = try ExportService.exportJSON(notes: notesToExport)
                    let tmpURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent("superbrain-\(Int(Date().timeIntervalSince1970)).json")
                    try data.write(to: tmpURL)
                    url = tmpURL
                case .markdown:
                    url = try ExportService.exportMarkdownZip(notes: notesToExport, imageService: imageService)
                }
                await MainActor.run {
                    shareURL = url
                    showShare = true
                    isExporting = false
                }
            } catch {
                await MainActor.run {
                    exportError = error.localizedDescription
                    isExporting = false
                }
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}
```

- [ ] **Step 6: 将 TimelineView 中 ExportView 占位替换为真实实现**

在 `TimelineView.swift` 中，将：
```swift
// Task 11 实现后替换为 ExportView(notes: filteredNotes)
Text("ExportView - coming soon")
```
替换为：
```swift
ExportView(
    filteredNotes: filteredNotes,
    allNotes: (try? modelContext.fetch(FetchDescriptor<Note>())) ?? []
)
```

同时更新 `ExportView` 的初始化签名（见 Step 5 说明）。

- [ ] **Step 7: 编译验证**

```bash
xcodebuild build \
  -scheme Superbrain \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  CODE_SIGNING_ALLOWED=NO | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 8: 提交**

```bash
git add Superbrain/Services/ExportService.swift Superbrain/Views/Export/ SuperbrainTests/ExportServiceTests.swift Superbrain/Views/Timeline/TimelineView.swift
git commit -m "feat: add ExportService (JSON/Markdown zip) and ExportView"
```

---

### Task 12: 全量测试 + 模拟器验证

**Files:** 无新文件

- [ ] **Step 1: 运行全部单元测试**

```bash
xcodebuild test \
  -scheme Superbrain \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "Test Suite|passed|failed"
```

Expected: 全部 3 个测试 Suite 通过（ImageStorageService, PredicateBuilder, ExportService）

- [ ] **Step 2: 在模拟器中验证核心流程**

用 Xcode (Cmd+R) 运行，逐项验证：

```
□ 新建笔记（纯文本）→ 时间线显示
□ 新建笔记（含 Markdown：**加粗** _斜体_）→ 预览模式正确渲染
□ 新建笔记（含 1 张图片）→ 卡片显示图片
□ 新建笔记（含 4 张图片）→ 网格布局正确
□ 新建笔记（含标签）→ TagFilterBar 出现新标签
□ 点击 TagFilterBar 标签 → 时间线过滤
□ 搜索关键词 → 结果正确
□ ⋯ 菜单 → 筛选 → 设置日期范围 → 时间线过滤
□ 点击卡片 → 详情页正确显示
□ 编辑笔记 → 保存 → 历史记录按钮出现
□ 查看历史版本 → 点击预览旧版本
□ 左滑删除笔记 → 孤立标签从 TagFilterBar 消失
□ 详情页删除按钮 → 确认删除
□ 导出 JSON → 系统分享面板打开
□ 导出 Markdown zip → 系统分享面板打开
□ ⋯ 菜单切换深色/浅色模式
```

- [ ] **Step 3: 最终提交**

```bash
git add -A
git commit -m "feat: Superbrain v1.0 — personal timeline notes complete"
```

---

## 常见问题

**Q: `xcodebuild` 找不到模拟器名称**
```bash
xcrun simctl list devices available | grep iPhone
```
使用输出中实际存在的设备名替换命令中的 `iPhone 16`。

**Q: ZIPFoundation SPM 包下载失败**
检查网络，或在 Xcode 中手动 File > Add Package Dependencies 添加：
`https://github.com/weichsel/ZIPFoundation`，最低版本 `0.9.19`。

**Q: SwiftData `@Attribute(.unique)` 在插入重复 Tag 时崩溃**
这是预期行为，表示数据库约束生效。TagInputField 中已通过先查询再插入避免重复。

**Q: NSPredicate `ANY tags.name IN` 在 SwiftData 中不生效**
TimelineView 使用 fetch-all + 内存过滤（`nsPredicate.evaluate(with:)`），这是已知限制的绕过方案。
