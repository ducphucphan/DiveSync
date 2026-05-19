//
//  FirmwareAPI.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 9/11/25.
//

import Foundation

final class FirmwareAPI {
    static func fetchText(from url: String, completion: @escaping (String?) -> Void) {
        guard let link = URL(string: url) else {
            completion(nil)
            return
        }
        URLSession.shared.dataTask(with: link) { data, response, error in
                // 1. Kiểm tra lỗi kết nối hoặc phản hồi từ server
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode), // Chỉ chấp nhận mã 2xx (Thành công)
                      let data = data,
                      error == nil else {
                    
                    // Nếu statusCode là 404 hoặc các lỗi khác, trả về nil
                    completion(nil)
                    return
                }
                
                // 2. Chuyển đổi data thành String
                if let text = String(data: data, encoding: .utf8) {
                    completion(text)
                } else {
                    completion(nil)
                }
            }.resume()
    }
}
