import GRDB

struct Users: Codable, FetchableRecord, PersistableRecord {
    var user_id: Int64?
    var login_id: String?
    var password: String?
    var firebase_token: String?
    var status: Int64?
    var age: Int64?
    var gender: Int64?
    var height: Double?
    var weight: Double?
    var create_date: String?
    var update_date: String?

    static let databaseTableName = "USERS"
}
