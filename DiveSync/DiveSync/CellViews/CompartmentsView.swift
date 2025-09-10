//
//  CompartmentsView.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 11/19/24.
//

import UIKit
import DGCharts

class CompartmentsView: UIView {
    
    @IBOutlet weak var barChartView: BarChartView!
    
    var psiGroupIn: String? {
        didSet {
            // Khi psiGroupIn thay đổi, cập nhật dữ liệu biểu đồ
            setupBarChart()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        let nib = UINib(nibName: "CompartmentsView", bundle: nil)
        guard let view = nib.instantiate(withOwner: self, options: nil).first as? UIView else { return }
        view.frame = self.bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.addSubview(view)
    }
    
    func generateChartData() -> [BarChartDataEntry] {
        var entries: [BarChartDataEntry] = []
        
        guard let groupIn = psiGroupIn else { return []}
        
        // Tách chuỗi thành các phần tử số
        let values = groupIn.split(separator: "|").compactMap { Double($0) }
        
        // Tạo BarChartDataEntry từ các giá trị
        for (index, value) in values.enumerated() {
            let entry = BarChartDataEntry(x: Double(index), y: value)
            entries.append(entry)
        }
        
        return entries
    }
    
    func setupBarChart() {
        // Generate data
        let dataEntries = generateChartData()
        
        // Create a BarChartDataSet
        let dataSet = BarChartDataSet(entries: dataEntries, label: "")
        dataSet.colors = [UIColor(hexString: "#5B9696")!]//ChartColorTemplates.material() // Set color palette
        dataSet.valueColors = [.black] // Set value label colors
        dataSet.drawValuesEnabled = true;
        
        // Add dataset to chart data
        let data = BarChartData(dataSet: dataSet)
        data.barWidth = 0.8 // Set bar width
        data.setValueFormatter(IntValueFormatter())
        
        // Configure BarChartView
        barChartView.data = dataEntries.count > 0 ? data : nil
        
        barChartView.xAxis.labelPosition = .bottom
        barChartView.xAxis.granularity = 1 // Ensure one label per entry
        barChartView.xAxis.axisMinimum = -0.5 // Adjust to ensure bars aren't clipped
        barChartView.xAxis.axisMaximum = Double(dataEntries.count) - 0.5
        if dataEntries.count > 0 {
            barChartView.xAxis.valueFormatter = IndexAxisValueFormatter(values: (1...dataEntries.count).map { "\($0)" }) // Custom labels
        }
        barChartView.xAxis.labelCount = dataEntries.count
        barChartView.xAxis.drawGridLinesEnabled = false // Remove gridlines on x-axis
        
        barChartView.leftAxis.axisMinimum = 0 // Minimum value on y-axis
        barChartView.leftAxis.axisMaximum = 50 // Maximum value on y-axis
        barChartView.rightAxis.enabled = false // Disable right axis
        barChartView.legend.enabled = false // Show legend
        
        barChartView.drawValueAboveBarEnabled = true
        barChartView.doubleTapToZoomEnabled = false
        barChartView.highlightPerTapEnabled = false // Disable highlight on tap
        
        // Hide vertical grid lines (X-axis)
        barChartView.xAxis.drawGridLinesEnabled = false
        
        // Hide left axis grid lines
        barChartView.leftAxis.drawGridLinesEnabled = false
        
        if dataEntries.count > 0 {
            barChartView.setVisibleXRange(minXRange: Double(dataEntries.count), maxXRange: Double(dataEntries.count)) // Show all bars
        }
        barChartView.highlightPerDragEnabled = false
    }
    
}
