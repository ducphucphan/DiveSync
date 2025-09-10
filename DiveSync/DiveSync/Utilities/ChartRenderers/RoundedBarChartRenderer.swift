//
//  RoundedBarChartRenderer.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 12/20/24.
//

import DGCharts
import CoreGraphics
import UIKit

// Custom Renderer for Rounded Bars
class RoundedBarChartRenderer: BarChartRenderer {
    override func drawHighlighted(context: CGContext, indices: [Highlight]) {}
    
    override func drawDataSet(context: CGContext, dataSet: BarChartDataSetProtocol, index: Int) {
        guard let barDataProvider = dataProvider else { return }
        
        let trans = barDataProvider.getTransformer(forAxis: dataSet.axisDependency)
        let phaseY = animator.phaseY
        
        context.saveGState()
        
        for i in 0..<dataSet.entryCount {
            guard let entry = dataSet.entryForIndex(i) as? BarChartDataEntry else { continue }
            
            // Lấy các giá trị stack (yValues)
            let yValues = entry.yValues ?? [entry.y]
            var currentY = 0.0
            
            for (stackIndex, value) in yValues.enumerated() {
                let yStart = currentY
                let yEnd = yStart + value * Double(phaseY)
                currentY = yEnd
                
                var rect = CGRect(x: entry.x - 0.3, y: yStart, width: CGFloat(barDataProvider.barData?.barWidth ?? 0.1), height: yEnd - yStart)
                trans.rectValueToPixel(&rect)
                
                if !viewPortHandler.isInBoundsLeft(rect.maxX) {
                    continue
                }
                
                if !viewPortHandler.isInBoundsRight(rect.minX) {
                    break
                }
                
                // Kiểm tra phần đầu và cuối để áp dụng corner radius
                let bottomCornerRadius: CGFloat = (stackIndex == 0) ? rect.width/2 : 0.0  // Bo tròn cho phần dưới cùng (stack đầu)
                let topCornerRadius: CGFloat = (stackIndex == yValues.count - 1) ? rect.width/2 : 0.0 // Bo tròn cho phần trên cùng (stack cuối)
                
                // Vẽ phần dưới cùng (stack đầu)
                if stackIndex == 0 {
                    let pathBottom = UIBezierPath(roundedRect: rect, byRoundingCorners: [.bottomLeft, .bottomRight], cornerRadii: CGSize(width: bottomCornerRadius, height: bottomCornerRadius))
                    context.addPath(pathBottom.cgPath)
                    context.setFillColor(dataSet.color(atIndex: stackIndex).cgColor)
                    context.fillPath()
                }
                
                // Vẽ phần trên cùng (stack cuối)
                if stackIndex == yValues.count - 1 {
                    let pathTop = UIBezierPath(roundedRect: rect, byRoundingCorners: [.topLeft, .topRight], cornerRadii: CGSize(width: topCornerRadius, height: topCornerRadius))
                    context.addPath(pathTop.cgPath)
                    context.setFillColor(dataSet.color(atIndex: stackIndex).cgColor)
                    context.fillPath()
                }
                
                // Vẽ các phần giữa stack mà không có bo tròn
                if stackIndex != 0 && stackIndex != yValues.count - 1 {
                    context.addRect(rect)
                    context.setFillColor(dataSet.color(atIndex: stackIndex).cgColor)
                    context.fillPath()
                }
            }
        }
        
        context.restoreGState()
    }
}
