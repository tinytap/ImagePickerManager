//
//  ImagePickerMediaTypes.swift
//  ImagePickerManager
//
//  Created by Yoel Lev on 07/07/2020.
//
import UIKit
import MobileCoreServices

struct ImagePickerMediaTypes: OptionSet {
    var rawValue: Set<CFString>

    init(rawValue: Set<CFString>) {
        self.rawValue = rawValue
    }

    var imagePickerMediaTypes: [String] {
        return rawValue.map { $0 as String }
    }

    static let images = ImagePickerMediaTypes(rawValue: [kUTTypeImage])
    static let movies = ImagePickerMediaTypes(rawValue: [kUTTypeMovie])

    static func availableMediaTypes(for sourceType: UIImagePickerController.SourceType) -> ImagePickerMediaTypes {
        let mediaTypes = UIImagePickerController.availableMediaTypes(for: sourceType) ?? []
        return ImagePickerMediaTypes(rawValue: Set(mediaTypes as [CFString]))
    }
}

extension ImagePickerMediaTypes: SetAlgebra {
    init() {
        self.init(rawValue: [])
    }

    mutating func formUnion(_ other: ImagePickerMediaTypes) {
        rawValue.formUnion(other.rawValue)
    }

    mutating func formIntersection(_ other: ImagePickerMediaTypes) {
    rawValue.formIntersection(other.rawValue)
  }

    mutating func formSymmetricDifference(_ other: ImagePickerMediaTypes) {
    rawValue.formSymmetricDifference(other.rawValue)
  }
}

extension ImagePickerMediaTypes: CustomStringConvertible {
    var description: String {
let names = rawValue.lazy.map { $0 as String }.joined(separator: ", ")
return "(\(names))"
}
}
