//
//  BottomPopupViewController.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 9/4/25.
//

import UIKit

final class BottomPopupViewController: UIViewController {
    private let containerView = UIView()
    private var heightConstraint: NSLayoutConstraint!
    
    private let contentVC: UIViewController
    
    init(contentVC: UIViewController) {
        self.contentVC = contentVC
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        // nền mờ
        view.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        
        // container
        containerView.backgroundColor = .clear
        containerView.layer.cornerRadius = 16
        containerView.clipsToBounds = true
        view.addSubview(containerView)
        
        containerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        heightConstraint = containerView.heightAnchor.constraint(equalToConstant: 0)
        heightConstraint.isActive = true
        
        // nhúng contentVC
        addChild(contentVC)
        containerView.addSubview(contentVC.view)
        contentVC.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentVC.view.topAnchor.constraint(equalTo: containerView.topAnchor),
            contentVC.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            contentVC.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            contentVC.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        contentVC.didMove(toParent: self)
        
        // tap nền để đóng
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissPopup))
        view.addGestureRecognizer(tap)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateHeightAndAnimateIn()
    }
    
    private func updateHeightAndAnimateIn() {
        // tính height theo content
        let targetHeight = contentVC.view.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height
        heightConstraint.constant = targetHeight
        view.layoutIfNeeded()   // ép layout trước khi set transform
        
        // bắt đầu từ dưới
        containerView.transform = CGAffineTransform(translationX: 0, y: view.bounds.height)
        
        UIView.animate(withDuration: 0.3,
                       delay: 0,
                       options: [.curveEaseOut]) {
            self.containerView.transform = .identity
            self.view.layoutIfNeeded()
        }
    }
    
    @objc private func dismissPopup() {
        animateOut { [weak self] in
            self?.dismiss(animated: false)
        }
    }
    
    private func animateOut(completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0.25,
                       delay: 0,
                       options: [.curveEaseIn]) {
            self.containerView.transform = CGAffineTransform(translationX: 0, y: self.view.bounds.height)
            self.view.backgroundColor = .clear
        } completion: { _ in
            completion()
        }
    }
}
