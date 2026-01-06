//
//  TwoRowPickerAlert.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 5/10/25.
//

import UIKit

enum TwoRowPickerAlertAction {
    case cancel
    case save(String, String)
}

final class TwoRowPickerAlert: UIViewController {

    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let pickerContainer = UIView()
    private let pickerView = UIPickerView()
    private let cancelButton = UIButton(type: .system)
    private let saveButton = UIButton(type: .system)

    private let valueOptions: [String]
    private let unitOptions: [String]
    private var completion: ((TwoRowPickerAlertAction) -> Void)?

    private var selectedValue: String
    private var selectedUnit: String

    // MARK: - Init
    init(title: String,
         valueOptions: [String],
         unitOptions: [String],
         initialValueIndex: Int = 0,
         initialUnitIndex: Int = 0,
         completion: @escaping (TwoRowPickerAlertAction) -> Void) {

        self.valueOptions = valueOptions
        self.unitOptions = unitOptions
        self.selectedValue = valueOptions[initialValueIndex]
        self.selectedUnit = unitOptions[initialUnitIndex]
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Show
    static func show(title: String,
                     valueOptions: [String],
                     unitOptions: [String],
                     initialValueIndex: Int = 0,
                     initialUnitIndex: Int = 0,
                     completion: @escaping (TwoRowPickerAlertAction) -> Void) {
        guard let topVC = UIApplication.shared.topMostViewController() else { return }
        let alert = TwoRowPickerAlert(
            title: title,
            valueOptions: valueOptions,
            unitOptions: unitOptions,
            initialValueIndex: initialValueIndex,
            initialUnitIndex: initialUnitIndex,
            completion: completion
        )
        topVC.present(alert, animated: true)
    }

    // MARK: - View
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
    }

    private func setupViews() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.6)

        containerView.backgroundColor = UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1.0)
        containerView.layer.cornerRadius = 16
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        titleLabel.text = "GAS CONSUMPTION RATE".localized
        titleLabel.textColor = .white
        titleLabel.font = UIFont.boldSystemFont(ofSize: 18)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)

        // Picker container with custom background
        pickerContainer.backgroundColor = .clear
        pickerContainer.clipsToBounds = true
        pickerContainer.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(pickerContainer)

        pickerView.backgroundColor = .clear
        pickerView.delegate = self
        pickerView.dataSource = self
        pickerView.translatesAutoresizingMaskIntoConstraints = false
        pickerContainer.addSubview(pickerView)

        // Highlight selection lines
        let lineColor = UIColor.bottomBar
        let topLine = UIView()
        topLine.backgroundColor = lineColor
        topLine.translatesAutoresizingMaskIntoConstraints = false

        let bottomLine = UIView()
        bottomLine.backgroundColor = lineColor
        bottomLine.translatesAutoresizingMaskIntoConstraints = false

        pickerContainer.addSubview(topLine)
        pickerContainer.addSubview(bottomLine)

        NSLayoutConstraint.activate([
            topLine.heightAnchor.constraint(equalToConstant: 1),
            topLine.leadingAnchor.constraint(equalTo: pickerContainer.leadingAnchor),
            topLine.trailingAnchor.constraint(equalTo: pickerContainer.trailingAnchor),
            topLine.centerYAnchor.constraint(equalTo: pickerView.centerYAnchor, constant: -20),

            bottomLine.heightAnchor.constraint(equalToConstant: 1),
            bottomLine.leadingAnchor.constraint(equalTo: pickerContainer.leadingAnchor),
            bottomLine.trailingAnchor.constraint(equalTo: pickerContainer.trailingAnchor),
            bottomLine.centerYAnchor.constraint(equalTo: pickerView.centerYAnchor, constant: 20),
        ])

        cancelButton.setTitle("Cancel".localized.uppercased(), for: .normal)
        cancelButton.setTitleColor(.systemOrange, for: .normal)
        cancelButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(cancelButton)

        saveButton.setTitle("SAVE".localized, for: .normal)
        saveButton.setTitleColor(.systemOrange, for: .normal)
        saveButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(saveButton)

        setupConstraints()

        pickerView.selectRow(valueOptions.firstIndex(of: selectedValue) ?? 0, inComponent: 0, animated: false)
        pickerView.selectRow(unitOptions.firstIndex(of: selectedUnit) ?? 0, inComponent: 1, animated: false)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 300),

            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),

            pickerContainer.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            pickerContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            pickerContainer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            pickerContainer.heightAnchor.constraint(equalToConstant: 120),

            pickerView.topAnchor.constraint(equalTo: pickerContainer.topAnchor),
            pickerView.bottomAnchor.constraint(equalTo: pickerContainer.bottomAnchor),
            pickerView.leadingAnchor.constraint(equalTo: pickerContainer.leadingAnchor),
            pickerView.trailingAnchor.constraint(equalTo: pickerContainer.trailingAnchor),

            saveButton.topAnchor.constraint(equalTo: pickerContainer.bottomAnchor, constant: 20),
            saveButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),

            cancelButton.centerYAnchor.constraint(equalTo: saveButton.centerYAnchor),
            cancelButton.trailingAnchor.constraint(equalTo: saveButton.leadingAnchor, constant: -20),

            saveButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20)
        ])
    }

    // MARK: - Actions
    @objc private func cancelTapped() {
        dismiss(animated: true) {
            self.completion?(.cancel)
        }
    }

    @objc private func saveTapped() {
        dismiss(animated: true) {
            self.completion?(.save(self.selectedValue, self.selectedUnit))
        }
    }
}

// MARK: - UIPickerViewDataSource & Delegate
extension TwoRowPickerAlert: UIPickerViewDataSource, UIPickerViewDelegate {

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 2
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return component == 0 ? valueOptions.count : unitOptions.count
    }

    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        return 40
    }

    func pickerView(_ pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat {
        return 130
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        let text = component == 0 ? valueOptions[row] : unitOptions[row]
        return text
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if component == 0 {
            selectedValue = valueOptions[row]
        } else {
            selectedUnit = unitOptions[row]
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        let title = component == 0 ? valueOptions[row] : unitOptions[row]
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        return NSAttributedString(string: title, attributes: [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 18),
            .paragraphStyle: paragraphStyle
        ])
    }
}
