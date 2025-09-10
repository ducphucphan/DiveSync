//
//  SetTimeAlert.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 6/9/25.
//

import UIKit

enum TimeFormat {
    case ampm
    case hour24
}

final class SetTimeAlert: UIViewController {
    
    // MARK: - IBOutlets
    @IBOutlet private weak var containerView: UIView!
    @IBOutlet private weak var messageLabel: UILabel!
    @IBOutlet private weak var allowButton: UIButton!
    @IBOutlet private weak var denyButton: UIButton!
    
    @IBOutlet private weak var amButton: UIButton!
    @IBOutlet private weak var pmButton: UIButton!
    
    @IBOutlet weak var pickerViewLeft: UIPickerView!
    
    @IBOutlet weak var pickerViewRight: UIPickerView!
    
    private var hourOptions: [String] = []
    private var minOptions: [String] = []
        
    private var selectedLeft = 0
    private var selectedRight = 0
    
    private var completionWithValue: ((_ action: PrivacyAlertAction, _ selectedValue: String?) -> Void)?
    private var allowTitle: String = "SET"
    private var denyTitle: String = "CANCEL"
    
    private var hourValue: String?
    private var minValue: String?
    
    var isAM = true
    
    // MARK: - Initializer
    static func showMessage(hourValue: String?,
                            minValue: String?,
                            allowTitle: String = "SET",
                            denyTitle: String = "CANCEL",
                            completion: @escaping (_ action: PrivacyAlertAction, _ selectedValue: String?) -> Void ) {
        guard let topVC = UIApplication.shared.topMostViewController(),
              let alert = UIStoryboard(name: "Utils", bundle: nil)
            .instantiateViewController(withIdentifier: "SetTimeAlert") as? SetTimeAlert else {
            return
        }
        
        alert.hourValue = hourValue
        alert.minValue = minValue
        alert.allowTitle = allowTitle
        alert.denyTitle = denyTitle
        alert.completionWithValue = completion
        alert.modalPresentationStyle = .overFullScreen
        alert.modalTransitionStyle = .crossDissolve
        topVC.present(alert, animated: true)
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        
        // Picker
        pickerViewLeft.dataSource = self
        pickerViewLeft.delegate = self
        
        pickerViewRight.dataSource = self
        pickerViewRight.delegate = self
        
        containerView.backgroundColor = UIColor.B_3
        containerView.layer.cornerRadius = 16
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        initializeTimeOptions(format: .ampm)     // Cho AM/PM
        
        // Convert selectedValue to selectedIndex if needed
        if let _hourValue = hourValue, let index = hourOptions.firstIndex(of: _hourValue) {
            selectedLeft = index
        } else {
            selectedLeft = 0
        }
        
        pickerViewLeft.selectRow(selectedLeft , inComponent: 0, animated: false)
        
        if let _minValue = minValue, let index = minOptions.firstIndex(of: _minValue) {
            selectedRight = index
        } else {
            selectedRight = 0
        }
        
        pickerViewRight.selectRow(selectedRight , inComponent: 0, animated: false)
    }
    
    private func initializeTimeOptions(format: TimeFormat) {
        switch format {
        case .ampm:
            // 1 - 12 giờ cho AM/PM
            hourOptions = (0...11).map { String(format: "%02d", $0) }
        case .hour24:
            // 0 - 23 giờ cho 24h
            hourOptions = (0...23).map { String(format: "%02d", $0) }
        }
        
        // phút giống nhau cho cả hai định dạng: 00 - 59
        minOptions = (0...59).map { String(format: "%02d", $0) }
    }
    
    // MARK: - IBActions
    @IBAction private func sortTapped(_ sender: UIButton) {
        dismiss(animated: true) {
            let hour = self.hourValue ?? "00"
            let min = self.minValue ?? "00"
            self.completionWithValue?(.allow, String(format: "%@:%@", hour, min))
        }
    }
    
    @IBAction private func cancelTapped(_ sender: UIButton) {
        dismiss(animated: true) {
        }
    }
    
    @IBAction func favoriteOnlyTapped(_ sender: Any) {
        isAM.toggle()
        
        if isAM {
            amButton.setImage(UIImage(named: "checked1"), for: .normal)
            pmButton.setImage(UIImage(named: "uncheck"), for: .normal)
        } else {
            amButton.setImage(UIImage(named: "uncheck"), for: .normal)
            pmButton.setImage(UIImage(named: "checked1"), for: .normal)
        }
        
        amButton.tintColor = UIColor.white
        pmButton.tintColor = UIColor.white
    }
}

extension SetTimeAlert: UIPickerViewDelegate, UIPickerViewDataSource {
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int { return 1 }
    
    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        return 30 // hoặc giá trị bạn muốn
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return (pickerView == pickerViewLeft) ? hourOptions.count:minOptions.count
    }
    
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        let label = UILabel()
        label.textAlignment = .center
        
        var selectedRow = selectedLeft
        if pickerView == pickerViewLeft {
            label.text = hourOptions[row]
        } else {
            label.text = minOptions[row]
            selectedRow = selectedRight
        }
        
        if row == selectedRow {
            label.textColor = .white
            label.font = UIFont.boldSystemFont(ofSize: 20)
        } else {
            label.textColor = .lightGray
            label.font = UIFont.systemFont(ofSize: 18)
        }
        
        return label
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if pickerView == pickerViewLeft {
            selectedLeft = row
            hourValue = hourOptions[row]
        } else {
            selectedRight = row
            minValue = minOptions[row]
        }
        pickerView.reloadAllComponents() // Update appearance
    }
}

