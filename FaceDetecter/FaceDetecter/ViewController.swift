//
//  ViewController.swift
//  FaceDetecter
//
//  Created by Abboskhon on 24/04/23.
//

import UIKit
import ARKit
import SceneKit
import Vision
import CoreImage
import Photos


struct ForeheadPoints {
    let center: UIColor?
    let left1: UIColor?
    let left2: UIColor?
    let left3: UIColor?
    let left4: UIColor?
    let right1: UIColor?
    let right2: UIColor?
    let right3: UIColor?
    let right4: UIColor?
}

class ViewController: UIViewController, ARSCNViewDelegate {

    var backgroundNode:SCNNode?
    var hairNode: SCNNode?
    
    var lastUpdated: Date?
    
    private let context = CIContext()

    private let sceneView: ARSCNView = {
        let sceneView = ARSCNView()
        sceneView.translatesAutoresizingMaskIntoConstraints = false
        return sceneView
    }()
    
    private let headView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .green
        
        return view
    }()
    
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        return imageView
    }()
    
    private lazy var actionButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
        button.backgroundColor = .black
        
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupConstraints()

        sceneView.delegate = self
        sceneView.automaticallyUpdatesLighting = true
        
        // Set up the AR session with face tracking
        let configuration = ARFaceTrackingConfiguration()
