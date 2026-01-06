//
//  Set2RowSettingAlert.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 6/12/25.
//

import UIKit

final class Set2ValueSettingAlert: UIViewController {
    
    // MARK: - IBOutlets
    @IBOutlet private weak var containerView: UIView!
    @IBOutlet private weak var messageLabel: UILabel!
    @IBOutlet private weak var allowButton: UIButton!
    @IBOutlet private weak var denyButton: UIButton!
    
    @IBOutlet weak var pickerViewLeft: UIPickerView!
    
    @IBOutlet weak var pickerViewRight: UIPickerView!
    
    private var leftOptions: [String] = []
    private var rightOptions: [String] = []
    
    private var selectedLeft = 0
    private var selectedRight = 0
    
    private var completionWithValue: ((_ action: PrivacyAlertAction, _ selectedValue: String?) -> Void)?
    private var allowTitle: String = "Set".localized.uppercased()
    private var denyTitle: String = "Cancel".localized.uppercased()
    
    private var leftValue: String = ""
    private var rightValue: String = ""
    
    private var messageText: String? = nil
        
    // MARK: - Initializer
    static func showMessage(message: String? = "Safety Stop".localized,
                            leftValue: String,
                            rightValue: String,
                            leftOptions: [String],
                            rightOptions: [String],
                            allowTitle: String = "Set".localized.uppercased(),
                            denyTitle: String = "Cancel".localized.uppercased(),
                            completion: @escaping (_ action: PrivacyAlertAction, _ selectedValue: String?) -> Void ) {
        guard let topVC = UIApplication.shared.topMostViewController(),
              let alert = UIStoryboard(name: "Utils", bundle: nil)
            .instantiateViewController(withIdentifier: "Set2RowSettingAlert") as? Set2ValueSettingAlert else {
            return
        }
        
        alert.messageText = message
        alert.leftOptions = leftOptions
        alert.rightOptions = rightOptions
        alert.leftValue = leftValue
        alert.rightValue = rightValue
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
        
        messageLabel.text = messageText
        allowButton.setTitle(allowTitle, for: .normal)
        denyButton.setTitle(denyTitle, for: .normal)
        
        // Picker
        pickerViewLeft.dataSource = self
        pickerViewLeft.delegate = self
        
        pickerViewRight.dataSource = self
        pickerViewRight.delegate = self
        
        containerView.backgroundColor = UIColor.B_3
        containerView.layer.cornerRadius = 16
        containerView.translatesAutoresizingMaskIntoConstraints = false
                
        // Convert selectedValue to selectedIndex if needed
        if let index = leftOptions.firstIndex(of: leftValue) {
            selectedLeft = index
        } else {
            selectedLeft = 0
        }
        
        pickerViewLeft.selectRow(selectedLeft , inComponent: 0, animated: false)
        
        if let index = rightOptions.firstIndex(of: rightValue) {
            selectedRight = index
        } else {
            selectedRight = 0
        }
        
        pickerViewRight.selectRow(selectedRight , inComponent: 0, animated: false)
    }
    
    // MARK: - IBActions
    @IBAction private func setTapped(_ sender: UIButton) {
        dismiss(animated: true) {
            let value = String(format: "%@ - %@", self.leftOptions[self.selectedLeft], self.rightOptions[self.selectedRight])
            self.completionWithValue?(.allow, value)
        }
    }
    
    @IBAction private func cancelTapped(_ sender: UIButton) {
        dismiss(animated: true) {
        }
    }
}

extension Set2ValueSettingAlert: UIPickerViewDelegate, UIPickerViewDataSource {
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int { return 1 }
    
    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        return 30 // hoặc giá trị bạn muốn
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return (pickerView == pickerViewLeft) ? leftOptions.count:rightOptions.count
    }
    
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        let label = UILabel()
        label.textAlignment = .center
        
        var selectedRow = selectedLeft
        if pickerView == pickerViewLeft {
            label.text = leftOptions[row]
        } else {
            label.text = rightOptions[row]
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
            leftValue = leftOptions[row]
        } else {
            selectedRight = row
            rightValue = rightOptions[row]
        }
        pickerView.reloadAllComponents() // Update appearance
    }
}


