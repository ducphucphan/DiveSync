//
//  PhotosViewController.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 5/7/25.
//

import UIKit
import GRDB
import Lightbox   // NEW >>> Thêm Lightbox

class PhotosViewController: BaseViewController {
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    @IBOutlet weak var noPhotosLabel: UILabel!
    @IBOutlet weak var addLb: UILabel!
    @IBOutlet weak var shareLb: UILabel!
    @IBOutlet weak var removeLb: UILabel!
    
    @IBOutlet weak var addView: UIView!
    @IBOutlet weak var shareView: UIView!
    @IBOutlet weak var deleteView: UIView!
    
    var selectedIndexes = Set<Int>()
    var isDeleteMode = false
    var photoColumnNumber = 3
    
    var photos: [URL] = []
    var lightboxImages: [LightboxImage] = []   // NEW >>> Dùng cho Lightbox
    
    var diveLog: Row!
    var onUpdated: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.setCustomTitle(for: self.navigationItem,
                                                  title: self.title ?? "Photos".localized,
                                                  pushBack: true,
                                                  backImage: "chevron.backward")
        self.title = nil
        
        noPhotosLabel.text = "No Photos Added".localized
        addLb.text = "Add".localized
        shareLb.text = "Share".localized
        removeLb.text = "Remove".localized
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            photoColumnNumber = 4
        }
        
        configCollectionView()
        addLongPressGesture()   // NEW >>> Thêm gesture long press
        loadPhotos()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if self.isMovingFromParent {
            onUpdated?()
        }
    }
    
    private func configCollectionView() {
        collectionView.delegate = self
        collectionView.dataSource = self
        
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 8
        layout.minimumInteritemSpacing = 8
        collectionView.collectionViewLayout = layout
    }
    
    private func addLongPressGesture() {   // NEW >>> Thêm long press
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        collectionView.addGestureRecognizer(longPress)
    }
    
    private func prepareLightboxImages() {   // NEW >>> Tạo Lightbox data
        lightboxImages = photos.compactMap { url in
            if let image = UIImage(contentsOfFile: url.path) {
                return LightboxImage(image: image)
            }
            return nil
        }
    }
    
    @IBAction private func shareTapped(_ sender: UIButton) {
        // Lấy tất cả ảnh được chọn
        let images = selectedIndexes.compactMap { index in
            UIImage(contentsOfFile: photos[index].path)
        }
        
        guard !images.isEmpty else { return }
        
        // Gọi tiện ích share có sẵn
        Utilities.share(items: images, from: self, sourceView: sender)
    }
    
    @IBAction private func removeTapped(_ sender: UIButton) {
        PrivacyAlert.showMessage(message: "Are you sure to want to delete selected photos?".localized,
                                 allowTitle: "Delete".localized.uppercased(),
                                 denyTitle: "Cancel".localized.uppercased()) { action in
            switch action {
            case .allow:
                var errors: [Error] = []
                
                for index in self.selectedIndexes {
                    let fileName = self.photos[index].lastPathComponent
                    do {
                        try DivePhotoManager.shared.deletePhoto(
                            fileName: fileName,
                            diveID: self.diveLog.intValue(key: "DiveID"),
                            modelID: self.diveLog.stringValue(key: "ModelID"),
                            serialNo: self.diveLog.stringValue(key: "SerialNo")
                        )
                    } catch {
                        errors.append(error)
                    }
                }
                
                self.exitDeleteMode()   // NEW >>> Sau khi xoá thì reset state
                self.loadPhotos()
                
                if !errors.isEmpty {
                    print("Có lỗi khi xoá một số ảnh:", errors)
                }
            case .deny:
                break
            }
        }
    }
    
    @IBAction func addImageTapped(_ sender: Any) {        
        let cameraAction = UIAlertAction(title: "Camera".localized, style: .default) { _ in
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                let cameraPicker = UIImagePickerController()
                cameraPicker.sourceType = .camera
                cameraPicker.delegate = self
                self.present(cameraPicker, animated: true)
            } else {
                let alert = UIAlertController(title: nil,
                                              message: "Camera not available on this device!".localized,
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK".localized, style: .default))
                self.present(alert, animated: true)
            }
        }
        
        let albumsAction = UIAlertAction(title: "Albums".localized, style: .default) { _ in
            let albumPicker = UIImagePickerController()
            albumPicker.sourceType = .photoLibrary
            albumPicker.delegate = self
            self.present(albumPicker, animated: true)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel".localized, style: .cancel)
        
        presentActionSheet(from: sender,
                           title: nil,
                           message: nil,
                           actions: [cameraAction, albumsAction, cancelAction])
    }
    
    private func loadPhotos() {
        do {
            let loadedPhotos = try DivePhotoManager.shared.loadPhotoPaths(
                forDiveID: diveLog.intValue(key: "DiveID"),
                modelID: diveLog.stringValue(key: "ModelID"),
                serialNo: diveLog.stringValue(key: "SerialNo")
            )
            
            // Lọc chỉ giữ lại URL trỏ tới file ảnh hợp lệ
            var validPhotos: [URL] = []
            
            for url in loadedPhotos {
                if FileManager.default.fileExists(atPath: url.path) {
                    validPhotos.append(url)
                } else {
                    // Xoá record trong DB nếu file không còn
                    let fileName = url.lastPathComponent
                    do {
                        try DivePhotoManager.shared.deletePhoto(
                            fileName: fileName,
                            diveID: self.diveLog.intValue(key: "DiveID"),
                            modelID: self.diveLog.stringValue(key: "ModelID"),
                            serialNo: self.diveLog.stringValue(key: "SerialNo")
                        )
                    } catch {}
                }
            }
            photos = validPhotos
        } catch {
            photos = []
        }
        
        noPhotosLabel.isHidden = !photos.isEmpty
        //if photos.isEmpty {
            deleteView.isHidden = true
            shareView.isHidden = true
        //}
        
        prepareLightboxImages()   // NEW >>> Refresh lightbox data
        collectionView.reloadData()
    }
    
    private func exitDeleteMode() {   // NEW >>> Thoát chế độ delete
        isDeleteMode = false
        selectedIndexes.removeAll()
        deleteView.isHidden = true
        shareView.isHidden = true
        collectionView.reloadData()
    }
    
    // MARK: - Gesture
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        let point = gesture.location(in: collectionView)
        guard let indexPath = collectionView.indexPathForItem(at: point) else { return }
        
        if gesture.state == .began {
            // Long press = chọn luôn và vào delete mode
            isDeleteMode = true
            selectedIndexes = [indexPath.item]
            deleteView.isHidden = false
            shareView.isHidden = false
            collectionView.reloadData()
        }
    }
}

