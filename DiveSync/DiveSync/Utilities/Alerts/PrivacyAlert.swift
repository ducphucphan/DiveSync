//
//  PrivacyAlert.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 4/26/25.
//

import UIKit

enum PrivacyAlertAction {
    case allow
    case deny
}

final class PrivacyAlert: UIViewController {

    // MARK: - UI Elements
    private let containerView = UIView()
    private let messageLabel = UILabel()
    private let allowButton = UIButton(type: .system)
    private let denyButton = UIButton(type: .system)

    private var completion: ((PrivacyAlertAction) -> Void)?

    // MARK: - Init
    init(message: String,
         allowTitle: String = "ALLOW",
         denyTitle: String = "DENY",
         completion: @escaping (PrivacyAlertAction) -> Void) {
        super.init(nibName: nil, bundle: nil)
        self.completion = completion
        setupViews(message: message, allowTitle: allowTitle, denyTitle: denyTitle)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Static Show Method
    static func showMessage(message: String,
                             allowTitle: String = "ALLOW",
                             denyTitle: String = "DENY",
                             completion: @escaping (PrivacyAlertAction) -> Void) {
        guard let topVC = UIApplication.shared.topMostViewController() else {
            return
        }
        let alert = PrivacyAlert(message: message, allowTitle: allowTitle, denyTitle: denyTitle, completion: completion)
        topVC.present(alert, animated: true)
    }

    // MARK: - Setup UI
    private func setupViews(message: String, allowTitle: String, denyTitle: String) {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.6)

        containerView.backgroundColor = UIColor.B_3
        containerView.layer.cornerRadius = 16
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        messageLabel.text = message
        messageLabel.textColor = .white
        messageLabel.font = UIFont.systemFont(ofSize: 18)
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .left
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(messageLabel)

        allowButton.setTitle(allowTitle, for: .normal)
        allowButton.setTitleColor(UIColor.B_2, for: .normal)
        allowButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        allowButton.addTarget(self, action: #selector(allowTapped), for: .touchUpInside)
        allowButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(allowButton)

        denyButton.setTitle(denyTitle, for: .normal)
        denyButton.setTitleColor(UIColor.B_2, for: .normal)
        denyButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        denyButton.addTarget(self, action: #selector(denyTapped), for: .touchUpInside)
        denyButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(denyButton)

        setupConstraints()
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 300),

            messageLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            messageLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            messageLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),

            allowButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 20),
            allowButton.trailingAnchor.constraint(equalTo: denyButton.leadingAnchor, constant: -20),

            denyButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 20),
            denyButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -30),

            allowButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20),
            denyButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20)
        ])
    }

    // MARK: - Actions
    @objc private func allowTapped() {
        dismiss(animated: true) {
            self.completion?(.allow)
        }
    }

    @objc private func denyTapped() {
        dismiss(animated: true) {
            self.completion?(.deny)
        }
    }
}
