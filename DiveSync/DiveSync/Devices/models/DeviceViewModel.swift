//
//  DeviceViewModel.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 4/10/25.
//

import Foundation
import RxSwift
import RxCocoa

// Models/CellModel.swift
struct CellModel {
    let title: String
    let value: String
}

// ViewModels/DeviceViewModel.swift
class DeviceViewModel {
    let cellData: BehaviorRelay<[CellModel]> = BehaviorRelay(value: [])

    init(infos: [(String, String)]) {
        let items = infos.map { key, value in
            CellModel(title: key, value: value)
        }
        cellData.accept(items)
    }
}
