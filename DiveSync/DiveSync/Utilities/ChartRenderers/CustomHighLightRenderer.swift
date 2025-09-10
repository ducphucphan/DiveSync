//
//  CustomHighLightRenderer.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 12/4/24.
//

import DGCharts
import CoreGraphics
import Foundation
import UIKit

class CustomHighLightRenderer: LineChartRenderer {
    
    override init(dataProvider: LineChartDataProvider, animator: Animator, viewPortHandler: ViewPortHandler) {
        super.init(dataProvider: dataProvider, animator: animator, viewPortHandler: viewPortHandler)
    }
    
    override func drawHighlightLines(context: CGContext, point: CGPoint, set: LineScatterCandleRadarChartDataSetProtocol) {
        guard let chart = dataProvider as? LineChartView else { return }
        
        context.saveGState()
        defer { context.restoreGState() }
        
        // Tùy chỉnh màu và kiểu đường
        context.setStrokeColor(set.highlightColor.cgColor)
        context.setLineWidth(set.highlightLineWidth)
        
        let dashLengths = set.highlightLineDashLengths ?? []
        if !dashLengths.isEmpty {
            context.setLineDash(phase: set.highlightLineDashPhase, lengths: dashLengths)
        } else {
            context.setLineDash(phase: 0, lengths: [])
        }
        
        // Vẽ highlight cho trục X (đường ngang)
        if set.isHorizontalHighlightIndicatorEnabled {
            context.beginPath()
            context.move(to: CGPoint(x: chart.viewPortHandler.contentLeft, y: point.y))
            context.addLine(to: point) // Đến điểm giao
            context.strokePath()
        }
        
        // Vẽ highlight cho trục Y (đường dọc)
        if set.isVerticalHighlightIndicatorEnabled {
            context.beginPath()
            context.move(to: CGPoint(x: point.x, y: chart.viewPortHandler.contentBottom))
            context.addLine(to: point) // Đến điểm giao
            context.strokePath()
        }
    }
}

