//
//  ViewController.swift
//  FaceDetecter
//
//  Created by Abboskhon on 24/04/23.
//

import UIKit
import ARKit
//import SceneKit
import Photos
//import RealityKit


class ViewController: UIViewController {

    var hairNode: SCNNode?
    
    var lastUpdated: Date?
    
    var hairNodes: [String] = []
    

    private let sceneView: ARSCNView = {
        let sceneView = ARSCNView()
        sceneView.translatesAutoresizingMaskIntoConstraints = false
        sceneView.autoenablesDefaultLighting = false
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
        
        addHairNode()
    }
    
    @objc private func buttonTapped() {
        let snapshot = sceneView.snapshot()
        saveImageToPhotoLibrary(image: snapshot)
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
}

//MARK: - ARKit Mask Logic
extension ViewController: ARSCNViewDelegate {
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
            if let lastUpdated = lastUpdated, Date().timeIntervalSince(lastUpdated) < 1.5 {
                return
            }

            // Update the time of the last update
            lastUpdated = Date()

            // Get the average skin color from the camera image
            if let pixelBuffer = sceneView.session.currentFrame?.capturedImage {
                
                drawMaskSegments(from: pixelBuffer, for: hairNode)
            }

        } else {
            print("NO NODE")
        }
    }
    
    private func addHairNode() {
        hairNode = createHairNode()
        sceneView.scene.rootNode.addChildNode(hairNode!)
    }
    
    private func createHairNode() -> SCNNode {
        guard let hairScene = SCNScene(named: "Phase1.dae") else {
            print("Failed to load hair model")
            return SCNNode()
        }
        
        let hairNode = SCNNode()
        for child in hairScene.rootNode.childNodes {
            let copy = child.clone() // Deep copy of the node
            hairNode.addChildNode(copy)
        }
        
        // Make sure the node isn't empty before manipulating its geometry
        guard !hairNode.childNodes.isEmpty else {
            return hairNode
        }

        // Iterate over every child node
        hairNode.enumerateChildNodes { (node, stop) in
            if let geometry = node.geometry {
                geometry.materials.forEach { material in
                    material.readsFromDepthBuffer = false
                }
                hairNodes.append(node.name ?? "Unnamed")
            }
        }

        return hairNode
    }
    
    func image(from colors: [UIColor], size: CGSize = CGSize(width: 1, height: 1)) -> UIImage {
        let rect = CGRect(origin: .zero, size: size)
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
        guard let context = UIGraphicsGetCurrentContext() else { return UIImage() }
        let colorWidth = rect.width / CGFloat(colors.count)
        for (index, color) in colors.enumerated() {
            color.setFill()
            let stripeRect = CGRect(x: CGFloat(index) * colorWidth, y: 0, width: colorWidth, height: rect.height)
            context.fill(stripeRect)
        }
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image ?? UIImage()
    }

    
    private func applyColorChange(to node: SCNNode, withColor color: UIColor, duration: TimeInterval) {
        let colorChangeAction = SCNAction.customAction(duration: duration) { [weak self] (node, elapsedTime) in
            guard let self = self else { return }
            
            let percentage = elapsedTime / CGFloat(duration)
            if let initialColor = node.geometry?.firstMaterial?.diffuse.contents as? UIColor {
                let newColor = self.interpolate(from: initialColor, to: color, percentage: percentage)
                node.geometry?.firstMaterial?.diffuse.contents = newColor
                
                self.applyLight(to: node, color: newColor, intensity: 300)
            }
        }
        node.runAction(colorChangeAction)
    }
    
    private func applyLight(to node: SCNNode, color: UIColor, intensity: CGFloat) {
        let light = SCNLight()
        light.type = .probe
        light.color = color
        light.intensity = intensity
        
        node.light = light
    }

    private func interpolate(from: UIColor, to: UIColor, percentage: CGFloat) -> UIColor {
        var fromRed: CGFloat = 0, fromGreen: CGFloat = 0, fromBlue: CGFloat = 0, fromAlpha: CGFloat = 0
        from.getRed(&fromRed, green: &fromGreen, blue: &fromBlue, alpha: &fromAlpha)

        var toRed: CGFloat = 0, toGreen: CGFloat = 0, toBlue: CGFloat = 0, toAlpha: CGFloat = 0
        to.getRed(&toRed, green: &toGreen, blue: &toBlue, alpha: &toAlpha)

        return UIColor(
            red: self.lerp(fromRed, toRed, percentage),
            green: self.lerp(fromGreen, toGreen, percentage),
            blue: self.lerp(fromBlue, toBlue, percentage),
            alpha: self.lerp(fromAlpha, toAlpha, percentage)
        )
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        return a + (b - a) * t
    }

    private func spotMaterial(with color: UIColor) -> SCNMaterial {
        let spotMaterial = SCNMaterial()
        spotMaterial.diffuse.contents = color
        spotMaterial.lightingModel = .lambert

        return spotMaterial
    }
    
    
    private func textureMaterial(image: UIImage, color: UIColor) -> SCNMaterial {
        let spotMaterial = SCNMaterial()
        spotMaterial.diffuse.contents = image
        spotMaterial.diffuse.intensity = 1.0
        spotMaterial.diffuse.contentsTransform = SCNMatrix4MakeScale(1.0, 1.0, 0.0)
        spotMaterial.diffuse.wrapS = .repeat
        spotMaterial.diffuse.wrapT = .repeat

        var red: CGFloat = 0.0, green: CGFloat = 0.0, blue: CGFloat = 0.0, alpha: CGFloat = 0.0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        let width = Int(image.size.width)
        let height = Int(image.size.height)

        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        guard let context = UIGraphicsGetCurrentContext() else {
            return spotMaterial
        }

        image.draw(at: .zero)

        let colorRect = CGRect(x: 0, y: 0, width: width, height: height)
        context.setFillColor(red: red, green: green, blue: blue, alpha: alpha)
        context.setBlendMode(.sourceAtop)
        context.fill(colorRect)

        guard let blendedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            UIGraphicsEndImageContext()
            return spotMaterial
        }

        UIGraphicsEndImageContext()

        spotMaterial.diffuse.contents = blendedImage

        return spotMaterial
    }

    private func configureNode(node: SCNNode, material: SCNMaterial, opacity: CGFloat) {
        node.geometry?.firstMaterial = material
        node.opacity = opacity
        node.castsShadow = false
    }

    private func drawMaskSegments(from pixelBuffer: CVPixelBuffer, for hairNode: SCNNode) {
        let foreheadColors = getAverageSkinColor(from: pixelBuffer)
        let centerColor = foreheadColors.center
        //let spotMaterial = spotMaterial(with: centerColor)
        let textureMaterial = textureMaterial(
            image: UIImage(named: "Phase1_Texture_256_customDots")!,
            color: centerColor
        )
        
        
        for hairString in hairNodes {
            if let foreheadNode = hairNode.childNode(withName: hairString, recursively: true) {
                configureNode(node: foreheadNode, material: textureMaterial, opacity: 2.0)
                applyColorChange(to: foreheadNode, withColor: centerColor, duration: 1.5)
            }
        }
    }
    
    private func getAverageSkinColor(from pixelBuffer: CVPixelBuffer) -> (ForeheadColor) {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        let faceDetectionRequest = VNDetectFaceRectanglesRequest()

        let requestHandler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        try? requestHandler.perform([faceDetectionRequest])

        guard let results = faceDetectionRequest.results,
                let firstFace = results.first else {
            return ForeheadColor(center: UIColor.clear, left1: UIColor.clear, left2: UIColor.clear, left3: UIColor.clear, left4: UIColor.clear, left5: UIColor.clear, right1: UIColor.clear, right2: UIColor.clear, right3: UIColor.clear, right4: UIColor.clear, right5: UIColor.clear)
        }
        
        let faceBounds = CGRect(x: firstFace.boundingBox.origin.x * ciImage.extent.size.width,
                                y: firstFace.boundingBox.origin.y * ciImage.extent.size.height,
                                width: firstFace.boundingBox.size.width * ciImage.extent.size.width,
                                height: firstFace.boundingBox.size.height * ciImage.extent.size.height)

        let centerForeheadBounds = CGRect(
            x: faceBounds.origin.x - (faceBounds.height / 30),
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
            y: foreheadBoundsForUIImage.origin.y + (foreheadBoundsForUIImage.width + 7),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )
        let leftBounds2 = CGRect(
            x: foreheadBoundsForUIImage.origin.x,
            y: foreheadBoundsForUIImage.origin.y + (foreheadBoundsForUIImage.width + 14),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )
        let leftBounds3 = CGRect(
            x: foreheadBoundsForUIImage.origin.x,
            y: foreheadBoundsForUIImage.origin.y + (foreheadBoundsForUIImage.width + 21),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )
        let leftBounds4 = CGRect(
            x: foreheadBoundsForUIImage.origin.x,
            y: foreheadBoundsForUIImage.origin.y + (foreheadBoundsForUIImage.width + 28),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )
        let leftBounds5 = CGRect(
            x: foreheadBoundsForUIImage.origin.x,
            y: foreheadBoundsForUIImage.origin.y + (foreheadBoundsForUIImage.width + 35),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )
        
        let rightBounds1 = CGRect(
            x: foreheadBoundsForUIImage.origin.x,
            y: foreheadBoundsForUIImage.origin.y - (foreheadBoundsForUIImage.width + 7),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )
        let rightBounds2 = CGRect(
            x: foreheadBoundsForUIImage.origin.x,
            y: foreheadBoundsForUIImage.origin.y - (foreheadBoundsForUIImage.width + 14),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )
        let rightBounds3 = CGRect(
            x: foreheadBoundsForUIImage.origin.x,
            y: foreheadBoundsForUIImage.origin.y - (foreheadBoundsForUIImage.width + 21),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )
        let rightBounds4 = CGRect(
            x: foreheadBoundsForUIImage.origin.x,
            y: foreheadBoundsForUIImage.origin.y - (foreheadBoundsForUIImage.width + 28),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )
        let rightBounds5 = CGRect(
            x: foreheadBoundsForUIImage.origin.x,
            y: foreheadBoundsForUIImage.origin.y - (foreheadBoundsForUIImage.width + 35),
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

        return ForeheadColor(
            center: centerAverageColor,
            left1: leftAverageColor1,
            left2: leftAverageColor2,
            left3: leftAverageColor3,
            left4: leftAverageColor4,
            left5: leftAverageColor5,
            right1: rightAverageColor1,
            right2: rightAverageColor2,
            right3: rightAverageColor3,
            right4: rightAverageColor4,
            right5: rightAverageColor5
        )
    }

    private func visualizeForeheadRegion(in ciImage: CIImage, with foreheadBounds: CGRect) -> UIImage? {
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
            y: foreheadBoundsForUIImage.origin.y + (foreheadBoundsForUIImage.width + 7),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )
        let leftBounds2 = CGRect(
            x: foreheadBoundsForUIImage.origin.x,
            y: foreheadBoundsForUIImage.origin.y + (foreheadBoundsForUIImage.width + 14),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )
        let leftBounds3 = CGRect(
            x: foreheadBoundsForUIImage.origin.x,
            y: foreheadBoundsForUIImage.origin.y + (foreheadBoundsForUIImage.width + 21),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )
        let leftBounds4 = CGRect(
            x: foreheadBoundsForUIImage.origin.x,
            y: foreheadBoundsForUIImage.origin.y + (foreheadBoundsForUIImage.width + 28),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )
        let leftBounds5 = CGRect(
            x: foreheadBoundsForUIImage.origin.x,
            y: foreheadBoundsForUIImage.origin.y + (foreheadBoundsForUIImage.width + 35),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )
        
        let rightBounds1 = CGRect(
            x: foreheadBoundsForUIImage.origin.x,
            y: foreheadBoundsForUIImage.origin.y - (foreheadBoundsForUIImage.width + 7),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )
        let rightBounds2 = CGRect(
            x: foreheadBoundsForUIImage.origin.x,
            y: foreheadBoundsForUIImage.origin.y - (foreheadBoundsForUIImage.width + 14),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )
        let rightBounds3 = CGRect(
            x: foreheadBoundsForUIImage.origin.x,
            y: foreheadBoundsForUIImage.origin.y - (foreheadBoundsForUIImage.width + 21),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )
        let rightBounds4 = CGRect(
            x: foreheadBoundsForUIImage.origin.x,
            y: foreheadBoundsForUIImage.origin.y - (foreheadBoundsForUIImage.width + 28),
            width: foreheadBoundsForUIImage.width,
            height: foreheadBoundsForUIImage.height
        )
        let rightBounds5 = CGRect(
            x: foreheadBoundsForUIImage.origin.x,
            y: foreheadBoundsForUIImage.origin.y - (foreheadBoundsForUIImage.width + 35),
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

// MARK: - Save Image
extension ViewController {
    private func saveImageToPhotoLibrary(image: UIImage) {
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
    
    private func saveImageToGallery(image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }
}

extension UIView {
    func snapshotImage() -> UIImage {
        UIGraphicsBeginImageContext(self.frame.size)
        self.layer.render(in: UIGraphicsGetCurrentContext()!)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image!
    }
}

extension UIColor {
    func toGradientColor(_ size: CGSize = CGSize(width: 100, height: 100)) -> UIColor {
        var gradientColor: UIColor!
        
        DispatchQueue.main.sync {
            let view = UIView(frame: CGRect(origin: .zero, size: size))
            
            let gradientLayer = CAGradientLayer()
            gradientLayer.frame = view.bounds
            gradientLayer.colors = [self.cgColor, UIColor.clear.cgColor]
            gradientLayer.locations = [0.0, 1.0]
            
            view.layer.addSublayer(gradientLayer)
            
            let gradientImage = view.snapshotImage()
            gradientColor = UIColor(patternImage: gradientImage)
        }
        
        return gradientColor
    }
}

extension UIImage {
    func getPixelColor(at point: CGPoint) -> UIColor {
        guard let imageCG = cgImage else { return UIColor.clear }
        let pixelData = imageCG.dataProvider?.data
        let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
        let pixelInfo: Int = ((Int(imageCG.width) * Int(point.y)) + Int(point.x)) * 4

        let r = CGFloat(data[pixelInfo]) / 255.0
        let g = CGFloat(data[pixelInfo + 1]) / 255.0
        let b = CGFloat(data[pixelInfo + 2]) / 255.0
        let a = CGFloat(data[pixelInfo + 3]) / 255.0

        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
}

extension UIColor {
    func isWhiteOrClose() -> Bool {
        guard let components = cgColor.components else { return false }
        let r = components[0]
        let g = components[1]
        let b = components[2]

        // Check if the color is white or close to white
        return r > 0.9 && g > 0.9 && b > 0.9
    }
}

extension UIColor {
    static func blendColors(color1: UIColor, color2: UIColor) -> UIColor {
        var r1: CGFloat = 0.0, g1: CGFloat = 0.0, b1: CGFloat = 0.0, a1: CGFloat = 0.0
        var r2: CGFloat = 0.0, g2: CGFloat = 0.0, b2: CGFloat = 0.0, a2: CGFloat = 0.0
        
        color1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        color2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        let r = (1 - a2) * r1 + a2 * r2
        let g = (1 - a2) * g1 + a2 * g2
        let b = (1 - a2) * b1 + a2 * b2
        let a = a1
        
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
}
