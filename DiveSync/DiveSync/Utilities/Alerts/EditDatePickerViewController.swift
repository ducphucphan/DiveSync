//
//  EditDatePickerViewController.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 5/2/25.
//

import UIKit

class EditDatePickerViewController: UIViewController {

    var outputFormat: String? = "dd.MM.yyyy"
    var initialDate: Date = Date()
    var onSave: ((String) -> Void)?

    private let datePicker = UIDatePicker()
    private let titleLabel = UILabel()
    private let cancelButton = UIButton(type: .system)
    private let saveButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        view.backgroundColor = .white
        view.layer.cornerRadius = 20
        view.clipsToBounds = true

        // Cấu hình tiêu đề
        titleLabel.text = "Select Date".localized
        titleLabel.font = .boldSystemFont(ofSize: 18)
        titleLabel.textAlignment = .center

        // Cấu hình các nút
        cancelButton.setTitle("Cancel".localized, for: .normal)
        saveButton.setTitle("Set".localized.uppercased(), for: .normal)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)

        // Hàng chứa cancel - title - save
        let titleRow = UIStackView(arrangedSubviews: [cancelButton, titleLabel, saveButton])
        titleRow.axis = .horizontal
        titleRow.alignment = .center
        titleRow.distribution = .equalCentering

        // Dải phân cách
        let separator = UIView()
        separator.backgroundColor = UIColor.main
        separator.heightAnchor.constraint(equalToConstant: 0.3).isActive = true

        // Date Picker
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .inline
        datePicker.date = initialDate
        datePicker.setContentHuggingPriority(.required, for: .vertical)
        datePicker.setContentCompressionResistancePriority(.required, for: .vertical)

        // Stack chính
        let stack = UIStackView(arrangedSubviews: [titleRow, separator, datePicker])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)

        // Ràng buộc
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),

            titleLabel.heightAnchor.constraint(equalToConstant: 24),
            cancelButton.widthAnchor.constraint(equalToConstant: 60),
            saveButton.widthAnchor.constraint(equalToConstant: 60)
        ])
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func saveTapped() {
        let formatter = DateFormatter()
        formatter.dateFormat = outputFormat
        let formatted = formatter.string(from: datePicker.date)
        onSave?(formatted)
        dismiss(animated: true)
    }
}

