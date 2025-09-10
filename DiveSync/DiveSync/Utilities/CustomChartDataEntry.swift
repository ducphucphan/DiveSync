//
//  CustomChartDataEntry.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 12/2/24.
//

import DGCharts

class CustomChartDataEntry: ChartDataEntry {
    var rotationAngleX: Float
    var rotationAngleY: Float

    init(x: Double, y: Double, rotationAngleX: Float, rotationAngleY: Float) {
        self.rotationAngleX = rotationAngleX
        self.rotationAngleY = rotationAngleY
        super.init(x: x, y: y)
    }
    
    required init() {
        fatalError("init() has not been implemented")
    }
}

