
import Foundation


@MainActor
protocol ConsentPrompting: AnyObject {

    func didRequestFileTransfer(
        fileName: String,
        fileSize: Int64,
        from device: ConnectedDevice,
        respond: @escaping (Bool, Bool) -> Void
    )
}

