//
//  DialogViewController.swift
//  testtesttest
//
//  Created by Phan Duc Phuc on 9/11/25.
//

import UIKit

// MARK: - Alert Style
enum DialogAlertStyle {
    case loading
    case progress
    case message
    case retry
}

class DialogViewController: UIViewController {
    
    // MARK: - Outlets
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var okButton: UIButton!
    
    // MARK: - Callbacks
    private var onCompleted: ((Bool) -> Void)?
    private var onCancel: (() -> Void)?
    private var onOKButton: (() -> Void)?
    var cancelTask: (() -> Void)?   // 👉 Hủy task thực tế sẽ gán vào đây
    
    // MARK: - Properties
    var initialTitle: String?
    var initialMessage: String?
    var style: DialogAlertStyle = .loading
    var hideCancelButton: Bool = false   // 👉 mới thêm
    
    var cancelButtonTitle: String?
    var okButtonTitle: String?
    
    // MARK: - Static Instance
    private static var currentAlert: DialogViewController?
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        containerView.layer.cornerRadius = 16
        containerView.layer.masksToBounds = true
        
        titleLabel.text = initialTitle
        messageLabel.text = initialMessage
        
        configureUI()
    }
    
    private func configureUI() {
        cancelButton.isHidden = hideCancelButton
        okButton.isHidden = okButtonTitle == nil
        
        if let title = okButtonTitle {
            okButton.setTitle(title, for: .normal)
        }
        
        switch style {
        case .loading:
            activityIndicator.startAnimating()
            activityIndicator.isHidden = false
            progressView.isHidden = true
            cancelButton.setTitle("Cancel".localized.uppercased(), for: .normal)
            
        case .progress:
            activityIndicator.isHidden = true
            progressView.isHidden = false
            progressView.progress = 0
            cancelButton.setTitle("Cancel".localized.uppercased(), for: .normal)
            
        case .message:
            activityIndicator.isHidden = true
            progressView.isHidden = true
            cancelButton.setTitle("OK".localized, for: .normal)
            
        case .retry:
            activityIndicator.isHidden = true
            progressView.isHidden = true
            if let cancelTitle = cancelButtonTitle {
                cancelButton.setTitle(cancelTitle, for: .normal)
            }
        }
        
    }
    
    // MARK: - Public Show Methods
    
    /// Hiển thị alert dạng loading
    static func showLoading(title: String,
                            message: String,
                            hideCancel: Bool? = false,   // 👉 thêm
                            task: ((DialogViewController) -> Void)? = nil,
                            onCancel: (() -> Void)? = nil,
                            onCompleted: ((Bool) -> Void)? = nil) {
        
        show(style: .loading,
             title: title,
             message: message,
             hideCancel: hideCancel,
             task: task,
             onCancel: onCancel,
             onCompleted: onCompleted)
    }
    
    /// Hiển thị alert dạng message (OK button)
    static func showMessage(title: String,
                            message: String,
                            onCancel: (() -> Void)? = nil) {
        
        show(style: .message,
             title: title,
             message: message,
             hideCancel: false,
             task: nil,
             onCancel: onCancel,  // OK button reuse cancel callback
             onCompleted: nil)
    }
    
    static func showRetryMessage(title: String,
                                 message: String,
                                 cancelButtonTitle: String? = nil,
                                 okButtonTitle: String? = nil,
                                 onCancel: (() -> Void)? = nil,
                                 onOK: (() -> Void)? = nil) {
        show(style: .retry,
             title: title,
             message: message,
             hideCancel: false,
             cancelButtonTitle: cancelButtonTitle,
             okButtonTitle: okButtonTitle,
             onOKButton: onOK,
             task: nil,
             onCancel: onCancel,
             onCompleted: nil)
        
    }
    
    /// Hiển thị alert dạng process (progress bar)
    static func showProcess(title: String,
                            message: String,
                            hideCancel: Bool? = false,   // 👉 thêm
                            task: ((DialogViewController) -> Void)? = nil,
                            onCancel: (() -> Void)? = nil,
                            onCompleted: ((Bool) -> Void)? = nil) {
        
        show(style: .progress,
             title: title,
             message: message,
             hideCancel: hideCancel,
             task: task,
             onCancel: onCancel,
             onCompleted: onCompleted)
    }
    
    // MARK: - Private Show
    private static func show(style: DialogAlertStyle,
                             title: String,
                             message: String,
                             hideCancel: Bool? = false,
                             cancelButtonTitle: String? = nil,
                             okButtonTitle: String? = nil,
                             onOKButton: (() -> Void)? = nil,
                             task: ((DialogViewController) -> Void)?,
                             onCancel: (() -> Void)?,
                             onCompleted: ((Bool) -> Void)?) {
        
        if let alertVC = currentAlert {
            alertVC.dismiss(animated: false) {
                currentAlert = nil
                self.show(style: style,
                          title: title,
                          message: message,
                          hideCancel: hideCancel,
                          cancelButtonTitle: cancelButtonTitle,
                          okButtonTitle: okButtonTitle,
                          onOKButton: onOKButton,
                          task: task,
                          onCancel: onCancel,
                          onCompleted: onCompleted)
            }
            return
        }
        
        guard let presenter = UIApplication.shared.topMostViewController() else { return }
        
        let storyboard = UIStoryboard(name: "Utils", bundle: nil)
        let alertVC = storyboard.instantiateViewController(withIdentifier: "DialogViewController") as! DialogViewController
        alertVC.modalPresentationStyle = .overFullScreen
        alertVC.modalTransitionStyle = .crossDissolve
        
        alertVC.onCompleted = onCompleted
        alertVC.onCancel = onCancel
        alertVC.onOKButton = onOKButton
        
        alertVC.initialTitle = title
        alertVC.initialMessage = message
        alertVC.style = style
        
        alertVC.hideCancelButton = hideCancel ?? false   // 👉 gán ở đây
        alertVC.cancelButtonTitle = cancelButtonTitle
        alertVC.okButtonTitle = okButtonTitle
        
        currentAlert = alertVC
        
        presenter.present(alertVC, animated: true) {
            if style == .loading || style == .progress {
                task?(alertVC)
            }
        }
    }
    
    // MARK: - Update / Finish
    static func updateProgress(_ value: Float, message: String? = nil) {
        guard let alertVC = currentAlert else { return }
        DispatchQueue.main.async {
            alertVC.titleLabel.text = alertVC.initialTitle
            if message != nil {
                alertVC.messageLabel.text = message
            }
            alertVC.activityIndicator.stopAnimating()
            alertVC.activityIndicator.isHidden = true
            alertVC.progressView.isHidden = false
            alertVC.progressView.progress = value
        }
    }
    
    static func finish(success: Bool) {
        guard let alertVC = currentAlert else { return }
        alertVC.dismiss(animated: true) {
            alertVC.onCompleted?(success)
            currentAlert = nil
        }
    }
    
    static func dismissAlert(completion: (() -> Void)? = nil) {
        guard let alertVC = currentAlert else {
            completion?()
            return
        }
        
        currentAlert = nil
        
        alertVC.dismiss(animated: true) {
            completion?()
        }
    }
    
    // MARK: - Actions
    @IBAction func cancelTapped(_ sender: Any) {
        DialogViewController.currentAlert = nil
        
        dismiss(animated: true) {
            self.cancelTask?()   // 👉 Hủy task thực sự
            self.onCancel?()
        }
    }
    
    @IBAction func okTapped(_ sender: Any) {
        DialogViewController.currentAlert = nil
        
        dismiss(animated: true) {
            self.cancelTask?()
            self.onOKButton?()
        }
    }
}