extension PhotosViewController: UICollectionViewDelegateFlowLayout, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let numberOfColumns: CGFloat = CGFloat(photoColumnNumber)
        let spacing: CGFloat = 8
        let totalSpacing = spacing * (numberOfColumns - 1)
        let totalInsets: CGFloat = spacing * 2
        let availableWidth = collectionView.bounds.width - totalSpacing - totalInsets
        let itemWidth = floor(availableWidth / numberOfColumns)
        return CGSize(width: itemWidth, height: itemWidth)
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photos.count
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath) as! PhotoCell
        cell.mainImageView.image = UIImage(contentsOfFile: photos[indexPath.item].path)
        cell.isChecked = selectedIndexes.contains(indexPath.item)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if isDeleteMode {
            if selectedIndexes.contains(indexPath.item) {
                selectedIndexes.remove(indexPath.item)
            } else {
                selectedIndexes.insert(indexPath.item)
            }
            collectionView.reloadItems(at: [indexPath])
            
            // Nếu không còn ảnh nào được chọn thì thoát delete mode
            if selectedIndexes.isEmpty {
                exitDeleteMode()
            } else {
                deleteView.isHidden = false
                shareView.isHidden = false
            }
        } else {
            // Bình thường = mở Lightbox
            let controller = LightboxController(images: lightboxImages, startIndex: indexPath.item)
            controller.dynamicBackground = true
            present(controller, animated: true)
        }
    }
}

extension PhotosViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[.originalImage] as? UIImage {
            do {
                try DivePhotoManager.shared.addPhoto(
                    image,
                    diveID: diveLog.intValue(key: "DiveID"),
                    modelID: diveLog.stringValue(key: "ModelID"),
                    serialNo: diveLog.stringValue(key: "SerialNo")
                )
            } catch {}
            
            loadPhotos()
        }
        picker.dismiss(animated: true)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}
