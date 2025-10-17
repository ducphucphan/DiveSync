//
//  DatabaseManager.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 11/12/24.
//

import GRDB
import Foundation

struct DiveStatistics {
    let mostVisitedDiveSpot: String?
    let totalNumberOfDives: Int
    let totalDiveTime: Int
    let averageDiveTime: Int
    let maxDepthFT: Double
    let averageDepthFT: Double
    let minTempF: Double
    let maxTempF: Double
    let averageTempF: Double
}

struct DiveSpot: Codable, FetchableRecord, PersistableRecord {
    let id: Int?
    let spot_name: String?
    let country: String?
    let latitude: String
    let longitude: String
    
    static let databaseTableName = "divespot"
}

class DatabaseManager {
    // Singleton instance
    static let shared = DatabaseManager()
    
    // Database queue
    private var dbQueue: DatabaseQueue?
    
    // Private initializer to enforce singleton
    public init() {
        do {
            self.dbQueue = try setupDatabase()
        } catch {
            fatalError("Database setup failed: \(error)")
        }
    }
    
    // Set up the database connection
    private func setupDatabase() throws -> DatabaseQueue {
        let databaseURL = try FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("divesync.db")
        
        PrintLog("Database path: \(databaseURL.path)")
        
        // Check if the database exists in the document directory
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: databaseURL.path) {
            // Database doesn't exist, copy from the bundle
            guard let bundleDatabaseURL = Bundle.main.url(forResource: "divesync", withExtension: "db") else {
                throw NSError(domain: "AqualungError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Database file not found in the bundle."])
            }
            
            do {
                try fileManager.copyItem(at: bundleDatabaseURL, to: databaseURL)
                PrintLog("Database copied from bundle to: \(databaseURL.path)")
            } catch {
                throw NSError(domain: "AqualungError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to copy the database from the bundle."])
            }
        }
        
        let dbQueue = try DatabaseQueue(path: databaseURL.path)
        
        // ✅ Thêm bước migration tại đây
        try performMigrations(on: dbQueue)
        
        return dbQueue
    }
    
    private func performMigrations(on dbQueue: DatabaseQueue) throws {
        var migrator = DatabaseMigrator()
        
        // ⚙️ Trong quá trình phát triển có thể dùng:
        // migrator.eraseDatabaseOnSchemaChange = true
        // nhưng đừng bật trong production vì sẽ xóa toàn bộ dữ liệu
        
        /*
        // 🔹 Migration 1: thêm cột mới
        migrator.registerMigration("v1_add_column_to_DiveLog") { db in
            // Ví dụ: thêm cột DiveRating nếu chưa có
            if try !db.columns(in: "DiveLog").contains(where: { $0.name == "DiveRating" }) {
                try db.alter(table: "DiveLog") { t in
                    t.add(column: "DiveRating", .integer).defaults(to: 0)
                }
            }
        }

        // 🔹 Migration 2: thêm bảng mới
        migrator.registerMigration("v2_create_table_SyncHistory") { db in
            if try !db.tableExists("SyncHistory") {
                try db.create(table: "SyncHistory") { t in
                    t.autoIncrementedPrimaryKey("id")
                    t.column("DeviceID", .integer).notNull()
                    t.column("SyncTime", .datetime).notNull()
                    t.column("Status", .text)
                }
            }
        }
        
        // 🔹 Migration 3: thay đổi kiểu dữ liệu hoặc thêm index
        migrator.registerMigration("v3_add_index_to_DiveLog") { db in
            try db.create(index: "idx_DiveLog_SerialNo_ModelID", on: "DiveLog", columns: ["SerialNo", "ModelID"])
        }
        */
        try migrator.migrate(dbQueue)
    }
    
    // Public accessor to the database queue
    func getDatabaseQueue() -> DatabaseQueue {
        guard let dbQueue = dbQueue else {
            fatalError("DatabaseQueue is not initialized")
        }
        return dbQueue
    }
}

