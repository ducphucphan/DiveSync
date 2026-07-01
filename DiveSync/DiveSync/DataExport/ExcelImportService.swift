//
//  ExcelImportService.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 6/16/26.
//

import Foundation
import CoreXLSX

class ExcelImportService {
    
    /// Đọc file Excel và parse thành cấu trúc JSON chuẩn tương tự cấu trúc từ Server gửi về
    static func parseDiveExcel(fileURL: URL) -> [String: Any]? {
        // Khởi tạo đối tượng XLSXFile an toàn theo cấu trúc bản mới
        guard let file = XLSXFile(filepath: fileURL.path) else {
            print("❌ Không thể mở hoặc định dạng sai file Excel.")
            return nil
        }
        
        var diveLogDict: [String: Any] = [:]
        var tankDataList: [[String: Any]] = []
        var diveProfileList: [[String: Any]] = []
        
        do {
            // Lấy danh sách Workbooks, Shared Strings và Worksheet Paths
            let workbooks = try file.parseWorkbooks()
            let sharedStrings = try file.parseSharedStrings()
            let worksheetPaths = try file.parseWorksheetPaths()
            
            // Lấy workbook đầu tiên để truyền vào hàm tìm tên sheet
            guard let firstWorkbook = workbooks.first else {
                print("❌ File Excel không chứa Workbook nào.")
                return nil
            }
            
            // Tìm chính xác đường dẫn file dựa vào tên hiển thị của Sheet
            // CoreXLSX map: workbook.sheets.items chứa tên hiển thị (.name) và thứ tự tương ứng với worksheetPaths
            func findPath(forSheetName name: String) -> String? {
                let sheetItems = firstWorkbook.sheets.items
                
                // Tìm vị trí của sheet có tên mong muốn
                if let index = sheetItems.firstIndex(where: { $0.name == name }), index < worksheetPaths.count {
                    return worksheetPaths[index]
                }
                return nil
            }
            
            // --- 1. PARSE SHEET: DIVE LOG ---
            if let path = findPath(forSheetName: "DiveLog") {
                let worksheet = try file.parseWorksheet(at: path)
                
                if let worksheetData = worksheet.data, !worksheetData.rows.isEmpty {
                    let rows = worksheetData.rows
                    if rows.count > 1 {
                        let headerRow = rows[0]
                        let valueRow = rows[1]
                        
                        // Tạo bảng map từ Tên cột (A, B, C...) sang Tên Key của Header
                        var headerMap: [String: String] = [:]
                        for cell in headerRow.cells {
                            let columnName = cell.reference.column.value // Trả về "A", "B", "C"...
                            let key = cellValue(cell: cell, sharedStrings: sharedStrings)
                            if !key.isEmpty { headerMap[columnName] = key }
                        }
                        
                        // Duyệt từng ô thực tế và ánh xạ dựa vào tọa độ cột để tránh lệch khi có ô trống
                        for cell in valueRow.cells {
                            let columnName = cell.reference.column.value
                            if let key = headerMap[columnName] {
                                let value = cellValue(cell: cell, sharedStrings: sharedStrings)
                                diveLogDict[key] = value
                            }
                        }
                    }
                }
            }
            
            // --- 2. PARSE SHEET: TANK DATA ---
            if let path = findPath(forSheetName: "TankData") {
                let worksheet = try file.parseWorksheet(at: path)
                if let worksheetData = worksheet.data, !worksheetData.rows.isEmpty {
                    let rows = worksheetData.rows
                    if rows.count > 1 {
                        let headerRow = rows[0]
                        
                        // Tạo bảng map tọa độ cột cho bảng TankData
                        var headerMap: [String: String] = [:]
                        for cell in headerRow.cells {
                            let columnName = cell.reference.column.value
                            let key = cellValue(cell: cell, sharedStrings: sharedStrings)
                            if !key.isEmpty { headerMap[columnName] = key }
                        }
                        
                        for rowIndex in 1..<rows.count {
                            let valueRow = rows[rowIndex]
                            var tankDict: [String: Any] = [:]
                            
                            for cell in valueRow.cells {
                                let columnName = cell.reference.column.value
                                if let key = headerMap[columnName] {
                                    let value = cellValue(cell: cell, sharedStrings: sharedStrings)
                                    tankDict[key] = value
                                }
                            }
                            if !tankDict.isEmpty {
                                tankDataList.append(tankDict)
                            }
                        }
                    }
                }
            }
            
            // --- 3. PARSE SHEET: DIVE PROFILE ---
            if let path = findPath(forSheetName: "DiveProfile") {
                let worksheet = try file.parseWorksheet(at: path)
                if let worksheetData = worksheet.data, !worksheetData.rows.isEmpty {
                    let rows = worksheetData.rows
                    if rows.count > 1 {
                        let headerRow = rows[0]
                        
                        // Tạo bảng map tọa độ cột cho bảng DiveProfile
                        var headerMap: [String: String] = [:]
                        for cell in headerRow.cells {
                            let columnName = cell.reference.column.value
                            let key = cellValue(cell: cell, sharedStrings: sharedStrings)
                            if !key.isEmpty { headerMap[columnName] = key }
                        }
                        
                        for rowIndex in 1..<rows.count {
                            let valueRow = rows[rowIndex]
                            var profileDict: [String: Any] = [:]
                            
                            for cell in valueRow.cells {
                                let columnName = cell.reference.column.value
                                if let key = headerMap[columnName] {
                                    let value = cellValue(cell: cell, sharedStrings: sharedStrings)
                                    profileDict[key] = value
                                }
                            }
                            if !profileDict.isEmpty {
                                diveProfileList.append(profileDict)
                            }
                        }
                    }
                }
            }
            
            // Đóng gói thành định dạng JSON đồng bộ hoàn toàn với cấu trúc Server API
            var resultJson: [String: Any] = [:]
            resultJson["status"] = "success"
            resultJson["DiveLog"] = diveLogDict
            resultJson["TankData"] = tankDataList
            resultJson["DiveProfile"] = diveProfileList
            
            return resultJson
            
        } catch {
            print("❌ Lỗi cấu trúc CoreXLSX: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Helper giải mã giá trị của Ô dữ liệu chính xác theo luật CoreXLSX
    private static func cellValue(cell: Cell, sharedStrings: SharedStrings?) -> String {
        if let sharedStrings = sharedStrings {
            return cell.stringValue(sharedStrings) ?? cell.value ?? ""
        }
        return cell.value ?? ""
    }
    
    /// Kiểm tra file xem có chứa sheet ẩn định danh hợp lệ hay không
    static func validateDiveSyncFile(fileURL: URL) -> Bool {
        guard let file = XLSXFile(filepath: fileURL.path) else { return false }
        
        do {
            let workbooks = try file.parseWorkbooks()
            let sharedStrings = try file.parseSharedStrings()
            let worksheetPaths = try file.parseWorksheetPaths()
            
            guard let firstWorkbook = workbooks.first else { return false }
            let sheetItems = firstWorkbook.sheets.items
            
            // 1. Tìm vị trí của sheet định danh
            if let index = sheetItems.firstIndex(where: { $0.name == "_DiveSync_Metadata" }), index < worksheetPaths.count {
                let path = worksheetPaths[index]
                let worksheet = try file.parseWorksheet(at: path)
                
                guard let worksheetData = worksheet.data, worksheetData.rows.count >= 2 else { return false }
                
                let rows = worksheetData.rows
                let row1 = rows[0] // Chứa A1, B1
                let row2 = rows[1] // Chứa A2, B2
                
                var isAppValid = false
                var isFileTypeValid = false
                
                // Kiểm tra B1 (Hàng 1, Cột B)
                if let b1Cell = row1.cells.first(where: { $0.reference.column.value == "B" }) {
                    let b1Value = cellValue(cell: b1Cell, sharedStrings: sharedStrings)
                    if b1Value == "DiveSync" { isAppValid = true }
                }
                
                // Kiểm tra B2 (Hàng 2, Cột B)
                if let b2Cell = row2.cells.first(where: { $0.reference.column.value == "B" }) {
                    let b2Value = cellValue(cell: b2Cell, sharedStrings: sharedStrings)
                    if b2Value == "DiveLogExport" { isFileTypeValid = true }
                }
                
                return isAppValid && isFileTypeValid
            }
        } catch {
            print("❌ Lỗi kiểm tra Metadata file: \(error.localizedDescription)")
        }
        
        return false
    }
}
