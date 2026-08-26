import UIKit

enum InputAlertAction {
    case cancel
    case save(String?)
}

final class InputAlert: UIViewController, UITextFieldDelegate {

    // MARK: - UI Elements
    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let textField = UITextField()
    private let unitLabel = UILabel()
    private let cancelButton = UIButton(type: .system)
    private let saveButton = UIButton(type: .system)
    private let inputStack = UIStackView()
    
    private var containerCenterYConstraint: NSLayoutConstraint?

    private var maxLength: Int? // Thêm biến lưu giới hạn ký tự
    
    private var completion: ((InputAlertAction) -> Void)?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.main.async {
            self.textField.becomeFirstResponder()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.textField.autocorrectionType = .no
        self.textField.spellCheckingType = .no
        
        setupKeyboardObservers()
    }

    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc private func handleKeyboardWillShow(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }

        // Tính toán khoảng cách cần đẩy containerView lên
        let keyboardHeight = keyboardFrame.height
        let containerBottom = containerView.frame.maxY
        let screenHeight = view.bounds.height
        let overlap = containerBottom - (screenHeight - keyboardHeight)

        // Nếu bàn phím đè lên Alert, đẩy Alert lên trên đúng khoảng bị đè (cộng thêm 20pt đệm)
        if overlap > 0 {
            containerCenterYConstraint?.constant = -(overlap + 20)
            UIView.animate(withDuration: duration) {
                self.view.layoutIfNeeded()
            }
        }
    }

    @objc private func handleKeyboardWillHide(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }

        containerCenterYConstraint?.constant = 0
        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Init
    init(title: String,
         saveTitle: String = "SAVE".localized,
         currentValue: String = "",
         placeholder: String? = nil,
         unitText: String = "",
         keyboardType: UIKeyboardType = .default,
         textAlignment: NSTextAlignment = .left,
         maxLength: Int? = nil,
         completion: @escaping (InputAlertAction) -> Void) {
        
        super.init(nibName: nil, bundle: nil)
        
        self.completion = completion
        self.maxLength = maxLength
        
        setupViews(title: title, saveTitle: saveTitle, currentValue: currentValue, placeholder: placeholder, unitText: unitText, keyboardType: keyboardType, textAlignment: textAlignment)
        
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Static Show Method
    static func show(title: String,
                     saveTitle: String = "SAVE".localized,
                     currentValue: String = "",
                     placeholder: String? = nil,
                     unitText: String = "",
                     keyboardType: UIKeyboardType = .default,
                     textAlignment: NSTextAlignment = .left,
                     maxLength: Int? = nil,
                     completion: @escaping (InputAlertAction) -> Void) {
        guard let topVC = UIApplication.shared.topMostViewController() else { return }
        let alert = InputAlert(title: title, saveTitle: saveTitle, currentValue: currentValue, placeholder: placeholder, unitText: unitText, keyboardType: keyboardType, textAlignment: textAlignment, maxLength: maxLength, completion: completion)
        topVC.present(alert, animated: true)
    }

    // MARK: - Setup UI
    private func setupViews(title: String, saveTitle: String, currentValue: String, placeholder: String?, unitText: String, keyboardType: UIKeyboardType, textAlignment: NSTextAlignment) {
        
        textField.delegate = self
        
        view.backgroundColor = UIColor.black.withAlphaComponent(0.6)

        // Container
        containerView.backgroundColor = UIColor.B_3
        containerView.layer.cornerRadius = 16
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        // Title
        titleLabel.text = title
        titleLabel.textColor = .white
        titleLabel.font = UIFont.boldSystemFont(ofSize: 20)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)

        // TextField
        textField.text = (currentValue == "-") ? "":currentValue
        textField.placeholder = placeholder
        textField.backgroundColor = .white
        textField.layer.cornerRadius = 8
        textField.keyboardType = keyboardType
        textField.textAlignment = textAlignment
        textField.translatesAutoresizingMaskIntoConstraints = false
        if (textAlignment == .left) {
            textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 4, height: 0))
            textField.leftViewMode = .always
        }
        
        // Unit Label
        unitLabel.text = unitText
        unitLabel.textColor = .lightGray
        unitLabel.font = UIFont.systemFont(ofSize: 14)
        unitLabel.translatesAutoresizingMaskIntoConstraints = false
        unitLabel.setContentHuggingPriority(.required, for: .horizontal)
        unitLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        // StackView
        inputStack.axis = .horizontal
        inputStack.spacing = 16
        inputStack.alignment = .fill
        inputStack.distribution = .fill
        inputStack.translatesAutoresizingMaskIntoConstraints = false
        inputStack.addArrangedSubview(textField)
        inputStack.addArrangedSubview(unitLabel)
        containerView.addSubview(inputStack)

        // Buttons
        cancelButton.setTitle("Cancel".localized.uppercased(), for: .normal)
        cancelButton.setTitleColor(UIColor.B_1, for: .normal)
        cancelButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(cancelButton)

        saveButton.setTitle(saveTitle, for: .normal)
        saveButton.setTitleColor(UIColor.B_1, for: .normal)
        saveButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(saveButton)

        setupConstraints()
    }

    private func setupConstraints() {
        let centerYConstraint = containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        self.containerCenterYConstraint = centerYConstraint

        NSLayoutConstraint.activate([
            // Container
            centerYConstraint,
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 300),

            // Title
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),

            // Input Stack (TextField + Unit)
            inputStack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            inputStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            inputStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            inputStack.heightAnchor.constraint(equalToConstant: 40),

            // Save and Cancel Buttons
            saveButton.topAnchor.constraint(equalTo: inputStack.bottomAnchor, constant: 20),
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
            self.completion?(.save(self.textField.text))
        }
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let limit = maxLength else { return true }
        
        let currentString = (textField.text ?? "") as NSString
        let newString = currentString.replacingCharacters(in: range, with: string)
        return newString.count <= limit
    }
}