extension DatabaseManager {
    func fetchData(from table: String, where condition: String? = nil, arguments: [DatabaseValueConvertible] = []) throws -> [Row] {
        try DatabaseManager.shared.getDatabaseQueue().read { db in
            let sql = condition != nil
                ? "SELECT * FROM \(table) WHERE \(condition!)"
                : "SELECT * FROM \(table)"
            return try Row.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))
        }
    }
    
    func fetchDiveLog(where condition: String? = nil, 
                      arguments: [DatabaseValueConvertible] = [],
                      sort: SortOptions? = nil) throws -> [Row] {
        /*
         Ngay cả khi bản ghi trong Devices hoặc DeviceSettings không tồn tại, bằng cách dùng LEFT JOIN thay vì JOIN. Đồng thời, bạn có thể sử dụng COALESCE() để trả về giá trị mặc định cho UnitOfUsed
         */
        try DatabaseManager.shared.getDatabaseQueue().read { db in
            var sql = """
                    SELECT
                        dl.*,
                        spot.Spot_Name AS SpotName
                    FROM
                        DiveLog dl
                    LEFT JOIN
                        DiveSpot spot ON dl.DiveSiteID = spot.id
                    """
            if let condition = condition {
                sql += " WHERE \(condition)"
            }
            
             if sort?.favoritesOnly == true {
                 if condition == nil {
                     sql += " WHERE dl.IsFavorite = 1"
                 } else {
                     sql += " AND dl.IsFavorite = 1"
                 }
             }
            
            // ✅ Append ORDER BY
            if let sort = sort {
                let direction = (sort.direction == .increasing) ? "ASC" : "DESC"
                
                let field: String
                switch sort.field {
                case .date:
                    // DiveStartLocalTime là text dạng "dd/MM/yyyy HH:mm:ss" cần dùng strftime
                    field = "strftime('%Y-%m-%d %H:%M:%S', substr(DiveStartLocalTime, 7, 4) || '-' || substr(DiveStartLocalTime, 4, 2) || '-' || substr(DiveStartLocalTime, 1, 2) || ' ' || substr(DiveStartLocalTime, 12))"
                case .maxDepth:
                    field = "CAST(MaxDepthFT AS REAL)"
                case .diveTime:
                    field = "CAST(TotalDiveTime AS INTEGER)"
                }
                
                sql += " ORDER BY \(field) \(direction)"
            }
            
            return try Row.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))
        }
    }
    
    func fetchDevices(nameKeys: [String]? = nil) -> [Devices]? {
        let dbQueue = DatabaseManager.shared.getDatabaseQueue()
        
        do {
            return try dbQueue.read { db in
                if let keys = nameKeys, !keys.isEmpty {
                    let placeholders = keys.map { _ in "?" }.joined(separator: ", ")
                    let sql = "SELECT * FROM DEVICES WHERE Identity IN (\(placeholders))"
                    return try Devices.fetchAll(db, sql: sql, arguments: StatementArguments(keys))
                } else {
                    let sql = "SELECT * FROM DEVICES"
                    return try Devices.fetchAll(db, sql: sql)
                }
            }
        } catch {
            PrintLog("Failed to fetch data: \(error)")
            return []
        }
    }
    
    func isExistDevice(modelId: Int, serialNo: Int) -> Bool {
        let dbQueue = DatabaseManager.shared.getDatabaseQueue()
        var exists = false

        do {
            try dbQueue.read { db in
                let existingRow = try Row.fetchOne(db, sql: "SELECT * FROM Devices WHERE ModelID = ? AND SerialNo = ?", arguments: [modelId, serialNo])
                if existingRow != nil {
                    exists = true
                }
            }
        } catch {
            PrintLog("Failed to query DEVICES: \(error)")
        }

        return exists
    }
    
    func lastDevicID(modelId: Int, serialNo: Int) -> Int {
        var deviceID = 0
        
        let dbQueue = DatabaseManager.shared.getDatabaseQueue()
        do {
            try dbQueue.read { db in
                let sql = """
                    SELECT
                        COALESCE(
                            (SELECT DeviceID FROM Devices WHERE SerialNo = ? AND ModelID = ?),
                            (SELECT IFNULL((SELECT seq FROM sqlite_sequence WHERE name = 'Devices'), 0) + 1)
                        ) AS DeviceID
                """
                
                let row = try Row.fetchOne(db, sql: sql, arguments: [serialNo, modelId])
                deviceID = row?["DeviceID"] ?? 0
            }
        } catch {
            PrintLog("Failed to query DEVICES: \(error)")
        }
        return deviceID
    }
    
    func isExistDiveLog(diveNo: Int, modelId: Int, serialNo: Int) -> Bool {
        let dbQueue = DatabaseManager.shared.getDatabaseQueue()
        var exists = false
        do {
            try dbQueue.read { db in
                let row = try Row.fetchOne(
                    db,
                    sql: "SELECT 1 FROM DiveLog WHERE DiveNo = ? AND ModelID = ? AND SerialNo = ? LIMIT 1",
                    arguments: [diveNo, modelId, serialNo]
                )
                exists = (row != nil)
            }
        } catch {
            PrintLog("Failed to query DiveLog: \(error)")
        }

        return exists
    }
    
    func insertDCSettingsIfNotExist(dcID: Int, dcSerialNo: Int) {
        let dbQueue = DatabaseManager.shared.getDatabaseQueue()
        
        do {
            try dbQueue.write { db in
                let existingRow = try Row.fetchOne(db, sql: "SELECT * FROM DC_SETTINGS WHERE DCID = ? AND DCSERIALNO = ?", arguments: [dcID, dcSerialNo])
                
                if existingRow == nil {
                    try db.execute(sql: "INSERT INTO DC_SETTINGS (DCID, DCSERIALNO) VALUES (?, ?)", arguments: [dcID, dcSerialNo])
                }
            }
        } catch {
            PrintLog("Failed to insert or update DC_SETTINGS: \(error)")
        }
    }
    
    func saveDeviceSettings(modelId: Int, serialNo: Int, dcSettings: [String: Any]) {
        let dbQueue = DatabaseManager.shared.getDatabaseQueue()
        
        do {
            try dbQueue.write { db in
                // 1. Tìm DeviceID
                let sqlDeviceID = """
                    SELECT
                        COALESCE(
                            (SELECT DeviceID FROM Devices WHERE SerialNo = ? AND modelId = ?),
                            (SELECT IFNULL(MAX(DeviceID), 0) + 1 FROM Devices)
                        ) AS DeviceID
                """
                let deviceID = try Int.fetchOne(db, sql: sqlDeviceID, arguments: [serialNo, modelId]) ?? 0
                
                // 2. Kiểm tra tồn tại trong DeviceSettings
                let exists = try Bool.fetchOne(
                    db,
                    sql: "SELECT EXISTS(SELECT 1 FROM DeviceSettings WHERE DeviceID = ?)",
                    arguments: [deviceID]
                ) ?? false
                
                if exists {
                    // 3. Update
                    var sql = "UPDATE DeviceSettings SET "
                    let updates = dcSettings.map { "\($0.key) = ?" }.joined(separator: ", ")
                    sql += updates
                    
                    let conditions = "WHERE DeviceID = \(deviceID)"
                    sql += " \(conditions)"
                    
                    let arguments = StatementArguments(dcSettings.map { $0.value }) ?? StatementArguments()
                    
                    try db.execute(sql: sql, arguments: arguments)
                } else {
                    // 4. Insert
                                        
                    let keys = dcSettings.keys.joined(separator: ", ")
                    let valuesPlaceholder = dcSettings.keys.map { _ in "?" }.joined(separator: ", ")
                    
                    let sql = "INSERT INTO DeviceSettings (\(keys)) VALUES (\(valuesPlaceholder))"
                    
                    let arguments: [DatabaseValueConvertible] = dcSettings.values.map { value in
                        if let dateValue = value as? Date {
                            return dateValue.timeIntervalSince1970 // Chuyển `Date` thành timestamp
                        } else if let convertible = value as? DatabaseValueConvertible {
                            return convertible
                        } else {
                            return "\(value)" // Chuyển thành chuỗi nếu không phải kiểu tương thích
                        }
                    }
                    
                    try db.execute(sql: sql, arguments: StatementArguments(arguments))
                }
            }
        } catch {
            PrintLog("❌ Failed to save DeviceSettings: \(error)")
        }
    }
    
    func saveGasSettings(dcGasSettings: [String: Any]) {
        guard let deviceID = dcGasSettings["DeviceID"] as? Int else {
            PrintLog("❌ DeviceID missing or invalid")
            return
        }
        
        let dbQueue = DatabaseManager.shared.getDatabaseQueue()
        
        do {
            try dbQueue.write { db in
                // 2. Kiểm tra tồn tại trong DeviceSettings
                let exists = try Bool.fetchOne(
                    db,
                    sql: "SELECT EXISTS(SELECT 1 FROM DeviceGasMixesSettings WHERE DeviceID = ?)",
                    arguments: [deviceID]
                ) ?? false
                
                if exists {
                    // 3. Update
                    var sql = "UPDATE DeviceGasMixesSettings SET "
                    let updates = dcGasSettings.map { "\($0.key) = ?" }.joined(separator: ", ")
                    sql += updates
                    
                    let conditions = "WHERE DeviceID = \(deviceID)"
                    sql += " \(conditions)"
                    
                    let arguments = StatementArguments(dcGasSettings.map { $0.value }) ?? StatementArguments()
                    
                    try db.execute(sql: sql, arguments: arguments)
                } else {
                    // 4. Insert
                                        
                    let keys = dcGasSettings.keys.joined(separator: ", ")
                    let valuesPlaceholder = dcGasSettings.keys.map { _ in "?" }.joined(separator: ", ")
                    
                    let sql = "INSERT INTO DeviceGasMixesSettings (\(keys)) VALUES (\(valuesPlaceholder))"
                    
                    let arguments: [DatabaseValueConvertible] = dcGasSettings.values.map { value in
                        if let dateValue = value as? Date {
                            return dateValue.timeIntervalSince1970 // Chuyển `Date` thành timestamp
                        } else if let convertible = value as? DatabaseValueConvertible {
                            return convertible
                        } else {
                            return "\(value)" // Chuyển thành chuỗi nếu không phải kiểu tương thích
                        }
                    }
                    
                    try db.execute(sql: sql, arguments: StatementArguments(arguments))
                }
            }
        } catch {
            PrintLog("❌ Failed to save DeviceSettings: \(error)")
        }
    }

    func saveDiveData(diveData: [String: Any]) -> (existed: Bool, diveID: Int64?) {
        guard let diveNo = diveData["DiveNo"] as? Int,
              let modelId = diveData["ModelID"] as? Int,
              let serialNo = diveData["SerialNo"] as? Int else {
            PrintLog("❌ DiveNo / ModelID / SerialNo missing or invalid")
            return (false, nil)
        }
        
        let dbQueue = DatabaseManager.shared.getDatabaseQueue()
        
        do {
            var existed = false
            var diveID: Int64?
            
            try dbQueue.write { db in
                if let existingID = try Int64.fetchOne(
                    db,
                    sql: "SELECT DiveID FROM DiveLog WHERE DiveNo = ? AND ModelID = ? AND SerialNo = ?",
                    arguments: [diveNo, modelId, serialNo]
                ) {
                    // ✅ Đã tồn tại → trả về DiveID hiện có
                    diveID = existingID
                    existed = true
                } else {
                    // ✅ Chưa có → thêm mới
                    let keys = diveData.keys.joined(separator: ", ")
                    let placeholders = diveData.keys.map { _ in "?" }.joined(separator: ", ")
                    
                    let sql = "INSERT INTO DiveLog (\(keys)) VALUES (\(placeholders))"
                    
                    let arguments: [DatabaseValueConvertible] = diveData.keys.compactMap { key in
                        let value = diveData[key]!
                        if let date = value as? Date {
                            return date.timeIntervalSince1970
                        } else if let convertible = value as? DatabaseValueConvertible {
                            return convertible
                        } else {
                            return "\(value)"
                        }
                    }
                    
                    try db.execute(sql: sql, arguments: StatementArguments(arguments))
                    diveID = db.lastInsertedRowID
                    existed = false
                }
            }
            
            return (existed, diveID)
        } catch {
            PrintLog("❌ Failed to save DiveLog: \(error)")
            return (false, nil)
        }
    }
    
    func saveDiveProfile(profile: [String: Any]) {
        let dbQueue = DatabaseManager.shared.getDatabaseQueue()
        
        do {
            try dbQueue.write { db in
                let keys = profile.keys.joined(separator: ", ")
                let valuesPlaceholder = profile.keys.map { _ in "?" }.joined(separator: ", ")
                
                let sql = "INSERT INTO DiveProfile (\(keys)) VALUES (\(valuesPlaceholder))"
                
                let arguments: [DatabaseValueConvertible] = profile.values.map { value in
                    if let dateValue = value as? Date {
                        return dateValue.timeIntervalSince1970
                    } else if let convertible = value as? DatabaseValueConvertible {
                        return convertible
                    } else {
                        return "\(value)"
                    }
                }
                
                try db.execute(sql: sql, arguments: StatementArguments(arguments))
            }
        } catch {
            PrintLog("❌ Failed to save DiveProfile: \(error)")
        }
    }
    
    func runSQL(_ sql: String, arguments: [DatabaseValueConvertible] = []) -> [[String: Any]]? {
        let dbQueue = DatabaseManager.shared.getDatabaseQueue()
        
        do {
            return try dbQueue.read { db in
                let trimmed = sql.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if trimmed.hasPrefix("select") {
                    let rows = try Row.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))
                    var results: [[String: Any]] = []
                    
                    for row in rows {
                        var dict: [String: Any?] = [:]
                        for columnName in row.columnNames {
                            let dbValue: DatabaseValue = row[columnName] // ép kiểu rõ ràng
                            let key = columnName.lowercased()
                            if dbValue.isNull {
                                dict[key] = Optional<Any>.none
                            } else if let intVal = Int.fromDatabaseValue(dbValue) {
                                dict[key] = intVal
                            } else if let doubleVal = Double.fromDatabaseValue(dbValue) {
                                dict[key] = doubleVal
                            } else if let boolVal = Bool.fromDatabaseValue(dbValue) {
                                dict[key] = boolVal
                            } else if let stringVal = String.fromDatabaseValue(dbValue) {
                                dict[key] = stringVal
                            } else if let dateVal = Date.fromDatabaseValue(dbValue) {
                                dict[key] = dateVal
                            } else {
                                dict[key] = dbValue.description
                            }
                        }
                        results.append(dict)
                    }
                    return results
                } else {
                    try db.execute(sql: sql, arguments: StatementArguments(arguments))
                    return nil
                }
            }
        } catch {
            PrintLog("Failed to execute SQL: \(error)")
            return nil
        }
    }
    
    func insertIntoTable(tableName: String, params: [String: Any], conditions: String? = nil) -> Bool {
        let dbQueue = DatabaseManager.shared.getDatabaseQueue()
        
        do {
            try dbQueue.write { db in
                guard !params.isEmpty else { return }
                
                let keys = params.keys.joined(separator: ", ")
                let valuesPlaceholder = params.keys.map { _ in "?" }.joined(separator: ", ")
                
                var sql = "INSERT INTO \(tableName) (\(keys)) VALUES (\(valuesPlaceholder))"
                
                if let conditions = conditions, !conditions.isEmpty {
                    sql += " \(conditions)"
                }
                
                let arguments: [DatabaseValueConvertible] = params.values.map { value in
                    if let dateValue = value as? Date {
                        return dateValue.timeIntervalSince1970 // Chuyển `Date` thành timestamp
                    } else if let convertible = value as? DatabaseValueConvertible {
                        return convertible
                    } else {
                        return "\(value)" // Chuyển thành chuỗi nếu không phải kiểu tương thích
                    }
                }
                
                try db.execute(sql: sql, arguments: StatementArguments(arguments))
            }
            return true
        } catch {
            PrintLog("Failed to insert into \(tableName): \(error)")
            return false
        }
    }
    
    func updateTable(tableName: String, params: [String: Any], conditions: String? = nil) {
        let dbQueue = DatabaseManager.shared.getDatabaseQueue()
        
        do {
            try dbQueue.write { db in
                var sql = "UPDATE \(tableName) SET "
                let updates = params.map { "\($0.key) = ?" }.joined(separator: ", ")
                sql += updates
                
                if let conditions = conditions {
                    sql += " \(conditions)"
                }
                
                let arguments = StatementArguments(params.map { $0.value }) ?? StatementArguments()
                try db.execute(sql: sql, arguments: arguments)
            }
        } catch {
            PrintLog("Failed to update table \(tableName): \(error)")
        }
    }
    
    func updateTableAndReturnRow(tableName: String, params: [String: Any], conditions: String? = nil) -> Row? {
        let dbQueue = DatabaseManager.shared.getDatabaseQueue()
        var updatedRow: Row? = nil
        
        do {
            try dbQueue.write { db in
                // 1. UPDATE
                var sql = "UPDATE \(tableName) SET "
                let updates = params.map { "\($0.key) = ?" }.joined(separator: ", ")
                sql += updates
                
                if let conditions = conditions {
                    sql += " \(conditions)"
                }
                
                let arguments = StatementArguments(params.map { $0.value }) ?? StatementArguments()
                try db.execute(sql: sql, arguments: arguments)
                
                // 2. SELECT lại row sau khi update
                if let conditions = conditions {
                    let selectSQL = "SELECT * FROM \(tableName) \(conditions) LIMIT 1"
                    updatedRow = try Row.fetchOne(db, sql: selectSQL)
                }
            }
        } catch {
            PrintLog("Failed to update and fetch row from \(tableName): \(error)")
        }
        
        return updatedRow
    }
    
    func deleteRows(from table: String, where condition: String? = nil, arguments: [DatabaseValueConvertible] = []) {
        let dbQueue = DatabaseManager.shared.getDatabaseQueue()
        
        do {
            try dbQueue.write { db in
                let sql: String
                if let condition = condition, !condition.isEmpty {
                    sql = "DELETE FROM \(table) WHERE \(condition)"
                } else {
                    sql = "DELETE FROM \(table)"
                }
                try db.execute(sql: sql, arguments: StatementArguments(arguments))
            }
        } catch {
            PrintLog("Failed to delete rows from \(table): \(error)")
        }
    }
    
    // MARK: - Statistics
    func fetchDiveStatistics() throws -> DiveStatistics {
        let dbQueue = DatabaseManager.shared.getDatabaseQueue()
        
        return try dbQueue.read { db in
            let row = try Row.fetchOne(db, sql: """
                SELECT
                        (
                            SELECT ds.spot_name
                            FROM DiveLog dl2
                            JOIN divespot ds ON dl2.DiveSiteID = ds.id
                            GROUP BY dl2.DiveSiteID
                            ORDER BY COUNT(*) DESC
                            LIMIT 1
                        ) AS MostVisitedDiveSpot,
                        COUNT(*) AS TotalNumberOfDives,
                        SUM(CAST(TotalDiveTime AS INTEGER)) AS TotalDiveTime,
                        ROUND(AVG(CAST(TotalDiveTime AS INTEGER))) AS AverageDiveTime,
                        MAX(CAST(MaxDepthFT AS REAL)) AS MaxDepthFT,
                        ROUND(AVG(CAST(AvgDepthFT AS REAL))) AS AvgDepthFT,
                        MIN(CAST(MinTemperatureF AS REAL)) AS MinTempF,
                        MAX(CAST(MaxTemperatureF AS REAL)) AS MaxTempF,
                        ROUND(AVG((CAST(MinTemperatureF AS REAL) + CAST(MaxTemperatureF AS REAL)) / 2)) AS AvgTempF
                    FROM DiveLog
            """)!
            
            return DiveStatistics(
                mostVisitedDiveSpot: row["MostVisitedDiveSpot"],
                totalNumberOfDives: row["TotalNumberOfDives"] ?? 0,
                totalDiveTime: row["TotalDiveTime"] ?? 0,
                averageDiveTime: row["AverageDiveTime"] ?? 0,
                maxDepthFT: row["MaxDepthFT"] ?? 0.0,
                averageDepthFT: row["AvgDepthFT"] ?? 0.0,
                minTempF: row["MinTempF"] ?? 0.0,
                maxTempF: row["MaxTempF"] ?? 0.0,
                averageTempF: row["AvgTempF"] ?? 0.0
            )
        }
    }
    
    func fetchDiveSpotsWithLogs() throws -> [DiveSpot] {
        let dbQueue = DatabaseManager.shared.getDatabaseQueue()

        return try dbQueue.read { db in
            try DiveSpot.fetchAll(db, sql: """
                SELECT DISTINCT ds.*
                FROM divespot ds
                JOIN DiveLog dl ON dl.DiveSiteID = ds.id
            """)
        }
    }
    
    /// Lấy ra record trong TankData theo TankNo và DiveID.
    /// Nếu chưa tồn tại, tạo mới rồi trả về record đó.
    func fetchOrCreateTankData(tankNo: Int, diveId: Int) -> Row? {
        let dbQueue = DatabaseManager.shared.getDatabaseQueue()
        var resultRow: Row? = nil
        
        do {
            try dbQueue.write { db in
                // 1️⃣ Kiểm tra record có tồn tại chưa
                resultRow = try Row.fetchOne(
                    db,
                    sql: "SELECT * FROM TankData WHERE TankNo = ? AND DiveID = ? LIMIT 1",
                    arguments: [tankNo, diveId]
                )
                
                // 2️⃣ Nếu chưa có → thêm mới
                if resultRow == nil {
                    try db.execute(
                        sql: "INSERT INTO TankData (TankNo, DiveID) VALUES (?, ?)",
                        arguments: [tankNo, diveId]
                    )
                    
                    // 3️⃣ Lấy lại record vừa tạo
                    resultRow = try Row.fetchOne(
                        db,
                        sql: "SELECT * FROM TankData WHERE TankNo = ? AND DiveID = ? LIMIT 1",
                        arguments: [tankNo, diveId]
                    )
                }
            }
        } catch {
            PrintLog("❌ fetchOrCreateTankData failed: \(error)")
        }
        
        return resultRow
    }
}

