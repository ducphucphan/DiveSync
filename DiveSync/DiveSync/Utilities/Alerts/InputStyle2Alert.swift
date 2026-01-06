//
//  InputStyle2Alert.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 5/9/25.
//

import UIKit

enum InputStyle2AlertAction {
    case cancel
    case save(String?, String?)
}

final class InputStyle2Alert: UIViewController {

    // MARK: - UI Elements
    private let containerView = UIView()
    private let titleLabel = UILabel()
    
    private let textField1 = UITextField()
    private let textField2 = UITextField()
    
    private let unitLabel1 = UILabel()
    private let unitLabel2 = UILabel()
    
    private let cancelButton = UIButton(type: .system)
    private let saveButton = UIButton(type: .system)

    private var completion: ((InputStyle2AlertAction) -> Void)?

    // MARK: - Init
    init(title: String,
         placeholder1: String? = nil,
         placeholder2: String? = nil,
         unitText1: String = "",
         unitText2: String = "",
         completion: @escaping (InputStyle2AlertAction) -> Void) {
        super.init(nibName: nil, bundle: nil)
        self.completion = completion
        setupViews(title: title, placeholder1: placeholder1, placeholder2: placeholder2, unitText1: unitText1, unitText2: unitText2)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Static Show Method
    static func show(title: String,
                     placeholder1: String? = nil,
                     placeholder2: String? = nil,
                     unitText1: String = "",
                     unitText2: String = "",
                     completion: @escaping (InputStyle2AlertAction) -> Void) {
        guard let topVC = UIApplication.shared.topMostViewController() else { return }
        let alert = InputStyle2Alert(title: title, placeholder1: placeholder1, placeholder2: placeholder2, unitText1: unitText1, unitText2: unitText2, completion: completion)
        topVC.present(alert, animated: true)
    }

    // MARK: - Setup UI
    private func setupViews(title: String, placeholder1: String?, placeholder2: String?, unitText1: String, unitText2: String) {
        // Dimmed background
        view.backgroundColor = UIColor.black.withAlphaComponent(0.6)

        // Container
        containerView.backgroundColor = UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1.0)
        containerView.layer.cornerRadius = 16
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        // Title
        titleLabel.text = title
        titleLabel.textColor = .white
        titleLabel.font = UIFont.boldSystemFont(ofSize: 20)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)

        // TextFields
        textField1.placeholder = placeholder1
        textField1.backgroundColor = .white
        textField1.layer.cornerRadius = 8
        textField1.keyboardType = .decimalPad
        textField1.textAlignment = .center
        textField1.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(textField1)

        textField2.placeholder = placeholder2
        textField2.backgroundColor = .white
        textField2.layer.cornerRadius = 8
        textField2.keyboardType = .decimalPad
        textField2.textAlignment = .center
        textField2.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(textField2)

        // Unit Labels
        unitLabel1.text = unitText1
        unitLabel1.textColor = .lightGray
        unitLabel1.font = UIFont.boldSystemFont(ofSize: 16)
        unitLabel1.textAlignment = .center
        unitLabel1.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(unitLabel1)

        unitLabel2.text = unitText2
        unitLabel2.textColor = .lightGray
        unitLabel2.font = UIFont.boldSystemFont(ofSize: 16)
        unitLabel2.textAlignment = .center
        unitLabel2.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(unitLabel2)

        // Buttons
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
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Container in center
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 300),

            // Title top
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),

            // TextFields (horizontally arranged)
            textField1.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            textField1.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            textField1.widthAnchor.constraint(equalToConstant: 120),
            textField1.heightAnchor.constraint(equalToConstant: 40),

            textField2.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            textField2.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            textField2.widthAnchor.constraint(equalToConstant: 120),
            textField2.heightAnchor.constraint(equalToConstant: 40),

            // Unit Labels below respective textfields
            unitLabel1.topAnchor.constraint(equalTo: textField1.bottomAnchor, constant: 8),
            unitLabel1.centerXAnchor.constraint(equalTo: textField1.centerXAnchor),

            unitLabel2.topAnchor.constraint(equalTo: textField2.bottomAnchor, constant: 8),
            unitLabel2.centerXAnchor.constraint(equalTo: textField2.centerXAnchor),

            // Buttons bottom
            saveButton.topAnchor.constraint(equalTo: unitLabel2.bottomAnchor, constant: 20),
            saveButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            cancelButton.centerYAnchor.constraint(equalTo: saveButton.centerYAnchor),
            cancelButton.trailingAnchor.constraint(equalTo: saveButton.leadingAnchor, constant: -30),

            // Bottom constraint
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
            self.completion?(.save(self.textField1.text, self.textField2.text))
        }
    }
}
