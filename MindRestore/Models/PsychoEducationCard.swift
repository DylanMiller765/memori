import Foundation

struct PsychoEducationCard: Identifiable, Codable {
    let id: UUID
    let title: String
    let body: String
    let categoryRaw: String
    var isRead: Bool
    let sortOrder: Int

    var category: EduCategory {
        EduCategory(rawValue: categoryRaw) ?? .techniques
    }

    init(title: String, body: String, category: EduCategory, sortOrder: Int) {
        self.id = UUID()
        self.title = title
        self.body = body
        self.categoryRaw = category.rawValue
        self.isRead = false
        self.sortOrder = sortOrder
    }
}