extension DatabaseManager {
    func exportDiveDataDictionary(diveID: Int) -> [String: Any]? {
        let dbQueue = DatabaseManager.shared.getDatabaseQueue()
        
        do {
            return try dbQueue.read { db -> [String: Any]? in
                // 1️⃣ Lấy DiveLog
                guard let diveLogRow = try Row.fetchOne(
                    db,
                    sql: "SELECT * FROM DiveLog WHERE DiveID = ?",
                    arguments: [diveID]
                ) else {
                    PrintLog("❌ Không tìm thấy DiveLog với DiveID = \(diveID)")
                    return nil
                }
                
                let excludeDiveLog = ["DiveID", "DiveNo", "IsFavorite", "Water", "Sound", "Light", "Language"]
                let diveLogDict = diveLogRow.toDictionary(excluding: excludeDiveLog)
                
                // 2️⃣ Lấy danh sách DiveProfile
                let diveProfiles = try Row.fetchAll(
                    db,
                    sql: "SELECT * FROM DiveProfile WHERE DiveID = ? ORDER BY RowID ASC",
                    arguments: [diveID]
                ).map { $0.toDictionary() }
                
                // 3️⃣ Lấy danh sách TankData
                let tankData = try Row.fetchAll(
                    db,
                    sql: "SELECT * FROM TankData WHERE DiveID = ? ORDER BY TankID ASC",
                    arguments: [diveID]
                ).map { $0.toDictionary() }
                
                // 4️⃣ Gom lại thành dictionary
                let jsonBody: [String: Any] = [
                    "DiveLog": diveLogDict,
                    "DiveProfile": diveProfiles,
                    "TankData": tankData
                ]
                
                return jsonBody
            }
        } catch {
            PrintLog("❌ exportDiveDataDictionary failed: \(error)")
            return nil
        }
    }
}
