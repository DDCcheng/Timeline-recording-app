// Superbrain/Utilities/PredicateBuilder.swift
import Foundation

/// 构建 NSPredicate 用于 Note 查询。
/// 说明：SwiftData #Predicate 不支持 ANY 语义的关系遍历，
/// 统一使用 NSPredicate，在 TimelineView 中 fetch-all 后内存过滤。
final class PredicateBuilder {
    private var predicates: [NSPredicate] = []

    @discardableResult
    func withText(_ text: String) -> Self {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return self }
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
        predicates.append(NSPredicate(format: "ANY tags.name IN %@", Array(tagNames) as CVarArg))
        return self
    }

    func build() -> NSPredicate? {
        guard !predicates.isEmpty else { return nil }
        return predicates.count == 1
            ? predicates[0]
            : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }
}
