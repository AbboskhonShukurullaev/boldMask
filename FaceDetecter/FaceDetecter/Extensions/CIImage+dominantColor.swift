//
//  CIImage+dominantColor.swift
//  FaceDetecter
//
//  Created by Abboskhon on 14/06/23.
//

import UIKit

extension CIImage {
    func dominantColor() -> UIColor? {
        // Reduce the image to a 4x4 pixel image
        guard let smallImage = CIFilter(name: "CILanczosScaleTransform", parameters: [kCIInputImageKey: self, kCIInputAspectRatioKey: 1.0, kCIInputScaleKey: 4.0 / min(extent.size.width, extent.size.height)])?.outputImage else {
            return nil
        }

        // Create a 4x4 bitmap
        var bitmap = [UInt8](repeating: 0, count: 4 * 4 * 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull!])
        context.render(smallImage, toBitmap: &bitmap, rowBytes: 16, bounds: CGRect(origin: .zero, size: CGSize(width: 4, height: 4)), format: .RGBA8, colorSpace: nil)

        // Create a dictionary to store the colors and counts
        var colorDict: [UIColor: Int] = [:]

        // Iterate through each pixel in the bitmap
        for i in stride(from: 0, to: bitmap.count, by: 4) {
            let r = CGFloat(bitmap[i]) / 255.0
            let g = CGFloat(bitmap[i + 1]) / 255.0
            let b = CGFloat(bitmap[i + 2]) / 255.0
            let a = CGFloat(bitmap[i + 3]) / 255.0
            let color = UIColor(red: r, green: g, blue: b, alpha: a)

            // If the color is already in the dictionary, increment its count. Otherwise, add it to the dictionary.
            if let count = colorDict[color] {
                colorDict[color] = count + 1
            } else {
                colorDict[color] = 1
            }
        }

        // Find the color with the highest count
        var maxCount = 0
        var dominantColor: UIColor?
        for (color, count) in colorDict {
            if count > maxCount {
                maxCount = count
                dominantColor = color
            }
        }

        return dominantColor
    }
}
