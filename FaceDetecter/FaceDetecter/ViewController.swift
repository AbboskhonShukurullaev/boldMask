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
        guard let hairScene = SCNScene(named: "Phase_1.dae") else {
            print("Failed to load hair model")
            return SCNNode()
        }
        
        let hairNode = SCNNode()
        for childNode in hairScene.rootNode.childNodes {
            hairNode.addChildNode(childNode)
        }
        
        for material in hairNode.geometry?.materials ?? [] {
            material.readsFromDepthBuffer = false
        }
        
        return hairNode
    }
    
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        // Check if a face is being tracked
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        
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
                let (centerColor, leftColor1, leftColor2, leftColor3, leftColor4, leftColor5, rightColor1, rightColor2, rightColor3, rightColor4, rightColor5) = getAverageSkinColor(from: pixelBuffer)

                // Create new materials with different colors
                let topMaterial = SCNMaterial()
                topMaterial.diffuse.contents = centerColor

                let leftMaterial1 = SCNMaterial()
                leftMaterial1.diffuse.contents = leftColor1
                
                let leftMaterial2 = SCNMaterial()
                leftMaterial2.diffuse.contents = leftColor2
                
                let leftMaterial3 = SCNMaterial()
                leftMaterial3.diffuse.contents = leftColor3
                
                let leftMaterial4 = SCNMaterial()
                leftMaterial4.diffuse.contents = leftColor4
                
                let leftMaterial5 = SCNMaterial()
                leftMaterial5.diffuse.contents = leftColor5

                let rightMaterial1 = SCNMaterial()
                rightMaterial1.diffuse.contents = rightColor1
                
                let rightMaterial2 = SCNMaterial()
                rightMaterial2.diffuse.contents = rightColor2
                
                let rightMaterial3 = SCNMaterial()
                rightMaterial3.diffuse.contents = rightColor3
                
                let rightMaterial4 = SCNMaterial()
                rightMaterial4.diffuse.contents = rightColor4
                
                let rightMaterial5 = SCNMaterial()
                rightMaterial5.diffuse.contents = rightColor5

                let topNode = hairNode.childNode(withName: "Top_phase1-001", recursively: true)
                topNode?.geometry?.firstMaterial = topMaterial

                let leftNode1 = hairNode.childNode(withName: "Lob_left_phase1-1", recursively: true)
                leftNode1?.geometry?.firstMaterial = leftMaterial1
                
                let leftNode2 = hairNode.childNode(withName: "Lob_left_phase1-2", recursively: true)
                leftNode2?.geometry?.firstMaterial = leftMaterial2
                
                let leftNode3 = hairNode.childNode(withName: "Lob_left_phase1-3", recursively: true)
                leftNode3?.geometry?.firstMaterial = leftMaterial3
                
                let leftNode4 = hairNode.childNode(withName: "Lob_left_phase1-4", recursively: true)
                leftNode4?.geometry?.firstMaterial = leftMaterial4
                
                let leftNode5 = hairNode.childNode(withName: "Lob_left_phase1-5", recursively: true)
                leftNode5?.geometry?.firstMaterial = leftMaterial5

                let rightNode1 = hairNode.childNode(withName: "Lob_right_phase1-1", recursively: true)
                rightNode1?.geometry?.firstMaterial = rightMaterial1
                
                let rightNode2 = hairNode.childNode(withName: "Lob_right_phase1-2", recursively: true)
                rightNode2?.geometry?.firstMaterial = rightMaterial2
                
                let rightNode3 = hairNode.childNode(withName: "Lob_right_phase1-3", recursively: true)
                rightNode3?.geometry?.firstMaterial = rightMaterial3
                
                let rightNode4 = hairNode.childNode(withName: "Lob_right_phase1-4", recursively: true)
                rightNode4?.geometry?.firstMaterial = rightMaterial4
                
                let rightNode5 = hairNode.childNode(withName: "Lob_right_phase1-5", recursively: true)
                rightNode5?.geometry?.firstMaterial = rightMaterial5

                sceneView.scene.rootNode.addChildNode(hairNode)
            }

        } else {
            print("NO NODE")
        }
    }
    
    
    func getAverageSkinColor(from pixelBuffer: CVPixelBuffer) -> (UIColor?, UIColor?, UIColor?, UIColor?, UIColor?, UIColor?, UIColor?, UIColor?, UIColor?, UIColor?, UIColor?) {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        let faceDetectionRequest = VNDetectFaceRectanglesRequest()

        let requestHandler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        try? requestHandler.perform([faceDetectionRequest])

        guard let results = faceDetectionRequest.results,
                let firstFace = results.first else {
            return (nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil)
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
            y: foreheadBoundsForUIImage.origin.y + (foreheadBoundsForUIImage.width + 8),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )
        let leftBounds2 = CGRect(
            x: foreheadBoundsForUIImage.origin.x,
            y: foreheadBoundsForUIImage.origin.y + (foreheadBoundsForUIImage.width + 16),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )
        let leftBounds3 = CGRect(
            x: foreheadBoundsForUIImage.origin.x,
            y: foreheadBoundsForUIImage.origin.y + (foreheadBoundsForUIImage.width + 24),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )
        let leftBounds4 = CGRect(
            x: foreheadBoundsForUIImage.origin.x,
            y: foreheadBoundsForUIImage.origin.y + (foreheadBoundsForUIImage.width + 32),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )
        let leftBounds5 = CGRect(
            x: foreheadBoundsForUIImage.origin.x,
            y: foreheadBoundsForUIImage.origin.y + (foreheadBoundsForUIImage.width + 40),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )
        
        let rightBounds1 = CGRect(
            x: foreheadBoundsForUIImage.origin.x,
            y: foreheadBoundsForUIImage.origin.y - (foreheadBoundsForUIImage.width + 8),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )
        let rightBounds2 = CGRect(
            x: foreheadBoundsForUIImage.origin.x,
            y: foreheadBoundsForUIImage.origin.y - (foreheadBoundsForUIImage.width + 16),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )
        let rightBounds3 = CGRect(
            x: foreheadBoundsForUIImage.origin.x,
            y: foreheadBoundsForUIImage.origin.y - (foreheadBoundsForUIImage.width + 24),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )
        let rightBounds4 = CGRect(
            x: foreheadBoundsForUIImage.origin.x,
            y: foreheadBoundsForUIImage.origin.y - (foreheadBoundsForUIImage.width + 32),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )
        let rightBounds5 = CGRect(
            x: foreheadBoundsForUIImage.origin.x,
            y: foreheadBoundsForUIImage.origin.y - (foreheadBoundsForUIImage.width + 40),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )
    
        let visualizedForeheadImage = visualizeForeheadRegion(in: ciImage, with: centerForeheadBounds)
        
        DispatchQueue.main.async {
            self.imageView.image = visualizedForeheadImage
        }

        let centerForeheadCiImage = ciImage.cropped(to: foreheadBoundsForUIImage)
        let leftForeheadCiImage1 = ciImage.cropped(to: leftBounds1)
        let leftForeheadCiImage2 = ciImage.cropped(to: leftBounds2)
        let leftForeheadCiImage3 = ciImage.cropped(to: leftBounds3)
        let leftForeheadCiImage4 = ciImage.cropped(to: leftBounds4)
        let leftForeheadCiImage5 = ciImage.cropped(to: leftBounds5)
        let rightForeheadCiImage1 = ciImage.cropped(to: rightBounds1)
        let rightForeheadCiImage2 = ciImage.cropped(to: rightBounds2)
        let rightForeheadCiImage3 = ciImage.cropped(to: rightBounds3)
        let rightForeheadCiImage4 = ciImage.cropped(to: rightBounds4)
        let rightForeheadCiImage5 = ciImage.cropped(to: rightBounds5)

        // Calculate the average color of the forehead
        let centerAverageColor = centerForeheadCiImage.averageColor()
        let leftAverageColor1 = leftForeheadCiImage1.averageColor()
        let leftAverageColor2 = leftForeheadCiImage2.averageColor()
        let leftAverageColor3 = leftForeheadCiImage3.averageColor()
        let leftAverageColor4 = leftForeheadCiImage4.averageColor()
        let leftAverageColor5 = leftForeheadCiImage5.averageColor()
        let rightAverageColor1 = rightForeheadCiImage1.averageColor()
        let rightAverageColor2 = rightForeheadCiImage2.averageColor()
        let rightAverageColor3 = rightForeheadCiImage3.averageColor()
        let rightAverageColor4 = rightForeheadCiImage4.averageColor()
        let rightAverageColor5 = rightForeheadCiImage5.averageColor()

        return (centerAverageColor, leftAverageColor1, leftAverageColor2, leftAverageColor3, leftAverageColor4, leftAverageColor5, rightAverageColor1, rightAverageColor2, rightAverageColor3, rightAverageColor4, rightAverageColor5)
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
            y: foreheadBoundsForUIImage.origin.y + (foreheadBoundsForUIImage.width + 8),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )
        let leftBounds2 = CGRect(
            x: foreheadBoundsForUIImage.origin.x,
            y: foreheadBoundsForUIImage.origin.y + (foreheadBoundsForUIImage.width + 16),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )
        let leftBounds3 = CGRect(
            x: foreheadBoundsForUIImage.origin.x,
            y: foreheadBoundsForUIImage.origin.y + (foreheadBoundsForUIImage.width + 24),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )
        let leftBounds4 = CGRect(
            x: foreheadBoundsForUIImage.origin.x,
            y: foreheadBoundsForUIImage.origin.y + (foreheadBoundsForUIImage.width + 32),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )
        let leftBounds5 = CGRect(
            x: foreheadBoundsForUIImage.origin.x,
            y: foreheadBoundsForUIImage.origin.y + (foreheadBoundsForUIImage.width + 40),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )
        
        let rightBounds1 = CGRect(
            x: foreheadBoundsForUIImage.origin.x,
            y: foreheadBoundsForUIImage.origin.y - (foreheadBoundsForUIImage.width + 8),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )
        let rightBounds2 = CGRect(
            x: foreheadBoundsForUIImage.origin.x,
            y: foreheadBoundsForUIImage.origin.y - (foreheadBoundsForUIImage.width + 16),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )
        let rightBounds3 = CGRect(
            x: foreheadBoundsForUIImage.origin.x,
            y: foreheadBoundsForUIImage.origin.y - (foreheadBoundsForUIImage.width + 24),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )
        let rightBounds4 = CGRect(
            x: foreheadBoundsForUIImage.origin.x,
            y: foreheadBoundsForUIImage.origin.y - (foreheadBoundsForUIImage.width + 32),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )
        let rightBounds5 = CGRect(
            x: foreheadBoundsForUIImage.origin.x,
            y: foreheadBoundsForUIImage.origin.y - (foreheadBoundsForUIImage.width + 40),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )

        // Draw the rectangles on the left and right of the forehead
        graphicsContext?.stroke(leftBounds1, width: 2)
        graphicsContext?.stroke(leftBounds2, width: 2)
        graphicsContext?.stroke(leftBounds3, width: 2)
        graphicsContext?.stroke(leftBounds4, width: 2)
        graphicsContext?.stroke(leftBounds5, width: 2)
        graphicsContext?.stroke(rightBounds1, width: 2)
        graphicsContext?.stroke(rightBounds2, width: 2)
        graphicsContext?.stroke(rightBounds3, width: 2)
        graphicsContext?.stroke(rightBounds4, width: 2)
        graphicsContext?.stroke(rightBounds5, width: 2)

        // Get the new image
        let newImage = UIGraphicsGetImageFromCurrentImageContext()

        // End the graphics context
        UIGraphicsEndImageContext()

        return newImage
    }
}
