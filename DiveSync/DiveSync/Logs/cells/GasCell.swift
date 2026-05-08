//
//  GasCell.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 5/5/26.
//

import UIKit
import GRDB

protocol GasCellDelegate: AnyObject {
    func gasCell(_ cell: GasCell, didUpdateStartPressure pressure: Double, tankId: Int, at index: Int)
    func gasCell(_ cell: GasCell, didUpdateEndPressure pressure: Double, tankId: Int, at index: Int)
}

class GasCell: UICollectionViewCell {
    
    // MARK: - Outlets
    @IBOutlet weak var tankBackgroundImageView: UIImageView!
    @IBOutlet weak var contentContainer: UIView! // Lớp Mask (Mũi tên đỏ)
    
    // Các lớp màu
    @IBOutlet weak var startView: UIView!
    @IBOutlet weak var endView: UIView!
    
    // Constraints để điều chỉnh độ cao
    @IBOutlet weak var startHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var endHeightConstraint: NSLayoutConstraint!
    
    // Pin và Labels
    @IBOutlet weak var startPinView: UIView! // start pin group view
    @IBOutlet weak var endPinView: UIView!   // end pin group view
    
    @IBOutlet weak var startPsiValueLb: UILabel!
    @IBOutlet weak var endPsiValueLb: UILabel!
    
    @IBOutlet weak var gasNumberLabel: UILabel!
    @IBOutlet weak var o2Label: UILabel!
    
    @IBOutlet weak var startLabel: UILabel!
    @IBOutlet weak var endLabel: UILabel!

    weak var delegate: GasCellDelegate?
    
    private var cellIndex: Int = 0
    private var currentTankId: Int = 0
    private let maxPressure: Double = 4000.0
    private var currentStartPressure: Double = 0
    private var currentEndPressure: Double = 0
    private var unitOfDive: Int = 0
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Đảm bảo phần màu không tràn ra ngoài thân bình
        
        startLabel.text = "START".localized
        endLabel.text = "END".localized
        
        contentContainer.clipsToBounds = true
        setupGestures()
    }
    
    private func setupGestures() {
        let startPan = UIPanGestureRecognizer(target: self, action: #selector(handleStartPan(_:)))
        startPinView.addGestureRecognizer(startPan)
        startPinView.isUserInteractionEnabled = true
        
        let endPan = UIPanGestureRecognizer(target: self, action: #selector(handleEndPan(_:)))
        endPinView.addGestureRecognizer(endPan)
        endPinView.isUserInteractionEnabled = true
    }
    
    @objc private func handleStartPan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: contentContainer)
        let totalHeight = contentContainer.frame.height
        
        // Tính toán pressure dựa trên tọa độ Y (Y=0 ở đỉnh, Y=totalHeight ở đáy)
        // Vì view của bạn bám đáy (Bottom), nên tỉ lệ nghịch:
        var newPressure = Double((totalHeight - location.y) / totalHeight) * maxPressure
        
        // Giới hạn (Constraints)
        newPressure = min(maxPressure, max(currentEndPressure, newPressure))
        
        currentStartPressure = newPressure
        updateUIForPressure()
        
        if gesture.state == .ended {
            delegate?.gasCell(self, didUpdateStartPressure: currentStartPressure, tankId: currentTankId, at: cellIndex)
        }
    }
    
    private func updateUIForPressure() {
        let totalHeight = contentContainer.frame.height
        startHeightConstraint.constant = CGFloat(currentStartPressure / maxPressure) * totalHeight
        endHeightConstraint.constant = CGFloat(currentEndPressure / maxPressure) * totalHeight
        
        // Cập nhật Label text
        let startStr = (unitOfDive == M) ? formatNumber(convertPSI2BAR(currentStartPressure)) : formatNumber(currentStartPressure, decimalIfNeeded: 0)
        let endStr = (unitOfDive == M) ? formatNumber(convertPSI2BAR(currentEndPressure)) : formatNumber(currentEndPressure, decimalIfNeeded: 0)
        
        let unitStr = (unitOfDive == M) ? "BAR" : "PSI"
        startPsiValueLb.text = "\(startStr) \(unitStr)"
        endPsiValueLb.text = "\(endStr) \(unitStr)"
        
        self.layoutIfNeeded()
    }
    
    @objc private func handleEndPan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: contentContainer)
        let totalHeight = contentContainer.frame.height
        
        var newPressure = Double((totalHeight - location.y) / totalHeight) * maxPressure
        
        // Giới hạn (Constraints): end <= start và end >= 0
        newPressure = min(currentStartPressure, max(0, newPressure))
        
        currentEndPressure = newPressure
        updateUIForPressure()
        
        if gesture.state == .ended {
            delegate?.gasCell(self, didUpdateEndPressure: currentEndPressure, tankId: currentTankId, at: cellIndex)
        }
    }

    func configure(with diveLog: Row, tankData: Row?, index: Int, numberOfGas: Int) {
        // 1. Gán các biến cơ sở
        self.cellIndex = index
        let gasNo = index + 1
        self.unitOfDive = diveLog.stringValue(key: "Units").toInt()
        
        // 2. Xử lý hiển thị số thứ tự Gas
        gasNumberLabel.text = "\(gasNo)"
        if numberOfGas == 1 {
            gasNumberLabel.text = ""
        }
        
        // 3. Xử lý Logic Mixes (O2 %)
        let mixes = diveLog.stringValue(key: "EnabledMixes").toInt()
        var mixesEnabled: [Bool] = []
        for i in 0..<8 {
            mixesEnabled.append((mixes & (1 << i)) != 0)
        }
        
        var fo2 = 0
        // Lấy FO2 dựa trên gasNo (Index + 1)
        switch gasNo {
        case 1: fo2 = diveLog.stringValue(key: "Mix1Fo2Percent").toInt()
        case 2: fo2 = diveLog.stringValue(key: "Mix2Fo2Percent").toInt()
        case 3: fo2 = diveLog.stringValue(key: "Mix3Fo2Percent").toInt()
        case 4: fo2 = diveLog.stringValue(key: "Mix4Fo2Percent").toInt()
        default: break
        }
        
        // Kiểm tra trạng thái Enabled của Gas
        let isEnabledByMask = (gasNo <= mixesEnabled.count) ? mixesEnabled[gasNo-1] : false
        let isEnabledByFo2 = fo2 >= 21
        let isGasEnabled = isEnabledByMask || isEnabledByFo2
        
        o2Label.text = "\(fo2)% O2"
        // Bạn có thể chỉnh alpha hoặc isHidden dựa trên isGasEnabled nếu muốn
        //self.contentView.alpha = isGasEnabled ? 1.0 : 0.5

        // 4. Xử lý dữ liệu Áp suất (Pressure)
        if let tankData = tankData {
            self.currentTankId = tankData.intValue(key: "TankID")
            self.currentStartPressure = tankData.stringValue(key: "StartPressure").toDouble()
            self.currentEndPressure = tankData.stringValue(key: "EndPressure").toDouble()
        } else {
            // Giá trị mặc định nếu không có dữ liệu tank
            self.currentStartPressure = 3000.0
            self.currentEndPressure = 500.0
        }
        
        // 5. Cập nhật giao diện (Chiều cao cột màu và Label)
        updateUIForPressure()
        
        // 6. Hiệu ứng mượt mà khi load (Tùy chọn)
        UIView.animate(withDuration: 0.3) {
            self.layoutIfNeeded()
        }
    }
}
