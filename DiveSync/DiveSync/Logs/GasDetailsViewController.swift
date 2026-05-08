//
//  GasDetailsViewController.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 5/5/26.
//

import UIKit
import GRDB

class GasDetailsViewController: BaseViewController {

    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var pageControl: UIPageControl!
    
    var diveLog: Row!
    
    var tankList: [Row?] = []
    
    var onUpdated: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.setCustomTitle(for: self.navigationItem,
                                                  title: self.title ?? "Log - Gas Details".localized,
                                                  pushBack: true,
                                                  backImage: "chevron.backward")
        self.title = nil
        
        setupCollectionView()
        
        setupData()
    }
    
    private func setupData() {
        let count = gasNumber()
        // Lấy dữ liệu tất cả các tank và lưu vào mảng
        tankList = (1...count).map { getTankInfo(tankNo: $0) }
        
        // Cấu hình PageControl
        pageControl.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        pageControl.numberOfPages = count
        pageControl.isHidden = count <= 1
        collectionView.reloadData()
    }
    
    private func setupCollectionView() {
        collectionView.delegate = self
        collectionView.dataSource = self
        
        // Quan trọng để Paging hoạt động đúng
        collectionView.isPagingEnabled = true
        collectionView.showsHorizontalScrollIndicator = false
        
        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.scrollDirection = .horizontal
            layout.minimumLineSpacing = 0
            layout.minimumInteritemSpacing = 0
        }
    }
    
    private func gasNumber() -> Int {
        let modelID = diveLog.stringValue(key: "ModelID").toInt()
        if modelID == C_WIS5 {
            return 1
        }
        
        let diveMode = diveLog.stringValue(key: "DiveMode").toInt()
        if diveMode >= 100 {
            return 3
        }
        return 4
    }
    
    private func getTankInfo(tankNo: Int) -> Row? {
        return DatabaseManager.shared.fetchOrCreateTankData(tankNo: tankNo, diveId: diveLog.intValue(key: "DiveID"))
    }
    
    private func saveTankData(tankId: Int, key: String, value: Any) {
        DatabaseManager.shared.updateTable(tableName: "TankData",
                                           params: [key: value],
                                           conditions: "where TankID=\(tankId)")
    }
}

// MARK: - CollectionView DataSource & Delegate
extension GasDetailsViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return gasNumber()
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "GasCell", for: indexPath) as! GasCell
        cell.delegate = self
        
        let tankData = tankList[indexPath.item]
        cell.configure(with: diveLog, tankData: tankData, index: indexPath.item, numberOfGas: gasNumber())
        
        return cell
    }
    
    // Ép Cell Full Width để hiển thị mỗi bình gas một trang
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: collectionView.frame.height)
    }
    
    // Cập nhật PageControl khi người dùng vuốt
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let page = Int(scrollView.contentOffset.x / scrollView.frame.width)
        pageControl.currentPage = page
    }
}

// MARK: - GasCellDelegate
extension GasDetailsViewController: GasCellDelegate {
    
    func gasCell(_ cell: GasCell, didUpdateStartPressure pressure: Double, tankId: Int, at index: Int) {
        // tankId đã có sẵn, không cần fetch lại tankInfo nữa
        if tankId > 0 {
            saveTankData(tankId: tankId, key: "StartPressure", value: pressure)
            
            tankList[index] = getTankInfo(tankNo: index + 1)
            
            onUpdated?()
            print("Updated Tank \(tankId) StartPressure: \(pressure)")
        }
    }
    
    func gasCell(_ cell: GasCell, didUpdateEndPressure pressure: Double, tankId: Int, at index: Int) {
        if tankId > 0 {
            saveTankData(tankId: tankId, key: "EndPressure", value: pressure)
            
            tankList[index] = getTankInfo(tankNo: index + 1)
            
            onUpdated?()
            print("Updated Tank \(tankId) EndPressure: \(pressure)")
        }
    }
}
