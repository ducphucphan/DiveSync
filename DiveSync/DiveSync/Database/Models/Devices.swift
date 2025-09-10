import GRDB

struct Devices: Codable, FetchableRecord, PersistableRecord {
    var deviceId: Int64?
    var modelId: Int64?
    var UserID: String?
    var SerialNo: String?
    var ModelName: String?
    var Firmware: String?
    var LastSync: String?
    var OwnerName: String?
    var Identity: String?
    var Battery: String?
    var AddressID: String?
    var Manufacture: String?
    
    static let databaseTableName = "DEVICES"
}

extension Devices: Equatable {
    static func == (lhs: Devices, rhs: Devices) -> Bool {
        return lhs.modelId == rhs.modelId
    }
}
