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
