import UIKit

let alunium = "Aluminum"
let steel = "Steel"

enum TankTypeAlertAction {
    case cancel
    case save(text: String?)
}

final class TankTypeAlert: UIViewController {

    // MARK: - UI Elements
    private let containerView = UIView()
    private let titleLabel = UILabel()

    //
    private let radioButton1 = UIButton(type: .system)
    private let radioLabel1 = UILabel()

    private let radioButton2 = UIButton(type: .system)
    private let radioLabel2 = UILabel()

    private let radioButton3 = UIButton(type: .system)
    private let radioLabel3 = UILabel()
    private let otherTextField = UITextField()

    private let cancelButton = UIButton(type: .system)
    private let saveButton = UIButton(type: .system)

    private var completion: ((TankTypeAlertAction) -> Void)?
    private var selectedIndex: Int = 0

    // MARK: - Init
    init(title: String,
         selectedIndex: Int = 0,
         otherText: String? = nil, completion: @escaping (TankTypeAlertAction) -> Void) {
        super.init(nibName: nil, bundle: nil)
        self.completion = completion
        self.selectedIndex = selectedIndex
        setupViews(title: title)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
        self.otherTextField.text = otherText
        updateSelection(index: selectedIndex)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }

        let keyboardHeight = keyboardFrame.height

