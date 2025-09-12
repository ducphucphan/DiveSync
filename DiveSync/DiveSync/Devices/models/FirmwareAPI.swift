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
        URLSession.shared.dataTask(with: link) { data, _, error in
            if let data = data, let text = String(data: data, encoding: .utf8) {
                completion(text)
            } else {
                completion(nil)
            }
        }.resume()
    }
}
