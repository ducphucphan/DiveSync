//
//  UIImage+Extends.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 1/9/26.
//

import UIKit
import Accelerate
import CoreImage

// MARK: - UIImage Extension

extension UIImage {

    // MARK: Public API (giống Objective-C)

    func rgb565Data(size: CGSize) -> Data? {

        guard let resizedImage = self.vImageResized(to: size) else {
            return nil
        }

        guard let cgImage = resizedImage.cgImage else {
            return nil
        }

        guard let ciImage = swapImageContext(cgImage: cgImage) else {
            return nil
        }

        let ciContext = CIContext(options: nil)
        guard let imageRef = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }

        guard let cgContext = createARGBBitmapContext(from: imageRef) else {
            return nil
        }

        let width = imageRef.width
        let height = imageRef.height
        let rect = CGRect(x: 0, y: 0, width: width, height: height)

        cgContext.draw(imageRef, in: rect)

        guard let srcData = cgContext.data else {
            return nil
        }

        // Source buffer (ARGB8888)
        var srcBuffer = vImage_Buffer(
            data: srcData,
            height: vImagePixelCount(height),
            width: vImagePixelCount(width),
            rowBytes: width * 4
        )

        // Destination buffer (RGB565)
        let destBytesPerRow = width * 2
        guard let destData = malloc(destBytesPerRow * height) else {
            return nil
        }

        var dstBuffer = vImage_Buffer(
            data: destData,
            height: vImagePixelCount(height),
            width: vImagePixelCount(width),
            rowBytes: destBytesPerRow
        )

        // Convert ARGB8888 -> RGB565
        vImageConvert_ARGB8888toRGB565(&srcBuffer, &dstBuffer, 0)

        let dataSize = 2 * width * height
        let rgb565Data = Data(bytes: dstBuffer.data, count: dataSize)

        free(destData)

        return rgb565Data
    }

    // MARK: Fit image (giữ đúng logic Objective-C)

    func fitImage(to size: CGSize) -> UIImage {

        // Fix orientation
        UIGraphicsBeginImageContext(self.size)
        self.draw(at: .zero)
        let fixedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        let imageToUse = fixedImage ?? self

        // Render UIImageView
        let imageView = UIImageView(frame: CGRect(origin: .zero, size: size))
        imageView.backgroundColor = .black
        imageView.contentMode = .scaleAspectFit
        imageView.image = imageToUse

        UIGraphicsBeginImageContextWithOptions(imageView.bounds.size, imageView.isOpaque, 0.0)
        imageView.layer.render(in: UIGraphicsGetCurrentContext()!)
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return result ?? imageToUse
    }
    
    // MARK: - Private helpers

    private func swapImageContext(cgImage: CGImage) -> CIImage? {

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = cgImage.bytesPerRow

        guard let colorSpace = cgImage.colorSpace else {
            return nil
        }

        guard let provider = cgImage.dataProvider,
              let data = provider.data else {
            return nil
        }

        let nsData = data as Data

        let ciImage = CIImage(
            bitmapData: nsData,
            bytesPerRow: bytesPerRow,
            size: CGSize(width: width, height: height),
            format: .BGRA8,
            colorSpace: colorSpace
        )

        return ciImage
    }

    private func createARGBBitmapContext(from image: CGImage) -> CGContext? {

        let width = image.width
        let height = image.height

        let bytesPerRow = width * 4
        let byteCount = bytesPerRow * height

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            return nil
        }

        guard let bitmapData = malloc(byteCount) else {
            return nil
        }

        guard let context = CGContext(
            data: bitmapData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else {
            free(bitmapData)
            return nil
        }

        return context
    }
}

private extension UIImage {

    func vImageResized(to size: CGSize) -> UIImage? {

        guard let cgImage = self.cgImage else { return nil }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var format = vImage_CGImageFormat(
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            colorSpace: Unmanaged.passRetained(colorSpace),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.first.rawValue),
            version: 0,
            decode: nil,
            renderingIntent: .defaultIntent
        )

        var srcBuffer = vImage_Buffer()
        defer { free(srcBuffer.data) }

        var error = vImageBuffer_InitWithCGImage(
            &srcBuffer,
            &format,
            nil,
            cgImage,
            vImage_Flags(kvImageNoFlags)
        )
        guard error == kvImageNoError else { return nil }

        let destWidth = Int(size.width)
        let destHeight = Int(size.height)

        let bytesPerPixel = 4
        let destBytesPerRow = destWidth * bytesPerPixel

        guard let destData = malloc(destHeight * destBytesPerRow) else {
            return nil
        }

        var destBuffer = vImage_Buffer(
            data: destData,
            height: vImagePixelCount(destHeight),
            width: vImagePixelCount(destWidth),
            rowBytes: destBytesPerRow
        )

        error = vImageScale_ARGB8888(
            &srcBuffer,
            &destBuffer,
            nil,
            vImage_Flags(kvImageHighQualityResampling)
        )

        guard error == kvImageNoError else {
            free(destData)
            return nil
        }

        guard let resultCGImage = vImageCreateCGImageFromBuffer(
            &destBuffer,
            &format,
            { _, data in free(data) },
            nil,
            vImage_Flags(kvImageNoAllocate),
            &error
        )?.takeRetainedValue() else {
            free(destData)
            return nil
        }

        return UIImage(cgImage: resultCGImage)
    }
}
