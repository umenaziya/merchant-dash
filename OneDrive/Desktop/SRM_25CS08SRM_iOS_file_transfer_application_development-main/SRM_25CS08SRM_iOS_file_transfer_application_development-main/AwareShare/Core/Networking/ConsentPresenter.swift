

import Foundation


@MainActor
protocol ConsentPresenter: AnyObject {

    func presentFileTransferConsent(
        fileName: String,
        fileSize: Int64,
        from device: ConnectedDevice,
        respond: @escaping (Bool, Bool) -> Void
    )
}
