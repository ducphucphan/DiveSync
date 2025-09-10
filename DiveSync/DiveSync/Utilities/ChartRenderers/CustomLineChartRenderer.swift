//
//  CustomLineChartRenderer.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 12/4/24.
//

import DGCharts
import CoreGraphics
import Foundation
import UIKit

class CustomLineChartRenderer: LineChartRenderer {
    var notesEntries: [ChartDataEntry] = []
    
    init(dataProvider: LineChartDataProvider, animator: Animator, viewPortHandler: ViewPortHandler, notesEntries: [ChartDataEntry]) {
        self.notesEntries = notesEntries
        super.init(dataProvider: dataProvider, animator: animator, viewPortHandler: viewPortHandler)
    }
    
    override func drawExtras(context: CGContext) {
        super.drawExtras(context: context)
        
        guard let dataProvider = dataProvider else { return }
        let transformer = dataProvider.getTransformer(forAxis: .left)
        
        for entry in notesEntries {
            let pixelPoint = transformer.pixelForValues(x: entry.x, y: entry.y)
            
            // Vẽ text hoặc hình ảnh tại vị trí chỉ định
            drawCustomContent(at: pixelPoint, context: context, entry: entry)
        }
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
    
    private func drawCustomContent(at position: CGPoint, context: CGContext, entry: ChartDataEntry) {
        // Vẽ text
//        if let note = entry.data as? String {
//            let attributes: [NSAttributedString.Key: Any] = [
//                .font: UIFont.systemFont(ofSize: 12),
//                .foregroundColor: UIColor.black
//            ]
//            note.draw(at: CGPoint(x: position.x, y: position.y - 20), withAttributes: attributes)
            
//            UIImage(named: "notes")!.draw(in: CGRect(x: position.x-18, y: position.y-20, width: 20, height: 20))
        
        if let image = UIImage(systemName: "mappin")?.withTintColor(.red, renderingMode: .alwaysOriginal) {
            //image.draw(in: CGRect(x: position.x-18, y: position.y-20, width: 20, height: 20))
        }
            
//        }
        
        // Vẽ hình ảnh (nếu có)
//        if let imageName = entry.data as? String, let image = UIImage(named: imageName) {
//            image.draw(in: CGRect(x: position.x - 10, y: position.y - 30, width: 20, height: 20))
//        }
    }
}

