//
//  FirmwarePageViewController.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 9/11/25.
//

import UIKit

class FirmwarePageViewController: UIViewController {
    
    private var pageViewController: UIPageViewController!
    private var pages: [UIViewController] = []
    private var pageControl: UIPageControl!
    
    var iniContent: String = ""
    var readmeContent: String = ""
    
    /// Callback khi user chọn I agree
    var onAgree: (() -> Void)?
    /// Callback khi user chọn I do not agree
    var onDisagree: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        setupPages()
        setupPageViewController()
        setupPageControl()
        setupButtons()
    }
    
    private func setupPages() {
        let iniVC = ContentViewController()
        
        if let range = iniContent.range(of: "\n\n") {
            let iniString = iniContent[range.upperBound...]
            iniVC.text = String(iniString)
        } else {
            iniVC.text = iniContent
        }
        
        let readmeVC = ContentViewController()
        readmeVC.text = readmeContent
        
        pages = [iniVC, readmeVC]
    }
    
    private func setupPageViewController() {
        pageViewController = UIPageViewController(transitionStyle: .scroll,
                                                  navigationOrientation: .horizontal,
                                                  options: nil)
        pageViewController.setViewControllers([pages[0]], direction: .forward, animated: true, completion: nil)
        pageViewController.dataSource = self
        pageViewController.delegate = self
        
        addChild(pageViewController)
        view.addSubview(pageViewController.view)
        pageViewController.didMove(toParent: self)
        
        // AutoLayout cho page view
        pageViewController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pageViewController.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            pageViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pageViewController.view.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -120) // chừa chỗ cho dot + nút
        ])
    }
    
    private func setupPageControl() {
        pageControl = UIPageControl()
        pageControl.numberOfPages = pages.count
        pageControl.currentPage = 0
        pageControl.currentPageIndicatorTintColor = .B_2
        pageControl.pageIndicatorTintColor = .lightGray
        view.addSubview(pageControl)
        
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pageControl.topAnchor.constraint(equalTo: pageViewController.view.bottomAnchor, constant: 8),
            pageControl.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
    
    private func setupButtons() {
        let agreeButton = UIButton(type: .system)
        agreeButton.setTitle("I agree", for: .normal)
        agreeButton.backgroundColor = .B_3
        agreeButton.setTitleColor(.white, for: .normal)
        agreeButton.layer.cornerRadius = 8
        agreeButton.addTarget(self, action: #selector(agreeTapped), for: .touchUpInside)
        
        let disagreeButton = UIButton(type: .system)
        disagreeButton.setTitle("I do not agree", for: .normal)
        disagreeButton.backgroundColor = .B_3
        disagreeButton.setTitleColor(.white, for: .normal)
        disagreeButton.layer.cornerRadius = 8
        disagreeButton.addTarget(self, action: #selector(disagreeTapped), for: .touchUpInside)
        
        let stack = UIStackView(arrangedSubviews: [agreeButton, disagreeButton])
        stack.axis = .horizontal
        stack.spacing = 12
        stack.distribution = .fillEqually
        view.addSubview(stack)
        
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            stack.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    @objc private func agreeTapped() {
        dismiss(animated: true) { [weak self] in
            self?.onAgree?()
        }
    }
    
    @objc private func disagreeTapped() {
        dismiss(animated: true) { [weak self] in
            self?.onDisagree?()
        }
    }
}

extension FirmwarePageViewController: UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let index = pages.firstIndex(of: viewController), index > 0 else { return nil }
        return pages[index - 1]
    }
    
    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let index = pages.firstIndex(of: viewController), index < pages.count - 1 else { return nil }
        return pages[index + 1]
    }
    
    func pageViewController(_ pageViewController: UIPageViewController,
                            didFinishAnimating finished: Bool,
                            previousViewControllers: [UIViewController],
                            transitionCompleted completed: Bool) {
        if completed, let currentVC = pageViewController.viewControllers?.first,
           let index = pages.firstIndex(of: currentVC) {
            pageControl.currentPage = index
        }
    }
}

// MARK: - Trang con hiển thị text
class ContentViewController: UIViewController {
    var text: String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        let textView = UITextView()
        textView.text = text
        textView.isEditable = false
        textView.font = UIFont.systemFont(ofSize: 16)
        view.addSubview(textView)
        
        textView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.topAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}
