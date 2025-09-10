//
//  LogGasCell.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 5/10/25.
//

import UIKit
import GRDB

class LogGasCell: UITableViewCell {

    @IBOutlet weak var gasNoLb: UILabel!
    //@IBOutlet weak var fo2ValueLb: UILabel!
    @IBOutlet weak var fo2ValueBt: UIButton!
    @IBOutlet weak var consmLb: UILabel!
    @IBOutlet weak var psiValueLb: UILabel!
    @IBOutlet weak var po2Lb: UILabel!
    @IBOutlet weak var maxPO2ValueLb: UILabel!
    
    var diveLog: Row!
    var manualDive = false
    var gasNo = 1
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    func bindValueAt(row: Int, fromDiveLog: Row) {
        gasNo = (row + 1)
        
        gasNoLb.text = String(format: "Gas %d", gasNo)
        psiValueLb.text = ""
        
        let mixes = fromDiveLog.stringValue(key: "EnabledMixes").toInt()
        
        var mixesEnabled: [Bool] = []
        for i in 0..<8 {
            mixesEnabled.append((mixes & (1 << i)) != 0)
        }
        
        let fo2 = fromDiveLog.stringValue(key: "Mix\(gasNo)Fo2Percent").toInt()
        let po2 = fromDiveLog.stringValue(key: "Mix\(gasNo)PpO2Barx100").toInt()
        
        maxPO2ValueLb.text = String(format: "%d.%02d", po2/100, po2%100)
        
        if mixesEnabled[gasNo] == false {
            po2Lb.isHidden = true
            maxPO2ValueLb.isHidden = true
        } else {
            po2Lb.isHidden = false
            maxPO2ValueLb.isHidden = false
        }
        
        fo2ValueBt.setTitle(Utilities.fo2GasValue(gasNo: gasNo, fo2: fo2), for: .normal)
        if mixesEnabled[gasNo] == false {
            fo2ValueBt.setTitle(OFF, for: .normal)
        }
        
        let diveMode = fromDiveLog.stringValue(key: "DiveMode").toInt()
        if diveMode >= 100 {
            manualDive = true
        }
        
        diveLog = fromDiveLog
    }
    
    @IBAction func fo2Tapped(_ sender: Any) {
        if manualDive == false {return}
        
        var mixes = diveLog.stringValue(key: "EnabledMixes").toInt()
        
        var opts: [String] = []

        if gasNo == 2 || gasNo == 3 {
            opts.append(OFF)
        }
        
        // Thêm Air
        opts.append("AIR")
        
        // Thêm EAN22 -> EAN99
        let eanValues = (22...99).map { "EAN\($0)" }
        opts.append(contentsOf: eanValues)

        // Thêm O2
        opts.append("O2")
        
        ItemSelectionAlert.showMessage(
            message: String(format: "Gas %i", gasNo),
            options: opts,
            selectedValue: fo2ValueBt.title(for: .normal)
        ) { [weak self] action, value, index in
            guard let self = self else { return }
            
            self.fo2ValueBt.setTitle(value, for: .normal)
            
            if let value = value {
                var fo2Save = 0
                if value == OFF {
                    fo2Save = 21
                } else if value == "AIR" {
                    fo2Save = 21
                } else if value == "O2" {
                    fo2Save = 100
                } else {
                    fo2Save = value.toInt()
                }
                
                if value == OFF {
                    mixes &= ~(1 << gasNo)
                } else {
                    mixes |= (1 << gasNo)
                }
                
                self.diveLog = DatabaseManager.shared.updateTableAndReturnRow(tableName: "DiveLog",
                                                                              params: ["EnabledMixes": mixes],
                                                                              conditions: "where DiveID=\(self.diveLog.intValue(key: "DiveID"))")
                
                self.diveLog = DatabaseManager.shared.updateTableAndReturnRow(tableName: "DiveLog",
                                                                              params: ["Mix\(gasNo)Fo2Percent": fo2Save],
                                                                              conditions: "where DiveID=\(self.diveLog.intValue(key: "DiveID"))")
                
                self.bindValueAt(row: gasNo-1, fromDiveLog: self.diveLog)
            }
        }
        
    }
}
