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
    
    var StatsLastLogId: String?
    var StatsLogTotalDives: String?
    var StatsTotalDiveSecond: String?
    var StatsMaxDepthFT: String?
    var StatsAvgDepthFT: String?
    var StatsMinTemperatureF: String?
    var StatsMaxAltitudeLevel: String?
    
    var Units: String?
    
    static let databaseTableName = "DEVICES"
}

extension Devices: Equatable {
    static func == (lhs: Devices, rhs: Devices) -> Bool {
        return lhs.modelId == rhs.modelId
    }
}
