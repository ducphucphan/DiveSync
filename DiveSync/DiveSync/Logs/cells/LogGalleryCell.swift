//
//  LogGalleryCell.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 5/6/25.
//

import UIKit

class LogGalleryCell: UICollectionViewCell {
    
    @IBOutlet weak var photoCollectionView: UICollectionView!
    @IBOutlet weak var noPhotosLb: UILabel!
    
    @IBOutlet weak var nextBtn: UIButton!
    @IBOutlet weak var prevBtn: UIButton!
    //
    private let currentImageView = UIImageView()
    private let nextImageView = UIImageView()
    
    private var images: [UIImage] = []
    private var currentIndex = 0
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        noPhotosLb.isHidden = true
        
        photoCollectionView.delegate = self
        photoCollectionView.dataSource = self
        
        // paging setup
        if let layout = photoCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.scrollDirection = .horizontal
            layout.minimumLineSpacing = 0
            layout.minimumInteritemSpacing = 0
        }
        photoCollectionView.isPagingEnabled = true
        
        // **Tắt drag to scroll**
        photoCollectionView.isScrollEnabled = false
        
        photoCollectionView.showsHorizontalScrollIndicator = false
        photoCollectionView.register(UINib(nibName: "PhotoItemCell", bundle: nil), forCellWithReuseIdentifier: "PhotoItemCell")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        contentView.bringSubviewToFront(nextBtn)
        contentView.bringSubviewToFront(prevBtn)
    }
    
    func configure(with imageURLs: [URL]) {
        self.images = imageURLs.compactMap { UIImage(contentsOfFile: $0.path) }
        
        if self.images.count > 0 {
            noPhotosLb.isHidden = true
        } else {
            noPhotosLb.isHidden = false
        }
        
        currentIndex = 0
        
        updateButtonVisibility()
        
        photoCollectionView.reloadData()
    }
    
    @IBAction func nextTapped(_ sender: Any) {
        guard currentIndex < images.count - 1 else { return }
        currentIndex += 1
        scrollToIndex(currentIndex)
    }

    @IBAction func prevTapped(_ sender: Any) {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        scrollToIndex(currentIndex)
    }

    private func scrollToIndex(_ index: Int) {
        let indexPath = IndexPath(item: index, section: 0)
        photoCollectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
        updateButtonVisibility()
    }
    
    private func updateButtonVisibility() {
        prevBtn.isHidden = (currentIndex == 0)
        nextBtn.isHidden = (currentIndex >= images.count - 1)
    }
    
}

extension LogGalleryCell: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return images.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoItemCell", for: indexPath) as! PhotoItemCell
        cell.imageView.image = images[indexPath.row]
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return collectionView.bounds.size
    }
}
