//
//  APIRequest.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 10/16/25.
//

import Foundation

struct APIRequest {
    let path: String
    let method: HTTPMethod
    let parameters: [String: Any]?
    let isFormEncoded: Bool   // 👈 dùng để biết body gửi dạng JSON hay form-urlencoded
    
    // ➕ Thêm các thuộc tính phục vụ Multipart Form-Data
    let fileData: Data?
    let fileName: String?
    let fileKey: String?
    let mimeType: String
    
    init(
        path: String,
        method: HTTPMethod = .GET,
        parameters: [String: Any]? = nil,
        isFormEncoded: Bool = false,    // 👈 mặc định là false (tức là gửi JSON)
        fileData: Data? = nil,          // 👈 Mặc định nil cho các request thường
        fileName: String? = nil,
        fileKey: String? = nil,
        mimeType: String = "text/plain"
    ) {
        self.path = path
        self.method = method
        self.parameters = parameters
        self.isFormEncoded = isFormEncoded
        self.fileData = fileData
        self.fileName = fileName
        self.fileKey = fileKey
        self.mimeType = mimeType
    }
}
