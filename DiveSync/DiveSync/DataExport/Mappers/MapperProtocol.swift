//
//  MapperProtocol.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 10/20/25.
//

import Foundation
import GRDB

protocol RowMapper {
    static func from(row: Row) -> [String: Any]
}
