//
//  Logger.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 8/25/25.
//

import Foundation

class Logger {
    static let shared = Logger()
    
    private let fileName = "divesync.log"
    private let fileURL: URL
    
    private init() {
        let fileManager = FileManager.default
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        self.fileURL = urls.first!.appendingPathComponent(fileName)
        
        // 👉 Xoá log cũ khi app start
        /*
        if fileManager.fileExists(atPath: fileURL.path) {
            try? fileManager.removeItem(at: fileURL)
        }
        */
        
        // 👉 Xoá log nếu quá 24h
        if let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path),
           let creationDate = attrs[.creationDate] as? Date {
            
            let now = Date()
            if now.timeIntervalSince(creationDate) > 24 * 60 * 60 {
                try? fileManager.removeItem(at: fileURL)
            }
        }
    }
    
    /// Ghi log ra console và file
    func log(_ message: Any?,
             function: String = #function,
             file: String = #file,
             line: Int = #line) {
        
        // Convert mọi kiểu về String
        let stringMessage = message.map { "\($0)" } ?? "nil"
        
        // Thêm timestamp + vị trí gọi
        let timestamp = Self.dateFormatter.string(from: Date())
        let fileName = (file as NSString).lastPathComponent
        let fullMessage = "[\(timestamp)] [\(fileName):\(line)] \(function) → \(stringMessage)"
        
        // In ra console
        print(fullMessage)
        
        // Ghi vào file
        writeToFile(fullMessage)
    }
    
    /// Xem log file path
    func logFilePath() -> String {
        return fileURL.path
    }
    
    /// Xoá file log thủ công (nếu cần)
    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    private func writeToFile(_ message: String) {
        let logWithNewline = message + "\n"
        if FileManager.default.fileExists(atPath: fileURL.path) {
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                handle.seekToEndOfFile()
                if let data = logWithNewline.data(using: .utf8) {
                    handle.write(data)
                }
                handle.closeFile()
            }
        } else {
            try? logWithNewline.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }
    
    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return df
    }()
}

/// 👉 Global function
func PrintLog(_ message: Any?,
              function: String = #function,
              file: String = #file,
              line: Int = #line) {
    Logger.shared.log(message, function: function, file: file, line: line)
}
