//
//  Utilities.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 11/25/24.
//

import Foundation
import MapKit
import GRDB
import ProgressHUD

func HomeDirectory() -> String {
    return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].path
}

class Utilities {
    static func addFlagAnnotation(to mapView: MKMapView, with gpsString: String) {
        PrintLog("GPS: \(gpsString)")
        // Bước 1: Tách chuỗi GPS thành tọa độ
        let components = gpsString.split(separator: ",").map { String($0) }
        guard components.count == 2,
              let latitude = Double(components[0]),
              let longitude = Double(components[1]) else {
            PrintLog("Chuỗi GPS không hợp lệ")
            return
        }
        
        // Kiểm tra xem tọa độ có phải là vị trí (0, 0)
        if latitude == 0.0 && longitude == 0.0 {
            PrintLog("Tọa độ là zero. Hiển thị vị trí hiện tại.")
            
            // Yêu cầu quyền truy cập vị trí nếu chưa có
            mapView.showsUserLocation = true
            
            // Di chuyển bản đồ đến vị trí hiện tại
            if let userLocation = mapView.userLocation.location {
                let region = MKCoordinateRegion(center: userLocation.coordinate, latitudinalMeters: 1000, longitudinalMeters: 1000)
                mapView.setRegion(region, animated: true)
            } else {
                PrintLog("Không thể lấy vị trí hiện tại.")
            }
            return
        }
        
        // Bước 2: Tạo tọa độ từ chuỗi GPS
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        
        // Bước 3: Tạo annotation
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        annotation.title = "Vị trí đánh dấu"
        annotation.subtitle = "(\(latitude), \(longitude))"
        
        // Bước 4: Thêm annotation vào bản đồ
        mapView.addAnnotation(annotation)
        
        // Bước 5: Di chuyển bản đồ tới vị trí của annotation
        let region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 2000, longitudinalMeters: 2000)
        mapView.setRegion(region, animated: true)
    }
    
    static func convertMinutesToHHmm(_ totalMinutes: Int) -> String {
        let minutes = totalMinutes % 60
        let hours = totalMinutes / 60
        return String(format: "%d:%02d", hours, minutes)
    }
    
    static func formatCoordinateString(latLng: String?) -> String {
        
        guard let input = latLng, !input.isEmpty else {
            return ""
        }
        
        // Split the input string into latitude and longitude components
        let components = input.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        guard components.count == 2,
              let latitude = Double(components[0]),
              let longitude = Double(components[1]) else {
            return "Invalid input"
        }
        
        func convertToDMS(coordinate: Double, positiveDirection: String, negativeDirection: String) -> String {
            let seconds = Int(coordinate * 3600)
            let degrees = seconds / 3600
            var remainingSeconds = abs(seconds % 3600)
            let minutes = remainingSeconds / 60
            let finalSeconds = Double(remainingSeconds % 60) + (coordinate * 3600).truncatingRemainder(dividingBy: 1)
            let direction = degrees >= 0 ? positiveDirection : negativeDirection
            
            return "\(abs(degrees))°\(minutes)'\(String(format: "%.1f", finalSeconds))\"\(direction)"
        }
        
        let latitudeString = convertToDMS(coordinate: latitude, positiveDirection: "N", negativeDirection: "S")
        let longitudeString = convertToDMS(coordinate: longitude, positiveDirection: "E", negativeDirection: "W")
        
        return "\(latitudeString) \(longitudeString)"
    }
    
    static func getLastSyncText(date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd/yy hh:mma"
        dateFormatter.amSymbol = "AM"
        dateFormatter.pmSymbol = "PM"
        
        let formattedDate = dateFormatter.string(from: date)
        return formattedDate
    }
    
    static func coordinateLatString(_ latitude: Float) -> String {
        var latSeconds = Int(latitude * 3600)
        let latDegrees = latSeconds / 3600
        latSeconds = abs(latSeconds % 3600)
        let latMinutes = latSeconds / 60
        latSeconds %= 60
        
        let direction = latDegrees >= 0 ? "N" : "S"
        
        return String(format: "%d°%d'%d\"%@", abs(latDegrees), latMinutes, latSeconds, direction)
    }

    static func coordinateLongString(_ longitude: Float) -> String {
        var longSeconds = Int(longitude * 3600)
        let longDegrees = longSeconds / 3600
        longSeconds = abs(longSeconds % 3600)
        let longMinutes = longSeconds / 60
        longSeconds %= 60
        
        let direction = longDegrees >= 0 ? "E" : "W"
        
        return String(format: "%d°%d'%d\"%@", abs(longDegrees), longMinutes, longSeconds, direction)
    }
    
    static func getDDMMYY(_ date: Date) -> [String] {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        
        let year = (components.year ?? 0) % 2000
        let month = components.month ?? 0
        let day = components.day ?? 0
        
        return ["\(day)", "\(month)", "\(year)"]
    }
    
    static func getDDMMYY(from date: Date) -> (day: Int, month: Int, year: Int){
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        
        let year = (components.year ?? 0) % 2000
        let month = components.month ?? 0
        let day = components.day ?? 0
        
        return (day, month, year)
    }
    
    static func getDateTime(_ date: Date, _ format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format        
        return formatter.string(from: date)
    }
    
    static func convertDateFormat(from input: String, fromFormat: String, toFormat: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = fromFormat
        inputFormatter.locale = Locale(identifier: "en_US_POSIX")

        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = toFormat
        outputFormatter.locale = Locale(identifier: "en_US_POSIX")

        if let date = inputFormatter.date(from: input) {
            return outputFormatter.string(from: date)
        }
        return input
    }
    
    static func getCurrentDateString(format: String) -> String {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: now)
    }
    
    static func optimizeImage(_ image: UIImage, newSize: CGSize) -> UIImage {
        var targetSize = newSize

        if image.size.width > newSize.width || image.size.height > newSize.height {
            let widthRatio = newSize.width / image.size.width
            let heightRatio = newSize.height / image.size.height

            let scaleFactor = min(widthRatio, heightRatio)

            targetSize = CGSize(width: image.size.width * scaleFactor, height: image.size.height * scaleFactor)
        }

        let a = (newSize.width - targetSize.width) / 2.0
        let b = (newSize.height - targetSize.height) / 2.0

        let rect = CGRect(x: a, y: b, width: targetSize.width, height: targetSize.height)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        image.draw(in: rect)
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return resizedImage ?? image
    }

    static func saveSelectedImage(_ object: Any, createImageDate: Date?, dir: String, name: String) -> (String, String) {
                
        // Tạo thư mục chứa ảnh
        let duidFolder = HomeDirectory().appendingFormat("%@", dir) // <-- Bạn cần cung cấp HomeDirectory()
        try? FileManager.default.createDirectory(atPath: duidFolder, withIntermediateDirectories: true, attributes: nil)
        
        let pathOfPhoto = "\(duidFolder)\(name)"
        let pathOfPhotoCache = "\(pathOfPhoto)_\(CACHE)" // CACHE là biến nào đó bạn định nghĩa
        
        // Chuyển object sang UIImage
        var image: UIImage?
        if let data = object as? Data {
            image = UIImage(data: data)
        } else if let img = object as? UIImage {
            image = img
        }
        
        guard let originalImage = image else {
            PrintLog("Invalid image data")
            return ("", "")
        }
        
        /*
        // Xử lý thumbnail
        let newSizeOfPiece = CGSize(width: 80, height: 80)
        let tmpImg = Utilities.optimizeImage(originalImage, newSize: newSizeOfPiece)
        
        if let thumbnailData = tmpImg.pngData() {
            do {
                try thumbnailData.write(to: URL(fileURLWithPath: pathOfPhotoCache))
                PrintLog("Thumbnail saved successfully!")
            } catch {
                PrintLog("Failed to save thumbnail: \(error)")
            }
        }
        */
        
        // Ghi ảnh full size trong background
        if let data = object as? Data {
            try? data.write(to: URL(fileURLWithPath: pathOfPhoto))
        } else {
            let resolution: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 1024 : 480
            let resizedImage = Utilities.optimizeImage(originalImage, newSize: CGSize(width: resolution, height: resolution))
            if let fullImageData = resizedImage.pngData() {
                try? fullImageData.write(to: URL(fileURLWithPath: pathOfPhoto))
            }
        }
        
        return (pathOfPhoto, pathOfPhotoCache)
    }
    
    static func saveOriginalSelectedImage(_ object: Any, createImageDate: Date?, dir: String, name: String) -> (String, String) {
                
        // Tạo thư mục chứa ảnh
        let duidFolder = HomeDirectory().appendingFormat("%@", dir) // <-- Bạn cần cung cấp HomeDirectory()
        try? FileManager.default.createDirectory(atPath: duidFolder, withIntermediateDirectories: true, attributes: nil)
        
        let pathOfPhoto = "\(duidFolder)\(name)"
        let pathOfPhotoCache = "\(pathOfPhoto)_\(CACHE)" // CACHE là biến nào đó bạn định nghĩa
        
        // Chuyển object sang UIImage
        var image: UIImage?
        if let data = object as? Data {
            image = UIImage(data: data)
        } else if let img = object as? UIImage {
            image = img
        }
        
        guard let originalImage = image else {
            PrintLog("Invalid image data")
            return ("", "")
        }
        
        // Ghi ảnh full size trong background
        if let data = object as? Data {
            try? data.write(to: URL(fileURLWithPath: pathOfPhoto))
        } else {
            if let fullImageData = originalImage.jpegData(compressionQuality: 1.0) {
                try? fullImageData.write(to: URL(fileURLWithPath: pathOfPhoto))
            }
        }
        
        return (pathOfPhoto, pathOfPhotoCache)
    }
    
    static func convertRowToMap(_ row: Row) -> [String: String] {
        var result: [String: String] = [:]
        
        for column in row.columnNames {
            let value = row[column]
            if value == nil {
                continue // hoặc: result[column] = "null"
            } else if let str = value as? String {
                result[column] = str
            } else if let int = value as? Int {
                result[column] = String(int)
            } else if let int64 = value as? Int64 {
                result[column] = String(int64)
            } else if let double = value as? Double {
                result[column] = String(double)
            } else if let bool = value as? Bool {
                result[column] = bool ? "true" : "false"
            } else {
                result[column] = "\(value!)" // fallback
            }
        }
        
        return result
    }
    
    static func intValue(at index: Int, from string: String?) -> Int {
        guard let string = string else { return 0 }
            
        let values = string
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        
        guard values.indices.contains(index) else {
            return 0
        }
        
        return values[index]
    }
    
    static func updateValue(in input: String, at index: Int, to newValue: Int) -> String {
        var parts = input.split(separator: ",").map { String($0) }
        
        guard index >= 0 && index < parts.count else {
            return input // Không thay đổi nếu index ngoài phạm vi
        }

        parts[index] = String(newValue)
        return parts.joined(separator: ",")
    }
    
    static func parseTimeToMins(from timeString: String) -> Int {
        let parts = timeString.split(separator: ":")
        guard parts.count == 2,
              let minutes = Int(parts[0]),
              let seconds = Int(parts[1]) else {
            return 0
        }
        return (minutes * 60) + seconds
    }
    
    static func isLastCharacterLetterRegex(_ str: String) -> Bool {
        return str.range(of: "[A-Za-z]\\s*$", options: .regularExpression) != nil
    }
    
    static func fo2GasValue(gasNo: Int, fo2: Int) -> String {
        var gasValue = ""
        if gasNo == 1 && fo2 <= 21 {
            gasValue = "AIR".localized
        } else {
            if fo2 <= 21 {
                gasValue = "AIR".localized
            } else if fo2 == 100 {
                gasValue = "O2".localized
            } else if fo2 > 100 {
                gasValue = OFF.localized
            } else {
                gasValue = String(format: "EAN%d", fo2)
            }
        }
        
        return gasValue
    }
    
    // Share
    static func share(items: [Any], from viewController: UIViewController, sourceView: UIView? = nil) {
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)

        if let popover = activityVC.popoverPresentationController {
            // Với iPad, cần thiết lập sourceView
            popover.sourceView = sourceView ?? viewController.view
            popover.sourceRect = sourceView?.bounds ?? CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = [.any]
        }

        viewController.present(activityVC, animated: true, completion: nil)
    }
    
    static func removeAllBinFiles() {
        let fileManager = FileManager.default
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!

        if let files = try? fileManager.contentsOfDirectory(at: docs, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension == "bin" {
                try? fileManager.removeItem(at: file)
            }
        }
    }
    
    static func firstBinFile() -> URL? {
        let fileManager = FileManager.default
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        if let files = try? fileManager.contentsOfDirectory(at: docs, includingPropertiesForKeys: nil) {
            // Lọc file có đuôi .bin
            let binFiles = files.filter { $0.pathExtension == "bin" }
            // Lấy file đầu tiên nếu có
            return binFiles.first
        }
        
        return nil
    }
    
    static func formatSecondsToHMS(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }
    
    static func to8BitBinaryString(_ value: Int) -> String {
        let v = max(0, min(255, value)) // Giới hạn trong phạm vi 0–255 (1 byte)
        let binary = String(v, radix: 2)
        return String(repeating: "0", count: 8 - binary.count) + binary
    }
    
    static func from8BitBinaryString(_ binaryString: String) -> Int {
        // Kiểm tra chuỗi chỉ gồm '0' hoặc '1' và có độ dài hợp lệ (1–8 ký tự)
        guard binaryString.range(of: "^[01]{1,8}$", options: .regularExpression) != nil else {
            return 0
        }
        return Int(binaryString, radix: 2) ?? 0
    }
    
    ///
    /// Handle share dive
    ///
    @MainActor
    static func handleSharedDive(token: String) {
        Task {
            do {
                ProgressHUD.animate()

                let data = try await APIManager.shared.getDiveData(token: token)
                guard
                    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let status = json["status"] as? String
                else {
                    ProgressHUD.dismiss()
                    return
                }

                guard
                    let rootVC = UIApplication.shared.connectedScenes
                        .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
                        .first
                else {
                    ProgressHUD.dismiss()
                    return
                }

                ProgressHUD.dismiss()
                
                if status == "success" {
                    // Kiểm tra dive trong dive list.
                    if let diveLog = json["DiveLog"] as? [String: Any],
                       let diveProfile = json["DiveProfile"] as? [[String: Any]],
                       let tankData = json["TankData"] as? [[String: Any]] {

                        let modelId = diveLog["ModelID"] as! String
                        let serialNo = diveLog["SerialNo"] as! String
                        let diveNo = diveLog["DiveNoOfDay"] as! String

                        var diveStartLocalTime = diveLog["DiveStartLocalTime"] as! String
                        diveStartLocalTime = Utilities.convertDateFormat(from: diveStartLocalTime, fromFormat: "MM/dd/yyyy HH:mm:ss", toFormat: "dd/MM/yyyy HH:mm:ss")
                        
                        let exists = DatabaseManager.shared.isDuplicateDive(
                            modelId: String(format: "%d", modelIDImport(modelId: modelId.toInt())),
                            serialNo: serialNo,
                            diveNo: diveNo,
                            diveStartLocalTime: diveStartLocalTime
                        )

                        if exists {
                            showAlert(on: rootVC, message: "Dive already exists".localized)
                        } else {
                            showAlert(on: rootVC,
                                      message: "Do you want to import this dive into your log?".localized,
                                      okTitle: "YES".localized,
                                      cancelTitle: "NO".localized,
                                      okHandler: {
                                ProgressHUD.animate()
                                do {
                                    let dbQueue = DatabaseManager.shared.getDatabaseQueue()
                                    try dbQueue.write { db in
                                        let newDiveID = try DiveLogMapper.insert(diveLog, db: db)
                                        print("Inserted DiveLog with DiveID:", newDiveID)

                                        try DiveProfileMapper.bulkInsert(forDiveID: Int(newDiveID), profiles: diveProfile, db: db)
                                        try TankDataMapper.bulkInsert(forDiveID: Int(newDiveID), tankDatas: tankData, db: db)
                                    }
                                    
                                    ProgressHUD.dismiss()
                                    NotificationCenter.default.post(name: .didImportDiveLog, object: nil)
                                    
                                } catch {
                                    ProgressHUD.dismiss()
                                    print("❌ Import failed:", error)
                                    showAlert(on: rootVC, message: "Failed to import dive: \(error.localizedDescription)")
                                }
                            })
                        }
                    }
                } else {
                    showAlert(on: rootVC, message: json["message"] as? String ?? "Unknown error")
                }
            } catch {
                print("❌ Error fetching dive data:", error)
            }
        }
    }
}
