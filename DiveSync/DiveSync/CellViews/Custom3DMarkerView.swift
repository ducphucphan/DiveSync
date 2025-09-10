//
//  Custom3DMarkerView.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 12/2/24.
//

import UIKit
import SceneKit
import DGCharts

class Custom3DMarkerView: MarkerView {
    private var sceneView: SCNView!
    
    var scene: SCNScene?
    var img: UIImageView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSceneView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupSceneView()
    }
    
    private func setupSceneView() {
        self.frame = CGRectMake(0, 0, 50, 50)
        self.offset = CGPoint(x: -self.frame.size.width / 2, y: -self.frame.size.height / 2)
        
        img = UIImageView(image: nil)
        img.frame = self.bounds
        addSubview(img)
        
        // Initialize SCNView for 3D rendering
        sceneView = SCNView(frame: self.bounds)
        sceneView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        sceneView.backgroundColor = .clear
        self.addSubview(sceneView)
        
        // Tạo Scene
        let scene = SCNScene()
        sceneView.scene = scene
        sceneView.allowsCameraControl = true // Cho phép điều khiển camera
        
        // Tải mô hình 3D từ file .obj
        guard let objURL = Bundle.main.url(forResource: "diving", withExtension: "obj") else {
            fatalError("Không tìm thấy tệp model.obj")
        }
        
        do {
            let objScene = try SCNScene(url: objURL, options: nil)
            if let objNode = objScene.rootNode.childNodes.first {
//                objNode.position = SCNVector3(0, 0, 0)
                objNode.geometry?.firstMaterial?.diffuse.contents = UIColor.orange // Đặt màu mặc định
                objNode.scale = SCNVector3(0.1, 0.1, 0.1) // Đặt kích thước hợp lý
                scene.rootNode.addChildNode(objNode)
                
                // Xoay mô hình
                let rotationAction = SCNAction.rotateBy(x: 0, y: CGFloat(Double.pi), z: 0, duration: 2)
                objNode.runAction(SCNAction.repeatForever(rotationAction))
            } else {
                PrintLog("Không tìm thấy node con trong file model.obj")
            }
        } catch {
            PrintLog("Lỗi khi tải file obj: \(error.localizedDescription)")
        }
        
        // Thêm ánh sáng
        let light = SCNLight()
        light.type = .omni
        let lightNode = SCNNode()
        lightNode.light = light
        lightNode.position = SCNVector3(x: 10, y: 10, z: 10)
        scene.rootNode.addChildNode(lightNode)
    }
    
    // Set up the marker with a specific scene
    func configure(with scene: SCNScene) {
        self.scene = scene
        sceneView.scene = scene
    }
    
    // Capture the scene as an image
    func captureSceneToImage() -> UIImage? {
        let snapshot = sceneView.snapshot() // Captures the current view as an image
        return snapshot
    }
    
    override func refreshContent(entry: ChartDataEntry, highlight: Highlight) {
        super.refreshContent(entry: entry, highlight: highlight)
        
        // Ép kiểu entry sang CustomChartDataEntry
        if let customEntry = entry as? CustomChartDataEntry,
           let sceneView = self.sceneView,
           let boxNode = sceneView.scene?.rootNode.childNodes.first {
            // Sử dụng thông tin góc xoay từ entry
            let rotationAngleX = customEntry.rotationAngleX * (Float.pi / 90)
            let rotationAngleY = customEntry.rotationAngleY * (Float.pi / 90)
            
            var v = boxNode.position
//            v.x = rotationAngleX
            v.y = rotationAngleY
            v.z = rotationAngleY
            
            boxNode.eulerAngles = v
            
            img.image = captureSceneToImage()
        }
    }
}
