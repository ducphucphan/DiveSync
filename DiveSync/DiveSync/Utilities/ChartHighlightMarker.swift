//
//  ChartHighlightMarker.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 11/23/24.
//

import UIKit
import DGCharts

class CustomHighLightMarkerView: MarkerView {
    var circleRadius: CGFloat = 3.0
    var borderWidth: CGFloat = 1.0
    var borderColor: UIColor = .darkGray
    var fillColor: UIColor = .white
    var shadowColor: UIColor = .red
    var shadowOffset: CGSize = CGSize(width: 0, height: 0)
    
    override func draw(context: CGContext, point: CGPoint) {
        
        // Vẽ bóng đổ
        if shadowOffset != CGSizeZero {
            context.setShadow(offset: shadowOffset, blur: 3, color: shadowColor.cgColor)
        }
        
        // Vẽ viền (border)
        context.setStrokeColor(borderColor.cgColor) // Màu của viền
        context.setLineWidth(borderWidth)
        context.addArc(center: point, radius: circleRadius, startAngle: 0, endAngle: CGFloat.pi * 2, clockwise: true)
        context.strokePath()
        
        // Vẽ màu nền (fill)
        context.setFillColor(fillColor.cgColor) // Màu của fill
        context.addArc(center: point, radius: circleRadius - borderWidth / 2, startAngle: 0, endAngle: CGFloat.pi * 2, clockwise: true)
        context.fillPath()
    }
    
    // Các phương thức để tùy chỉnh thuộc tính của MarkerView (nếu cần)
    func setCircleRadius(_ radius: CGFloat) {
        self.circleRadius = radius
    }
    
    func setBorderWidth(_ width: CGFloat) {
        self.borderWidth = width
    }
    
    func setBorderColor(_ color: UIColor) {
        self.borderColor = color
    }
    
    func setFillColor(_ color: UIColor) {
        self.fillColor = color
    }
    
    func setShadowColor(_ color: UIColor) {
        self.shadowColor = color
    }
    
    func setShadowOffset(_ offset: CGSize) {
        self.shadowOffset = offset
    }
}

