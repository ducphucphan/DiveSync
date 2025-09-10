//
//  IntValueFormatter.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 11/19/24.
//

import DGCharts

class IntValueFormatter: ValueFormatter {
    func stringForValue(_ value: Double, entry: DGCharts.ChartDataEntry, dataSetIndex: Int, viewPortHandler: DGCharts.ViewPortHandler?) -> String {
        return String(Int(value))
    }
}