        // Move containerView lên nếu bị che
        UIView.animate(withDuration: duration) {
            self.containerView.transform = CGAffineTransform(translationX: 0, y: -keyboardHeight / 3)
        }
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }

        UIView.animate(withDuration: duration) {
            self.containerView.transform = .identity
        }
    }

    // MARK: - Static Show Method
    static func show(title: String,
                     selectedIndex: Int = 0,
                     otherText: String? = nil, completion: @escaping (TankTypeAlertAction) -> Void) {
        guard let topVC = UIApplication.shared.topMostViewController() else { return }
        let alert = TankTypeAlert(title: title, selectedIndex: selectedIndex, otherText: otherText, completion: completion)
        topVC.present(alert, animated: true)
    }

    // MARK: - Setup UI
    private func setupViews(title: String) {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.6)

        containerView.backgroundColor = .B_3
        containerView.layer.cornerRadius = 16
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        titleLabel.text = title
        titleLabel.textColor = .white
        titleLabel.font = UIFont.boldSystemFont(ofSize: 20)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)

        setupRadioButton(radioButton1, selected: true)
        radioLabel1.text = alunium.localized
        radioLabel1.textColor = .white
        radioLabel1.translatesAutoresizingMaskIntoConstraints = false

        setupRadioButton(radioButton2)
        radioLabel2.text = steel.localized
        radioLabel2.textColor = .white
        radioLabel2.translatesAutoresizingMaskIntoConstraints = false

        setupRadioButton(radioButton3)
        radioLabel3.text = "Other".localized
        radioLabel3.textColor = .white
        radioLabel3.translatesAutoresizingMaskIntoConstraints = false

        otherTextField.placeholder = "Enter tank type".localized
        otherTextField.borderStyle = .roundedRect
        otherTextField.isEnabled = false
        otherTextField.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(radioButton1)
        containerView.addSubview(radioLabel1)
        containerView.addSubview(radioButton2)
        containerView.addSubview(radioLabel2)

        containerView.addSubview(radioButton3)
        containerView.addSubview(radioLabel3)
        containerView.addSubview(otherTextField)

        cancelButton.setTitle("Cancel".localized.uppercased(), for: .normal)
        cancelButton.setTitleColor(.B_1, for: .normal)
        cancelButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(cancelButton)

        saveButton.setTitle("Set".localized.uppercased(), for: .normal)
        saveButton.setTitleColor(.B_1, for: .normal)
        saveButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(saveButton)

        // Targets
        radioButton1.addTarget(self, action: #selector(selectRadio1), for: .touchUpInside)
        radioButton2.addTarget(self, action: #selector(selectRadio2), for: .touchUpInside)
        radioButton3.addTarget(self, action: #selector(selectRadio3), for: .touchUpInside)

        // Constraints
        NSLayoutConstraint.activate([
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 320),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),

            radioButton1.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            radioButton1.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            radioButton1.widthAnchor.constraint(equalToConstant: 24),
            radioButton1.heightAnchor.constraint(equalToConstant: 24),

            radioLabel1.centerYAnchor.constraint(equalTo: radioButton1.centerYAnchor),
            radioLabel1.leadingAnchor.constraint(equalTo: radioButton1.trailingAnchor, constant: 12),

            radioButton2.topAnchor.constraint(equalTo: radioButton1.bottomAnchor, constant: 16),
            radioButton2.leadingAnchor.constraint(equalTo: radioButton1.leadingAnchor),
            radioButton2.widthAnchor.constraint(equalToConstant: 24),
            radioButton2.heightAnchor.constraint(equalToConstant: 24),

            radioLabel2.centerYAnchor.constraint(equalTo: radioButton2.centerYAnchor),
            radioLabel2.leadingAnchor.constraint(equalTo: radioButton2.trailingAnchor, constant: 12),

            radioButton3.topAnchor.constraint(equalTo: radioButton2.bottomAnchor, constant: 16),
            radioButton3.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            radioButton3.widthAnchor.constraint(equalToConstant: 24),
            radioButton3.heightAnchor.constraint(equalToConstant: 24),

            radioLabel3.centerYAnchor.constraint(equalTo: radioButton3.centerYAnchor),
            radioLabel3.leadingAnchor.constraint(equalTo: radioButton3.trailingAnchor, constant: 12),

            otherTextField.centerYAnchor.constraint(equalTo: radioButton3.centerYAnchor),
            otherTextField.leadingAnchor.constraint(equalTo: radioLabel3.trailingAnchor, constant: 12),
            otherTextField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            otherTextField.heightAnchor.constraint(equalToConstant: 36),

            // Buttons bottom
            saveButton.topAnchor.constraint(equalTo: otherTextField.bottomAnchor, constant: 20),
            saveButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            cancelButton.centerYAnchor.constraint(equalTo: saveButton.centerYAnchor),
            cancelButton.trailingAnchor.constraint(equalTo: saveButton.leadingAnchor, constant: -30),

            // Bottom constraint
            saveButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20)
        ])
    }

    private func setupRadioButton(_ button: UIButton, selected: Bool = false) {
        let config = UIImage.SymbolConfiguration(scale: .medium)
        let image = UIImage(systemName: selected ? "largecircle.fill.circle" : "circle", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
    }

    private func updateSelection(index: Int) {
        selectedIndex = index

        let config = UIImage.SymbolConfiguration(scale: .medium)
        radioButton1.setImage(UIImage(systemName: index == 0 ? "largecircle.fill.circle" : "circle", withConfiguration: config), for: .normal)
        radioButton2.setImage(UIImage(systemName: index == 1 ? "largecircle.fill.circle" : "circle", withConfiguration: config), for: .normal)
        radioButton3.setImage(UIImage(systemName: index == 2 ? "largecircle.fill.circle" : "circle", withConfiguration: config), for: .normal)

        otherTextField.isEnabled = (index == 2)
        if index == 2 {
            otherTextField.becomeFirstResponder()
        } else {
            otherTextField.resignFirstResponder()
        }
    }

    // MARK: - Actions
    @objc private func selectRadio1() {
        updateSelection(index: 0)
    }

    @objc private func selectRadio2() {
        updateSelection(index: 1)
    }

    @objc private func selectRadio3() {
        updateSelection(index: 2)
    }

    @objc private func cancelTapped() {
        dismiss(animated: true) {
            self.completion?(.cancel)
        }
    }

    @objc private func saveTapped() {
        dismiss(animated: true) {
            var selectedType = ""
            switch self.selectedIndex {
            case 0: selectedType = alunium
            case 1: selectedType = steel
            case 2: selectedType = self.otherTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            default: break
            }
            self.completion?(.save(text: selectedType))
        }
    }
}
