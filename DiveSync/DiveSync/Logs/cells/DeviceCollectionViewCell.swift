//
//  DeviceCollectionViewCell.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 9/3/25.
//

import UIKit

final class DeviceCollectionViewCell: UICollectionViewCell {
    //@IBOutlet weak var containerView: UIView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    
    static let reuseIdentifier = "DeviceCell"
    
    override func awakeFromNib() {
        super.awakeFromNib()
        //setupAppearance()
    }
    
    private func setupAppearance() {
        //containerView.layer.cornerRadius = 12
        //containerView.clipsToBounds = true
        //containerView.backgroundColor = .secondarySystemBackground
        
        imageView.contentMode = .scaleAspectFit
        
        nameLabel.textAlignment = .center
        nameLabel.numberOfLines = 2
        nameLabel.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        
        statusLabel.textAlignment = .center
        statusLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        statusLabel.textColor = .systemGreen
    }
    
    override var isSelected: Bool {
        didSet {
            if isSelected {
                //containerView.layer.borderWidth = 2
                //containerView.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.45).cgColor
            } else {
                //containerView.layer.borderWidth = 0
                //containerView.layer.borderColor = UIColor.clear.cgColor
            }
        }
    }
    
    func configure(with item: Devices) {
        imageView.image = UIImage(named: "\(item.modelId ?? 0)") ?? UIImage(systemName: "8682")
        nameLabel.text = String(format: "%@-%05d", item.ModelName ?? "Unknown", item.SerialNo?.toInt() ?? 0)
        
        // Kiểm tra kết nối từ BluetoothDeviceCoordinator
        if let active = BluetoothDeviceCoordinator.shared.activeDataManager,
           active.SerialNo == item.SerialNo?.toInt(),
           active.ModelID == item.modelId ?? 0,
           active.peripheral.peripheral.state == .connected {
            
            statusLabel.isHidden = false
            statusLabel.text = "Connected"
            statusLabel.textColor = .systemGreen
        } else {
            statusLabel.isHidden = true
        }
        
    }
}
