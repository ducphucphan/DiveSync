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

    init(
        path: String,
        method: HTTPMethod = .GET,
        parameters: [String: Any]? = nil,
        isFormEncoded: Bool = false     // 👈 mặc định là false (tức là gửi JSON)
    ) {
        self.path = path
        self.method = method
        self.parameters = parameters
        self.isFormEncoded = isFormEncoded
    }
}
