import UIKit
import Photos

/// Allows `ImagePicker` operation queues to safely target the main queue.
private let pickerQueue = DispatchQueue(label: "com.thoughtbot.uploadr.picker", target: .main)

/// An image picker with a specific `UIImagePickerController` configuration.
/// Defines a serial operation queue for image picking tasks, allowing `pickImage()`
/// to be called safely from any thread, and ensuring that only one image picking
/// task is active at a time.
public final class ImagePickerManager {
    private let picker = UIImagePickerController()
    private let operationQueue = OperationQueue()

    @available(iOS 9.1, *)
    public init(sourceType: UIImagePickerController.SourceType, mediaType: MediaType = .images, allowsEditing: Bool = false) {
        let mediaTypes: ImagePickerMediaTypes = mediaType.getImagePickerMediaTypes()

        precondition(UIImagePickerController.isSourceTypeAvailable(sourceType), "Unavailable source type '\(sourceType.caseDescription)'.")
        precondition(!mediaTypes.isEmpty, "You must provide at least one media type.")

        let availableMediaTypes = ImagePickerMediaTypes.availableMediaTypes(for: sourceType).intersection(mediaTypes)
        precondition(!availableMediaTypes.isEmpty, "Requested media types not available: \(mediaTypes).")

        picker.allowsEditing = allowsEditing
        picker.mediaTypes = mediaTypes.imagePickerMediaTypes
        picker.sourceType = sourceType
        operationQueue.maxConcurrentOperationCount = 1
        operationQueue.underlyingQueue = pickerQueue
    }

    /// Present a `UIImagePickerController` in a specific configuration, in a thread-safe way.
    /// Multiple calls to this method will safely enqueue image picking tasks, removing the
    /// need for the caller to manage state. The completion handler is called on the main queue.
    @discardableResult
    public func pickImage(over context: UIViewController, animated: Bool, completionHandler: @escaping (UIImage?) -> Void) -> ImagePickerTask {
        let operation = ImagePickerOperation(context: context, picker: picker, animated: animated)

        operation.completionBlock = { [unowned operation] in
          let result = operation.result
          DispatchQueue.main.async {
            completionHandler(result)
          }
        }

        operationQueue.addOperation(operation)
        return ImagePickerTask(operation)
    }

    /// Cancels all current and pending image picker operations.
    public func cancelAll() {
        operationQueue.cancelAllOperations()
    }
}

/// Handle  an image picker operation, allowing it to be cancelled.
public final class ImagePickerTask {
  private let operation: ImagePickerOperation

  fileprivate init(_ operation: ImagePickerOperation) {
    self.operation = operation
  }

  public func cancel() {
    operation.cancel()
  }
}

/// Manages the state of a single image picking operation.
///
/// - Requires: Must be started on `pickerQueue`.
private final class ImagePickerOperation: Operation {
    let animated: Bool
    let context: UIViewController
    let picker: UIImagePickerController
    private(set) var state: ImagePickingState

    var result: UIImage? {
       switch state {
       case let .completed(result):
         return result
       case .ready, .executing, .cancelledByUser:
         return nil
       }
    }

    init(context: UIViewController, picker: UIImagePickerController, animated: Bool) {
        self.animated = animated
        self.context = context
        self.picker = picker
        self.state = .ready
        super.init()
    }

    override var isAsynchronous: Bool {
        return true
    }

    override var isExecuting: Bool {
        return state.isExecuting
    }

    override var isFinished: Bool {
        return state.isFinished
    }

    override func start() {
        if #available(iOS 10.0, *) {
            dispatchPrecondition(condition: .onQueue(pickerQueue))
        } else {
            // Fallback on earlier versions
        }

        guard !isCancelled else {
          willChangeValue(for: \.isFinished)
          state = .completed(nil)
          didChangeValue(for: \.isFinished)
          return
        }

        picker.delegate = self
        picker.modalPresentationStyle = .formSheet
        picker.presentationController?.delegate = context as? UIAdaptivePresentationControllerDelegate

        willChangeValue(for: \.isExecuting)

        context.present(picker, animated: animated) {
          self.state = .executing
          self.didChangeValue(for: \.isExecuting)
        }
    }

    override func cancel() {
        cancelImagePickerController()
    }

    private func cancelImagePickerController() {
        willChangeValue(for: \.isExecuting)
        willChangeValue(for: \.isFinished)

        state = .cancelledByUser

        context.dismiss(animated: true)  {
            self.didChangeValue(for: \.isExecuting)
            self.didChangeValue(for: \.isFinished)
        }
    }
}

extension ImagePickerOperation: UIImagePickerControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {

        var image: UIImage?

        if let possibleImage = info[.editedImage] as? UIImage {
            image = possibleImage
        } else if let possibleImage = info[.originalImage] as? UIImage {
            image = possibleImage
        } else if let possibleImage = info[.cropRect] as? UIImage {
            image = possibleImage
        } else {
            return
        }

        willChangeValue(for: \.isExecuting)
        willChangeValue(for: \.isFinished)

        let result = isCancelled ? nil : image
        state = .completed(result)

        context.dismiss(animated: true) {
            self.didChangeValue(for: \.isExecuting)
            self.didChangeValue(for: \.isFinished)
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        willChangeValue(for: \.isExecuting)
        willChangeValue(for: \.isFinished)

        state = .cancelledByUser

        context.dismiss(animated: true) {
          self.didChangeValue(for: \.isExecuting)
          self.didChangeValue(for: \.isFinished)
        }
    }

}

extension ImagePickerOperation: UINavigationControllerDelegate { }

// MERK: - ImagePickingState
private enum ImagePickingState {
  case ready
  case executing
  case cancelledByUser
  case completed(UIImage?)

  var isExecuting: Bool {
    switch self {
    case .executing:
      return true
    case .ready, .cancelledByUser, .completed:
      return false
    }
  }

  var isFinished: Bool {
    switch self {
    case .cancelledByUser, .completed:
      return true
    case .ready, .executing:
      return false
    }
  }
}

private extension UIImagePickerController.SourceType {
  @nonobjc var caseDescription: String {
    let typeName = String(describing: type(of: self))
    let caseName: String

    switch self {
    case .camera:
      caseName = "camera"
    case .photoLibrary:
      caseName = "photoLibrary"
    case .savedPhotosAlbum:
      caseName = "savedPhotosAlbum"
    @unknown default:
        fatalError()
    }

    return "\(typeName).\(caseName)"
  }
}
