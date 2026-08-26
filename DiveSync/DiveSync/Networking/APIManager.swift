//
//  APIManager.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 10/16/25.
//

import Foundation

final class APIManager {
    static let shared = APIManager()
    private init() {}
    
    // ⚙️ Cấu hình URL gốc của API
    private let baseURL = "https://divesync.io"
    
    // MARK: - Gửi Request
    func sendRequest<T: Decodable>(
        _ request: APIRequest,
        responseType: T.Type
    ) async throws -> T {
        
        guard let url = URL(string: baseURL + request.path) else {
            throw APIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        
        // Gửi body nếu là POST/PUT
        if let params = request.parameters {
            urlRequest.httpBody = try? JSONSerialization.data(withJSONObject: params)
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        // (Tùy chọn) Thêm token nếu có
        // urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw APIError.serverError(httpResponse.statusCode)
            }
            
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.requestFailed(error)
        }
    }
}

extension APIManager {
    func sendRawRequest(_ request: APIRequest) async throws -> Data {
        guard let url = URL(string: baseURL + request.path) else {
            throw APIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        
        // ⚙️ Encode body theo kiểu
        if let params = request.parameters {
            if request.isFormEncoded {
                // 🔹 Trường hợp đặc biệt: server chỉ nhận `data={json}`
                let jsonData = try JSONSerialization.data(withJSONObject: params)
                let jsonString = String(data: jsonData, encoding: .utf8)!
                let bodyString = "data=\(jsonString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)"
                
                urlRequest.httpBody = bodyString.data(using: .utf8)
                
                // ⚠️ KHÔNG set Content-Type, hoặc nếu muốn:
                // urlRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            } else {
                // 🔹 Dạng chuẩn JSON
                urlRequest.httpBody = try JSONSerialization.data(withJSONObject: params)
                urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        }
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        //print("⬅️ Response Code:", httpResponse.statusCode)
        //print("⬅️ Response Body:", String(data: data, encoding: .utf8) ?? "<no body>")
        
        return data
    }

}

extension APIManager {
    /// 📦 Lấy dữ liệu dive theo token chia sẻ
    func getDiveData(token: String) async throws -> Data {
        let request = APIRequest(
            path: "/get_dive_data.php",
            method: .POST,
            parameters: ["token": token],
            isFormEncoded: false
        )
        
        let data = try await sendRawRequest(request)
        return data
    }
}

extension APIManager {
    
    /// 📤 Gửi request dạng Multipart Form Data (dành cho API update firmware kèm logFile)
    func uploadMultipart(_ request: APIRequest) async throws -> Data {
        guard let url = URL(string: baseURL + request.path) else {
            throw APIError.invalidURL
        }
        
        let boundary = "Boundary-\(UUID().uuidString)"
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // 1. Thêm các tham số chuỗi (deviceInfo)
        if let params = request.parameters {
            for (key, value) in params {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
                body.append("\(value)\r\n".data(using: .utf8)!)
            }
        }
        
        // 2. Thêm file log (nếu có)
        if let fileData = request.fileData,
           let fileName = request.fileName,
           let fileKey = request.fileKey {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(fileKey)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(request.mimeType)\r\n\r\n".data(using: .utf8)!)
            body.append(fileData)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        urlRequest.httpBody = body
        
        // 3. Thực hiện Request
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(httpResponse.statusCode)
        }
        
        return data
    }
}

extension APIManager {
    /// 🚀 API Cập nhật firmware thiết bị và gửi file log nếu có lỗi
    func updateFirmware(
        deviceInfo: [String: Any],
        logFilePath: String?,
        status: String
    ) async throws -> Data {
        
        var logFileData: Data? = nil
        var logFileName: String? = nil
        
        // 🛑 Chỉ đọc file log khi status là "ERROR"
        if status == "ERROR", let logPath = logFilePath, !logPath.isEmpty {
            let logURL = URL(fileURLWithPath: logPath)
            if FileManager.default.fileExists(atPath: logURL.path) {
                logFileData = try? Data(contentsOf: logURL)
                logFileName = logURL.lastPathComponent
            }
        }
        
        let request = APIRequest(
            path: "/firmware_update_status.php", // Thay đúng endpoint API của bạn
            method: .POST,
            parameters: deviceInfo,
            fileData: logFileData,
            fileName: logFileName,
            fileKey: "LogFile",
            mimeType: "text/plain"
        )
        
        return try await uploadMultipart(request)
    }
}
