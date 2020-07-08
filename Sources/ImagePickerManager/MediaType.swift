//
//  MediaType.swift
//  ImagePickerManager
//
//  Created by Yoel Lev on 08/07/2020.
//

import Foundation
import MobileCoreServices

@available(iOS 9.1, *)
public enum MediaType {
    case images
    case movies
    case livePhotos

    internal func setImagePickerMediaTypes() -> ImagePickerMediaTypes {
        switch self {
        case .images:
            return ImagePickerMediaTypes(rawValue: [kUTTypeImage])
        case .movies:
            return ImagePickerMediaTypes(rawValue: [kUTTypeMovie])
        case .livePhotos:
            return ImagePickerMediaTypes(rawValue: [kUTTypeImage, kUTTypeLivePhoto])
        }
    }
}
