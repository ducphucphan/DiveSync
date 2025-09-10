import UIKit

class DownloadProgressView: UIView {

    static let shared = DownloadProgressView()

    private let backgroundView = UIView()
    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let cancelButton = UIButton(type: .system)

    private var indeterminateTimer: Timer?
    private var currentProgress: Float = 0
    private var isIndeterminate = true

    private override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        frame = UIScreen.main.bounds
        backgroundColor = .clear

        backgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        backgroundView.frame = bounds
        addSubview(backgroundView)

        containerView.backgroundColor = .white
        containerView.layer.cornerRadius = 12
        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)

        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        progressView.translatesAutoresizingMaskIntoConstraints = false

        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.isHidden = true
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        containerView.addSubview(titleLabel)
        containerView.addSubview(progressView)
        containerView.addSubview(cancelButton)

        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 220),
            containerView.heightAnchor.constraint(equalToConstant: 130),

            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),

            progressView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            progressView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            progressView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            progressView.heightAnchor.constraint(equalToConstant: 4),

            cancelButton.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 12),
            cancelButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor)
        ])
    }

    func show(title: String, showCancel: Bool = false) {
        DispatchQueue.main.async {
            self.titleLabel.text = title
            self.cancelButton.isHidden = !showCancel
            self.progressView.progress = 0
            self.currentProgress = 0
            self.isIndeterminate = true
            self.startIndeterminateAnimation()

            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
                if self.superview != window {
                    self.removeFromSuperview()
                    window.addSubview(self)
                }
            }
        }
    }

    func updateProgress(_ progress: Float) {
        DispatchQueue.main.async {
            self.stopIndeterminateAnimation()
            self.isIndeterminate = false
            self.currentProgress = progress
            self.progressView.setProgress(progress / 100.0, animated: true)
        }
    }

    func hide() {
        DispatchQueue.main.async {
            self.stopIndeterminateAnimation()
            self.removeFromSuperview()
        }
    }

    @objc private func cancelTapped() {
        hide()
    }

    // MARK: - Indeterminate animation

    private func startIndeterminateAnimation() {
        stopIndeterminateAnimation()
        indeterminateTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] _ in
            guard let self = self, self.isIndeterminate else { return }
            self.currentProgress += 0.01
            if self.currentProgress > 1.0 {
                self.currentProgress = 0.0
            }
            self.progressView.setProgress(self.currentProgress, animated: false)
        }
    }

    private func stopIndeterminateAnimation() {
        indeterminateTimer?.invalidate()
        indeterminateTimer = nil
    }
}
