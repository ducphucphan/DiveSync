//
//  AddDivesPopupViewController.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 9/4/25.
//

import Foundation

import UIKit

protocol AddLogsPopupDelegate: AnyObject {
    func popupDidTapAddManualLog(_ vc: AddDivesPopupViewController)
    func popup(_ vc: AddDivesPopupViewController, didSelect device: Devices)
    func popupDidTapAddNewDevice(_ vc: AddDivesPopupViewController)
}

final class AddDivesPopupViewController: UIViewController {
    // MARK: - Outlets (kết nối trong Storyboard)
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var closeButton: UIButton!
    @IBOutlet private weak var addManualLogButton: UIButton!
    @IBOutlet private weak var downloadTitleLabel: UILabel!
    @IBOutlet private weak var downloadSubtitleLabel: UILabel!
    @IBOutlet private weak var collectionView: UICollectionView!
    @IBOutlet private weak var emptyStateStack: UIStackView!
    @IBOutlet private weak var emptyStateLabel: UILabel!
    @IBOutlet private weak var addNewDeviceButton: UIButton!
    
    @IBOutlet weak var addManualLb: UILabel!
    
    
    weak var delegate: AddLogsPopupDelegate?
    
    // Demo data — thay bằng dữ liệu thực tế từ BLE
    var devices: [Devices] = []
    
    // Layout config
    private let columns: CGFloat = 2
    private let interItemSpacing: CGFloat = 8
    private let lineSpacing: CGFloat = 8
    private let contentInset: CGFloat = 8
    private let itemHeight: CGFloat = 150
    
    private let cellID = DeviceCollectionViewCell.reuseIdentifier
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        titleLabel.text = "Add Logs".localized
        addManualLb.text = "Add Manual Log".localized
        downloadTitleLabel.text = "Download Logs".localized
        downloadSubtitleLabel.text = "Please select a device below".localized + ":"
        emptyStateLabel.text = "No device to list.".localized
        addNewDeviceButton.setTitle("Add New Device".localized + "?", for: .normal)
        
        loadDevices()
        setupUI()
        setupCollectionView()
        reloadUI()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.itemSize = calculateItemSize()
        }
    }
    
    private func loadDevices() {
        devices = DatabaseManager.shared.fetchDevices() ?? []
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 16
        view.clipsToBounds = true
    }
    
    private func setupCollectionView() {
        collectionView.backgroundColor = .clear
        collectionView.showsVerticalScrollIndicator = false
        collectionView.delegate = self
        collectionView.dataSource = self
        
        // Flow layout
        let flow = UICollectionViewFlowLayout()
        flow.scrollDirection = .vertical
        flow.minimumInteritemSpacing = interItemSpacing
        flow.minimumLineSpacing = lineSpacing
        flow.sectionInset = UIEdgeInsets(top: contentInset, left: contentInset, bottom: contentInset, right: contentInset)
        collectionView.collectionViewLayout = flow
        
        // Nếu bạn dùng XIB cho cell (DeviceCollectionViewCell.xib), register nó.
        if Bundle.main.path(forResource: "DeviceCollectionViewCell", ofType: "nib") != nil {
            collectionView.register(UINib(nibName: "DeviceCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: cellID)
        }
        // Nếu bạn tạo prototype cell trong Storyboard (không dùng xib), không cần register.
    }
    
    private func calculateItemSize() -> CGSize {
        let width = collectionView.bounds.width
        // total horizontal spacing = leftInset + rightInset + (columns - 1) * interItemSpacing
        let totalSpacing = (contentInset * 2) + (columns - 1) * interItemSpacing
        let itemWidth = floor((width - totalSpacing) / columns)
        return CGSize(width: itemWidth, height: itemHeight)
    }
    
    private func reloadUI() {
        let isEmpty = devices.isEmpty
        //emptyStateStack.isHidden = !isEmpty
        collectionView.isHidden = isEmpty
        collectionView.reloadData()
    }
    
    // MARK: - Actions
    @IBAction private func closeTapped(_ sender: UIButton) {
        dismiss(animated: true)
    }
    
    @IBAction private func addManualLogTapped(_ sender: UIButton) {
        delegate?.popupDidTapAddManualLog(self)
    }
    
    @IBAction private func addNewDeviceTapped(_ sender: UIButton) {
        delegate?.popupDidTapAddNewDevice(self)
    }
}

// MARK: - UICollectionViewDataSource & Delegate
extension AddDivesPopupViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        devices.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellID, for: indexPath) as? DeviceCollectionViewCell else {
            // Fallback: create a basic cell if something is wrong (shouldn't happen if storyboard/xib configured)
            let fallback = UICollectionViewCell()
            fallback.backgroundColor = .secondarySystemBackground
            return fallback
        }
        let item = devices[indexPath.item]
        cell.configure(with: item)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = devices[indexPath.item]
        
        // Haptic feedback
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.impactOccurred()
        
        delegate?.popup(self, didSelect: item)
    }
}
