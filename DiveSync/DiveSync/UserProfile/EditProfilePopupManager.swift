//
//  EditProfilePopupManager.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 5/2/25.
//

import UIKit

final class EditProfilePopupManager {
    
    // MARK: - Show text input alert (e.g., name, email)
    static func showTextInput(
        in viewController: UIViewController,
        title: String,
        currentValue: String?,
        placeholder: String = "",
        keyboardType: UIKeyboardType = .default,
        onSave: @escaping (String) -> Void
    ) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alert.addTextField {
            let valueToShow = (currentValue == "-") ? "" : currentValue
            $0.placeholder = placeholder
            $0.text = valueToShow
            $0.keyboardType = keyboardType
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Set", style: .default) { _ in
            if let value = alert.textFields?.first?.text {
                onSave(value)
            }
        })
        viewController.present(alert, animated: true)
    }
    
    // MARK: - Show date picker popup (e.g., birthday)
    static func showBirthDatePicker(
        in presenter: UIViewController,
        title: String,
        currentValue: String?,
        inputFormat: String? = "dd.MM.yyyy",
        onSave: @escaping (String) -> Void
    ) {
        let dateVC = EditDatePickerViewController()
        dateVC.title = title
        dateVC.outputFormat = inputFormat
        
        if let text = currentValue, text != "-" {
            let formatter = DateFormatter()
            formatter.dateFormat = inputFormat
            if let date = formatter.date(from: text) {
                dateVC.initialDate = date
            }
        }
        
        dateVC.onSave = onSave
        dateVC.modalPresentationStyle = .automatic
        if let sheet = dateVC.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true // Thêm dòng này
        }
        
        presenter.present(dateVC, animated: true)
    }
    
    // MARK: - Show text input for phone number (with numeric keyboard)
    static func showPhoneInput(
        in viewController: UIViewController,
        currentValue: String?,
        onSave: @escaping (String) -> Void
    ) {
        showTextInput(
            in: viewController,
            title: "Phone number",
            currentValue: currentValue,
            placeholder: "Enter phone number",
            keyboardType: .phonePad,
            onSave: onSave
        )
    }
    
    // MARK: - Show bottom sheet for value + unit input (e.g., height, weight)
    static func showValueWithUnitPicker(
        in viewController: UIViewController,
        title: String,
        currentValue: String?,
        units: [String],
        selectedUnitIndex: Int = 0,
        keyboardType: UIKeyboardType = .decimalPad,
        onSave: @escaping (String, String) -> Void
    ) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        
        // Add custom view
        let margin: CGFloat = 8.0
        let customView = UIView(frame: CGRect(x: 0, y: 0, width: 250, height: 80))
        
        // TextField
        let textField = UITextField(frame: CGRect(x: margin, y: 0, width: 250 - margin * 2, height: 36))
        textField.borderStyle = .roundedRect
        textField.keyboardType = keyboardType
        textField.placeholder = "Nhập giá trị"
        textField.text = currentValue
        customView.addSubview(textField)
        
        // Segmented Control
        let segmented = UISegmentedControl(items: units)
        segmented.selectedSegmentIndex = selectedUnitIndex
        segmented.frame = CGRect(x: margin, y: 44, width: 250 - margin * 2, height: 30)
        customView.addSubview(segmented)
        
        // Trick: Use UIViewController to embed custom view
        let vc = UIViewController()
        vc.preferredContentSize = customView.frame.size
        vc.view.addSubview(customView)
        
        alert.setValue(vc, forKey: "contentViewController")
        
        alert.addAction(UIAlertAction(title: "Huỷ", style: .cancel))
        alert.addAction(UIAlertAction(title: "Lưu", style: .default, handler: { _ in
            let value = textField.text ?? ""
            let unit = units[segmented.selectedSegmentIndex]
            onSave(value, unit)
        }))
        
        viewController.present(alert, animated: true)
    }

}