//        if ARFaceTrackingConfiguration.supportsFrameSemantics(.personSegmentation) {
//            configuration.frameSemantics.insert(.personSegmentation)
//        } else {
//            print("Available from ios 13")
////              presentAlert(NSLocalizedString("You can not use People Occlusion in this device.", comment: ""))
//        }

        
        sceneView.session.run(configuration)
        
        
        hairNode = createHairNode()
    }
    
    @objc private func buttonTapped() {
        let snapshot = sceneView.snapshot()
        saveImageToPhotoLibrary(image: snapshot)
    }
    
    func saveImageToPhotoLibrary(image: UIImage) {
        // First, we need to check for the photo library permission
        let status = PHPhotoLibrary.authorizationStatus()
        if (status == PHAuthorizationStatus.authorized) {
            // Access has been granted.
            saveImageToGallery(image: image)
        }
        else if (status == PHAuthorizationStatus.denied) {
            // Access has been denied.
            print("Access to photo library is denied.")
        }
        else if (status == PHAuthorizationStatus.notDetermined) {
            // Access has not been determined.
            PHPhotoLibrary.requestAuthorization({ (newStatus) in
                if (newStatus == PHAuthorizationStatus.authorized) {
                    self.saveImageToGallery(image: image)
                }
                else {
                    print("Access to photo library is not determined.")
                }
            })
        }
        else if (status == PHAuthorizationStatus.restricted) {
            // Restricted access - normally won't happen.
            print("Access to photo library is restricted.")
        }
    }
    
    func saveImageToGallery(image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }
    
    private func setupViews() {
        view.addSubview(sceneView)
        view.addSubview(imageView)
        view.addSubview(actionButton)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            sceneView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            sceneView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sceneView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sceneView.heightAnchor.constraint(equalToConstant: UIScreen.main.bounds.height / 2),
//            sceneView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
            
            imageView.topAnchor.constraint(equalTo: sceneView.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -50),
            
            actionButton.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 0),
            actionButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            actionButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            actionButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
            
        ])
    }
    
    private func createHairNode() -> SCNNode {
        guard let hairScene = SCNScene(named: "Lysina_alien.dae") else {
            print("Failed to load hair model")
            return SCNNode()
        }
        
        let hairNode = SCNNode()
        for childNode in hairScene.rootNode.childNodes {
            hairNode.addChildNode(childNode)
        }
        
        hairNode.renderingOrder = 1

        for material in hairNode.geometry?.materials ?? [] {
            material.readsFromDepthBuffer = false
        }
        
        return hairNode
    }
    
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        // Check if a face is being tracked
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        
        if backgroundNode == nil {
//            backgroundNode = createBackgroundNode()
//            backgroundNode?.position = SCNVector3(faceAnchor.transform.columns.3.x, faceAnchor.transform.columns.3.y, -10)
//            backgroundNode?.renderingOrder = -1

//            node.addChildNode(backgroundNode!)
//            sceneView.scene.rootNode.addChildNode(backgroundNode!)
        }
        
        // Position and orient the hair model
        if let hairNode = hairNode {
            hairNode.position = SCNVector3(faceAnchor.transform.columns.3.x, faceAnchor.transform.columns.3.y, faceAnchor.transform.columns.3.z)
            hairNode.transform = SCNMatrix4(faceAnchor.transform)

            // Adjust the scale of the hair model
            hairNode.scale = SCNVector3(0.011, 0.011, 0.011)

            // Check if three seconds have passed since the last update
            if let lastUpdated = lastUpdated, Date().timeIntervalSince(lastUpdated) < 3 {
                return
            }

            // Update the time of the last update
            lastUpdated = Date()

            // Get the average skin color from the camera image
            if let pixelBuffer = sceneView.session.currentFrame?.capturedImage {
                let (leftColor1, leftColor2, leftColor3, leftColor4, centerColor, rightColor1, rightColor2, rightColor3, rightColor4) = getAverageSkinColor(from: pixelBuffer)
                
//                let view = UIView()
//                view.backgroundColor = .red
                
                let color = UIColor(red: 255 / 255, green: 255 / 255, blue: 255 / 255, alpha: 0.8)
                let boldMaterial = SCNMaterial()
//                boldMaterial.diffuse.contents = headView
                
                DispatchQueue.main.async {
                    let imageFromView = UIImage(named: "rabbit")!
                    if let blurredImage = self.blur(image: imageFromView) {
                        boldMaterial.diffuse.contents = blurredImage
                    }
                }


                // Create new materials with different colors
                let topMaterial = SCNMaterial()
                topMaterial.diffuse.contents = centerColor

                let leftForeheadMaterial = SCNMaterial()
                leftForeheadMaterial.diffuse.contents = leftColor1
                
                let leftMaterial4 = SCNMaterial()
                leftMaterial4.diffuse.contents = leftColor2
                
                let leftMaterial3 = SCNMaterial()
                leftMaterial3.diffuse.contents = leftColor3
                
                let leftMaterial2 = SCNMaterial()
                leftMaterial2.diffuse.contents = leftColor4
                
                let leftMaterial1 = SCNMaterial()
                leftMaterial1.diffuse.contents = leftColor4

                let rightForeheadMaterial = SCNMaterial()
                rightForeheadMaterial.diffuse.contents = rightColor1
                
                let rightMaterial4 = SCNMaterial()
                rightMaterial4.diffuse.contents = rightColor2
                
                let rightMaterial3 = SCNMaterial()
                rightMaterial3.diffuse.contents = rightColor3
                
                let rightMaterial2 = SCNMaterial()
                rightMaterial2.diffuse.contents = rightColor4
                
                let rightMaterial1 = SCNMaterial()
                rightMaterial1.diffuse.contents = rightColor4
                
                let foreheadNode = hairNode.childNode(withName: "bald", recursively: true)
                foreheadNode?.geometry?.firstMaterial = topMaterial
                
                let leftForeheadNode = hairNode.childNode(withName: "Helmet", recursively: true)
                leftForeheadNode?.geometry?.firstMaterial = boldMaterial

                // Apply the materials to the respective child nodes
//                let foreheadNode = hairNode.childNode(withName: "Top", recursively: true)
//                foreheadNode?.geometry?.firstMaterial = topMaterial

//                let leftForeheadNode = hairNode.childNode(withName: "Left_forehead", recursively: true)
//                leftForeheadNode?.geometry?.firstMaterial = leftForeheadMaterial
                
                let leftNode4 = hairNode.childNode(withName: "Left_4", recursively: true)
                leftNode4?.geometry?.firstMaterial = leftMaterial4
                
                let leftNode3 = hairNode.childNode(withName: "Left_3", recursively: true)
                leftNode3?.geometry?.firstMaterial = leftMaterial3
                
                let leftNode2 = hairNode.childNode(withName: "Left_2", recursively: true)
                leftNode2?.geometry?.firstMaterial = leftMaterial2
                
                let leftNode1 = hairNode.childNode(withName: "Left_1", recursively: true)
                leftNode1?.geometry?.firstMaterial = leftMaterial1

                let rightForeheadNode = hairNode.childNode(withName: "Right_forehead", recursively: true)
                rightForeheadNode?.geometry?.firstMaterial = rightForeheadMaterial
                
                let rightNode4 = hairNode.childNode(withName: "Right_4", recursively: true)
                rightNode4?.geometry?.firstMaterial = rightMaterial4
                
                let rightNode3 = hairNode.childNode(withName: "Right_3", recursively: true)
                rightNode3?.geometry?.firstMaterial = rightMaterial3
                
                let rightNode2 = hairNode.childNode(withName: "Right_2", recursively: true)
                rightNode2?.geometry?.firstMaterial = rightMaterial2
                
                let rightNode1 = hairNode.childNode(withName: "Right_1", recursively: true)
                rightNode1?.geometry?.firstMaterial = rightMaterial1

                // Add the hair model as a child of the scene root node
//                node.addChildNode(hairNode)
                sceneView.scene.rootNode.addChildNode(hairNode)
//                node.renderingOrder = 1
            }
            

            
            
        } else {
            print("NO NODE")
        }
    }

    private func createBackgroundNode() -> SCNNode {
        
        let uiImage = UIImage(named: "image")!
        let size: CGFloat = 10
        
        let width = uiImage.size.width
        let height = uiImage.size.height
        let mediaAspectRatio = Double(width / height)
        let cgImage = uiImage.cgImage
        let newUiImage = UIImage(cgImage: cgImage!, scale: 1.0, orientation: .up)
        let skScene = SKScene(size: CGSize(width: 1000  * mediaAspectRatio, height: 1000))
        let texture = SKTexture(image:newUiImage)
        let skNode = SKSpriteNode(texture:texture)
        skNode.position = CGPoint(x: skScene.size.width / 2.0, y: skScene.size.height / 2.0)
        skNode.size = skScene.size
        skNode.yScale = -1.0
        skScene.addChild(skNode)
        let node = SCNNode()
//        node.renderingOrder = -1
        node.geometry = SCNPlane(width: size, height: size)
        let material = SCNMaterial()
        
        node.geometry?.firstMaterial = material
        material.diffuse.contents = skScene
        node.geometry?.materials = [material]
        node.geometry?.firstMaterial?.diffuse.contents = UIColor.white
        node.scale = SCNVector3(1.7  * mediaAspectRatio, 1.7, 1)
//        node.position = position()
//        node.position = SCNVector3(x: 0, y: 0, z: -1)

//        sceneView.scene.rootNode.addChildNode(node)
        
        

        // Return the created node
        return node
    }
    
    private func position()->SCNVector3 {
        let cameraPosition = sceneView.pointOfView?.scale
        let position = SCNVector3(cameraPosition!.x, cameraPosition!.y, cameraPosition!.z - 10)
        print(position)
        return position
    }
    
    func getAverageSkinColor(from pixelBuffer: CVPixelBuffer) -> (UIColor?, UIColor?, UIColor?, UIColor?, UIColor?, UIColor?, UIColor?, UIColor?, UIColor?) {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        let faceDetectionRequest = VNDetectFaceRectanglesRequest()

        let requestHandler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        try? requestHandler.perform([faceDetectionRequest])

        guard let results = faceDetectionRequest.results,
                let firstFace = results.first else {
            return (nil, nil, nil, nil, nil, nil, nil, nil, nil)
        }
        
        let faceBounds = CGRect(x: firstFace.boundingBox.origin.x * ciImage.extent.size.width,
                                y: firstFace.boundingBox.origin.y * ciImage.extent.size.height,
                                width: firstFace.boundingBox.size.width * ciImage.extent.size.width,
                                height: firstFace.boundingBox.size.height * ciImage.extent.size.height)

        let centerForeheadBounds = CGRect(
            x: faceBounds.origin.x - (faceBounds.height / 24),
            y: faceBounds.origin.y + (faceBounds.width / 2),
            width: faceBounds.width / 18,
            height: faceBounds.height / 18)
        
        let foreheadBoundsForUIImage = CGRect(
            x: centerForeheadBounds.origin.x,
            y: centerForeheadBounds.origin.y - centerForeheadBounds.height,
            width: centerForeheadBounds.width,
            height: centerForeheadBounds.height
        )
        
        let leftBounds1 = CGRect(
            x: foreheadBoundsForUIImage.origin.x,
            y: foreheadBoundsForUIImage.origin.y + (foreheadBoundsForUIImage.width + 5),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )
        let leftBounds2 = CGRect(
            x: foreheadBoundsForUIImage.origin.x,
            y: foreheadBoundsForUIImage.origin.y + (foreheadBoundsForUIImage.width + 10),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )
        let leftBounds3 = CGRect(
            x: foreheadBoundsForUIImage.origin.x,
            y: foreheadBoundsForUIImage.origin.y + (foreheadBoundsForUIImage.width + 15),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )
        let leftBounds4 = CGRect(
            x: foreheadBoundsForUIImage.origin.x,
            y: foreheadBoundsForUIImage.origin.y + (foreheadBoundsForUIImage.width + 20),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )
        
        let rightBounds1 = CGRect(
            x: foreheadBoundsForUIImage.origin.x,
            y: foreheadBoundsForUIImage.origin.y - (foreheadBoundsForUIImage.width + 5),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )
        let rightBounds2 = CGRect(
            x: foreheadBoundsForUIImage.origin.x,
            y: foreheadBoundsForUIImage.origin.y - (foreheadBoundsForUIImage.width + 10),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )
        let rightBounds3 = CGRect(
            x: foreheadBoundsForUIImage.origin.x,
            y: foreheadBoundsForUIImage.origin.y - (foreheadBoundsForUIImage.width + 15),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )
        let rightBounds4 = CGRect(
            x: foreheadBoundsForUIImage.origin.x,
            y: foreheadBoundsForUIImage.origin.y - (foreheadBoundsForUIImage.width + 20),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )
        
        DispatchQueue.main.async {
            let blurEffect = UIBlurEffect(style: .dark)
            let blurredEffectView = UIVisualEffectView(effect: blurEffect)

            blurredEffectView.frame = centerForeheadBounds
            blurredEffectView.frame = leftBounds1
            blurredEffectView.frame = leftBounds2
            blurredEffectView.frame = leftBounds3
            blurredEffectView.frame = leftBounds4
            blurredEffectView.frame = rightBounds1
            blurredEffectView.frame = rightBounds2
            blurredEffectView.frame = rightBounds3
            blurredEffectView.frame = rightBounds4
        }
    
        let visualizedForeheadImage = visualizeForeheadRegion(in: ciImage, with: centerForeheadBounds)
        
        DispatchQueue.main.async {
            self.imageView.image = visualizedForeheadImage
        }

        let centerForeheadCiImage = ciImage.cropped(to: foreheadBoundsForUIImage)
        let leftForeheadCiImage1 = ciImage.cropped(to: leftBounds1)
        let leftForeheadCiImage2 = ciImage.cropped(to: leftBounds2)
        let leftForeheadCiImage3 = ciImage.cropped(to: leftBounds3)
        let leftForeheadCiImage4 = ciImage.cropped(to: leftBounds4)
        let rightForeheadCiImage1 = ciImage.cropped(to: rightBounds1)
        let rightForeheadCiImage2 = ciImage.cropped(to: rightBounds2)
        let rightForeheadCiImage3 = ciImage.cropped(to: rightBounds3)
        let rightForeheadCiImage4 = ciImage.cropped(to: rightBounds4)

        // Calculate the average color of the forehead
        let centerAverageColor = centerForeheadCiImage.averageColor()
        let leftAverageColor1 = leftForeheadCiImage1.averageColor()
        let leftAverageColor2 = leftForeheadCiImage2.averageColor()
        let leftAverageColor3 = leftForeheadCiImage3.averageColor()
        let leftAverageColor4 = leftForeheadCiImage4.averageColor()
        let rightAverageColor1 = rightForeheadCiImage1.averageColor()
        let rightAverageColor2 = rightForeheadCiImage2.averageColor()
        let rightAverageColor3 = rightForeheadCiImage3.averageColor()
        let rightAverageColor4 = rightForeheadCiImage4.averageColor()

        return (leftAverageColor1, leftAverageColor2, leftAverageColor3, leftAverageColor4, centerAverageColor, rightAverageColor1, rightAverageColor2, rightAverageColor3, rightAverageColor4)
    }

    func visualizeForeheadRegion(in ciImage: CIImage, with foreheadBounds: CGRect) -> UIImage? {
        let context = CIContext(options: nil)

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }

        let uiImage = UIImage(cgImage: cgImage)

        // Begin a new image context
        UIGraphicsBeginImageContextWithOptions(uiImage.size, false, 0.0)

        let graphicsContext = UIGraphicsGetCurrentContext()

        // Draw the original image
        uiImage.draw(in: CGRect(x: 0, y: 0, width: uiImage.size.width, height: uiImage.size.height))

        // Set the stroke color
        graphicsContext?.setStrokeColor(UIColor.red.cgColor)
        
        // Convert the coordinates from CIImage to UIImage
        let foreheadBoundsForUIImage = CGRect(
            x: foreheadBounds.origin.x,
            y: uiImage.size.height - foreheadBounds.origin.y - foreheadBounds.height,
            width: foreheadBounds.width,
            height: foreheadBounds.height
        )

        // Draw the rectangle in the center of the forehead
        graphicsContext?.stroke(foreheadBoundsForUIImage, width: 2)
        
        // Calculate the bounds for the left and right rectangles
        let leftBounds1 = CGRect(
            x: foreheadBoundsForUIImage.origin.x,
            y: foreheadBoundsForUIImage.origin.y + (foreheadBoundsForUIImage.width + 5),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )
        let leftBounds2 = CGRect(
            x: foreheadBoundsForUIImage.origin.x,
            y: foreheadBoundsForUIImage.origin.y + (foreheadBoundsForUIImage.width + 10),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )
        let leftBounds3 = CGRect(
            x: foreheadBoundsForUIImage.origin.x,
            y: foreheadBoundsForUIImage.origin.y + (foreheadBoundsForUIImage.width + 15),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )
        let leftBounds4 = CGRect(
            x: foreheadBoundsForUIImage.origin.x,
            y: foreheadBoundsForUIImage.origin.y + (foreheadBoundsForUIImage.width + 20),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )
        
        let rightBounds1 = CGRect(
            x: foreheadBoundsForUIImage.origin.x,
            y: foreheadBoundsForUIImage.origin.y - (foreheadBoundsForUIImage.width + 5),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )
        let rightBounds2 = CGRect(
            x: foreheadBoundsForUIImage.origin.x,
            y: foreheadBoundsForUIImage.origin.y - (foreheadBoundsForUIImage.width + 10),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )
        let rightBounds3 = CGRect(
            x: foreheadBoundsForUIImage.origin.x,
            y: foreheadBoundsForUIImage.origin.y - (foreheadBoundsForUIImage.width + 15),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )
        let rightBounds4 = CGRect(
            x: foreheadBoundsForUIImage.origin.x,
            y: foreheadBoundsForUIImage.origin.y - (foreheadBoundsForUIImage.width + 20),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )

        // Draw the rectangles on the left and right of the forehead
        graphicsContext?.stroke(leftBounds1, width: 2)
        graphicsContext?.stroke(leftBounds2, width: 2)
        graphicsContext?.stroke(leftBounds3, width: 2)
        graphicsContext?.stroke(leftBounds4, width: 2)
        graphicsContext?.stroke(rightBounds1, width: 2)
        graphicsContext?.stroke(rightBounds2, width: 2)
        graphicsContext?.stroke(rightBounds3, width: 2)
        graphicsContext?.stroke(rightBounds4, width: 2)

        // Get the new image
        let newImage = UIGraphicsGetImageFromCurrentImageContext()

        // End the graphics context
        UIGraphicsEndImageContext()

        return newImage
    }
    
    func blur(image: UIImage) -> UIImage? {
        let context = CIContext(options: nil)
        let inputImage = CIImage(image: image)
        
        let filter = CIFilter(name: "CIGaussianBlur")
        filter?.setValue(inputImage, forKey: kCIInputImageKey)
        filter?.setValue(10.0, forKey: kCIInputRadiusKey)
        
        guard let outputImage = filter?.outputImage else { return nil }
        guard let outImage = context.createCGImage(outputImage, from: inputImage!.extent) else { return nil }
        
        return UIImage(cgImage: outImage)
    }
}
