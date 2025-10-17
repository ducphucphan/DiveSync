//
//  APIError.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 10/16/25.
//

import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case requestFailed(Error)
    case invalidResponse
    case decodingError(Error)
    case serverError(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .requestFailed(let err):
            return "Request failed: \(err.localizedDescription)"
        case .invalidResponse:
            return "Invalid server response"
        case .decodingError(let err):
            return "Decoding error: \(err.localizedDescription)"
        case .serverError(let code):
            return "Server returned error code: \(code)"
        }
    }
}
