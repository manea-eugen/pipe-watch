import Foundation

struct GitLabProject: Codable, Identifiable, Sendable, Hashable {
    let id: Int
    let name: String
    let nameWithNamespace: String
    let pathWithNamespace: String
    let webURL: String
    let lastActivityAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case nameWithNamespace = "name_with_namespace"
        case pathWithNamespace = "path_with_namespace"
        case webURL = "web_url"
        case lastActivityAt = "last_activity_at"
    }
}

struct GitLabUser: Codable, Sendable {
    let id: Int
    let username: String
    let name: String
    let avatarURL: String?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case name
        case avatarURL = "avatar_url"
    }
}
