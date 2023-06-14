//
//  CIImage+averageColor.swift
//  FaceDetecter
//
//  Created by Abboskhon on 14/06/23.
//

import UIKit

extension CIImage {
    func averageColor() -> UIColor? {
        let extentVector = CIVector(x: extent.origin.x, y: extent.origin.y, z: extent.size.width, w: extent.size.height)

        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: self, kCIInputExtentKey: extentVector]) else {
            return nil
        }

        guard let outputImage = filter.outputImage else {
            return nil
        }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull!])
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)

        let floatComponents = bitmap.map { Float($0) / 255 }
        return UIColor(red: CGFloat(floatComponents[0]), green: CGFloat(floatComponents[1]), blue: CGFloat(floatComponents[2]), alpha: CGFloat(floatComponents[3]))
    }
}
