

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct FileSelectionView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var selectedFiles: [SelectedFile] = []
    @State private var showingPhotoPicker = false
    @State private var showingDocumentPicker = false
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var isReceiving = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    
                    Spacer()
                    
                    if coordinator.transferMode == .send {
                        // Send mode - show file selection options
                        VStack(spacing: 20) {
                            // Photos & Videos
                            FileTypeCard(
                                title: "Photos & Videos",
                                description: "Select from your photo library",
                                icon: "photo.on.rectangle",
                                color: .pink,
                                count: photoCount
                            ) {
                                showingPhotoPicker = true
                            }
                            
                            // Documents
                            FileTypeCard(
                                title: "Documents",
                                description: "PDF, Word, Excel and more",
                                icon: "doc.on.doc",
                                color: .blue,
                                count: documentCount
                            ) {
                                showingDocumentPicker = true
                            }
                            
                            // All Files
                            FileTypeCard(
                                title: "All Files",
                                description: "Browse all file types",
                                icon: "folder",
                                color: .orange,
                                count: 0
                            ) {
                                showingDocumentPicker = true
                            }
                            
                            // Selected files preview
                            if !selectedFiles.isEmpty {
                                SelectedFilesPreview(files: selectedFiles) { file in
                                    selectedFiles.removeAll { $0.id == file.id }
                                }
                            }
                        }
                        .padding(.horizontal, 32)
                        
                        Spacer()
                        
                        // Send button
                        if !selectedFiles.isEmpty {
                            Button(action: {
                                startTransfer()
                            }) {
                                HStack {
                                    Image(systemName: "paperplane.fill")
                                        .font(.system(size: 18, weight: .semibold))
                                    
                                    Text("Send \(selectedFiles.count) \(selectedFiles.count == 1 ? "File" : "Files")")
                                        .font(.system(size: 18, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(red: 0.04, green: 0.52, blue: 1.0),
                                            Color(red: 0.04, green: 0.68, blue: 0.94)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .cornerRadius(16)
                            }
                            .padding(.horizontal, 32)
                            .padding(.bottom, 20)
                        }
                    } else {
                        // Receive mode - show waiting state and start receiving
                        VStack(spacing: 32) {
                            // Waiting animation
                            ZStack {
                                Circle()
                                    .stroke(Color.blue.opacity(0.2), lineWidth: 4)
                                    .frame(width: 120, height: 120)
                                
                                Circle()
                                    .trim(from: 0, to: 0.7)
                                    .stroke(Color.blue, lineWidth: 4)
                                    .frame(width: 120, height: 120)
                                    .rotationEffect(.degrees(-90))
                                    .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: true)
                                
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(.blue)
                            }
                            
                            VStack(spacing: 8) {
                                Text("Ready to Receive")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Text("Your device is discoverable and ready\nto accept multiple incoming files")
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                
                                // Show active transfers count if any
                                if !coordinator.activeTransfers.isEmpty {
                                    let receiveTransfers = coordinator.activeTransfers.values.filter { $0.type == .receive }
                                    if !receiveTransfers.isEmpty {
                                        Text("Receiving \(receiveTransfers.count) file\(receiveTransfers.count == 1 ? "" : "s")...")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.blue)
                                            .padding(.top, 8)
                                    }
                                }
                            }
                        }
                        .onAppear {
                            // ✅ FIXED: Prevent multiple receive sessions and synchronize UI state
                            guard !isReceiving else { return }
                            
                            Task {
                                if let discoveredDevice = coordinator.selectedDevice,
                                   let connectedDevice = coordinator.connectionStateManager.getConnectedDevice(for: discoveredDevice) {
                                    isReceiving = true
                                    
                                    // ✅ FIXED: Set transfer mode and navigate to progress before starting receive
                                    coordinator.transferMode = .receive
                                    coordinator.showTransferProgress()
                                    
                                    await coordinator.receiveFiles(from: connectedDevice)
                                }
                            }
                        }
                        .onDisappear {
                            isReceiving = false
                        }
                        
                        Spacer()
                    }
                    
                    // Back button
                    Button(action: {
                        coordinator.showSendReceiveOptions()
                    }) {
                        HStack {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.bottom, geometry.safeAreaInsets.bottom + 32)
                }
            }
        }
        .liquidGlassNavigationBar(
            title: coordinator.transferMode == .send ? "Select Files" : "Receiving",
            subtitle: coordinator.selectedDevice?.name ?? "Unknown Device",
            showBackButton: true,
            onBackTap: {
                coordinator.showTransfer2()
            }
        )
        .photosPicker(isPresented: $showingPhotoPicker, selection: $photoPickerItems, maxSelectionCount: 10, matching: .any(of: [.images, .videos]))
        .fileImporter(isPresented: $showingDocumentPicker, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            handleDocumentSelection(result)
        }
        .onChange(of: photoPickerItems) { _, items in
            handlePhotoSelection(items)
        }
    }
    
    private var photoCount: Int {
        selectedFiles.filter { $0.type == .photo || $0.type == .video }.count
    }
    
    private var documentCount: Int {
        selectedFiles.filter { $0.type == .document }.count
    }
    
    private func handlePhotoSelection(_ items: [PhotosPickerItem]) {
        Task {
            for item in items {
                // Generate fallback identifier if itemIdentifier is nil
                let itemIdentifier = item.itemIdentifier ?? "media_\(UUID().uuidString)"
                
                do {
                    // Try loading as URL first (preferred method)
                    var fileURL: URL?
                    var loadError: Error?
                    
                    // First attempt: URL loading
                    do {
                        fileURL = try await item.loadTransferable(type: URL.self)
                    } catch {
                        loadError = error
                        // If URL loading fails, try Data loading as fallback
                        if let data = try? await item.loadTransferable(type: Data.self) {
                            // Save data to temporary file
                            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                            let fileName = "photo_\(UUID().uuidString).jpg"
                            let destinationURL = documentsPath.appendingPathComponent(fileName)
                            try data.write(to: destinationURL)
                            fileURL = destinationURL
                        }
                    }
                    
                    guard let finalURL = fileURL else {
                        // Generate descriptive error message
                        let errorMessage: String
                        if let error = loadError {
                            if let nsError = error as NSError? {
                                if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileReadNoPermissionError {
                                    errorMessage = "Permission denied to access photo"
                                } else if nsError.domain == NSURLErrorDomain {
                                    errorMessage = "Unable to load photo: network error"
                                } else if nsError.domain == "com.apple.photos" {
                                    errorMessage = "Unable to load photo from Photos library"
                                } else {
                                    errorMessage = "Unable to load photo: \(nsError.localizedDescription)"
                                }
                            } else {
                                errorMessage = "Unable to load photo: \(error.localizedDescription)"
                            }
                        } else {
                            errorMessage = "Unable to load photo: item not available"
                        }
                        
                        await MainActor.run {
                            coordinator.showError(.fileOperationFailed(details: errorMessage))
                        }
                        continue
                    }
                    
                    // Create temporary file in documents directory
                    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    let fileName = itemIdentifier.isEmpty ? "media_\(UUID().uuidString)" : itemIdentifier
                    let destinationURL = documentsPath.appendingPathComponent(fileName)
                    
                    // Copy file directly to avoid loading entire Data into memory
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    
                    // Ensure destination directory exists
                    let destinationDir = destinationURL.deletingLastPathComponent()
                    try FileManager.default.createDirectory(at: destinationDir, withIntermediateDirectories: true, attributes: nil)
                    
                    try FileManager.default.copyItem(at: finalURL, to: destinationURL)
                    
                    // Get file size from copied file
                    let fileSize = (try? FileManager.default.attributesOfItem(atPath: destinationURL.path)[.size] as? NSNumber)?.int64Value ?? 0
                    
                    // Determine media type based on content type
                    let fileType: FileType
                    if let contentType = try? finalURL.resourceValues(forKeys: [.contentTypeKey]).contentType {
                        if contentType.conforms(to: .movie) {
                            fileType = .video
                        } else if contentType.conforms(to: .image) {
                            fileType = .photo
                        } else {
                            fileType = .document
                        }
                    } else {
                        // Fallback: check file extension
                        let fileExtension = finalURL.pathExtension.lowercased()
                        if ["mp4", "mov", "avi", "mkv", "wmv", "flv", "webm"].contains(fileExtension) {
                            fileType = .video
                        } else if ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "heif"].contains(fileExtension) {
                            fileType = .photo
                        } else {
                            fileType = .document
                        }
                    }
                    
                    let file = SelectedFile(
                        id: UUID().uuidString,
                        name: fileName,
                        type: fileType,
                        size: fileSize,
                        url: destinationURL
                    )
                    
                    await MainActor.run {
                        if !selectedFiles.contains(where: { $0.id == file.id }) {
                            selectedFiles.append(file)
                        }
                    }
                } catch {
                    await MainActor.run {
                        let errorMessage: String
                        if let nsError = error as NSError? {
                            if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileReadNoPermissionError {
                                errorMessage = "Permission denied to access photo"
                            } else if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileWriteFileExistsError {
                                errorMessage = "Photo file already exists"
                            } else if nsError.domain == NSURLErrorDomain {
                                errorMessage = "Network error while loading photo"
                            } else {
                                errorMessage = "Unable to load photo: \(nsError.localizedDescription)"
                            }
                        } else {
                            errorMessage = "Unable to load photo: \(error.localizedDescription)"
                        }
                        coordinator.showError(.fileOperationFailed(details: errorMessage))
                    }
                }
            }
        }
    }
    
    private func handleDocumentSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                // Start accessing security-scoped resource
                guard url.startAccessingSecurityScopedResource() else {
                    print("Failed to access security-scoped resource: \(url.lastPathComponent)")
                    continue
                }
                
                do {
                    // Copy the file to a temporary directory to ensure persistent access
                    let temporaryDirectoryURL = FileManager.default.temporaryDirectory
                    let destinationURL = temporaryDirectoryURL.appendingPathComponent(url.lastPathComponent)
                    
                    // If a file with the same name already exists, remove it
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    
                    try FileManager.default.copyItem(at: url, to: destinationURL)
                    
                    // Stop accessing the security-scoped resource
                    url.stopAccessingSecurityScopedResource()
                    
                    // ✅ FIXED: Compute document size from the copied file
                    let size = (try? FileManager.default.attributesOfItem(atPath: destinationURL.path)[.size] as? NSNumber)?.int64Value ?? 0
                    
                    let file = SelectedFile(
                        id: UUID().uuidString,
                        name: destinationURL.lastPathComponent,
                        type: .document,
                        size: size,
                        url: destinationURL
                    )
                    
                    if !selectedFiles.contains(where: { $0.id == file.id }) {
                        selectedFiles.append(file)
                    }
                } catch {
                    url.stopAccessingSecurityScopedResource()
                    
                    // Show user-friendly error message
                    let errorMessage: String
                    if let nsError = error as NSError? {
                        if nsError.domain == NSCocoaErrorDomain {
                            if nsError.code == NSFileReadNoPermissionError {
                                errorMessage = "Permission denied to access document"
                            } else if nsError.code == NSFileWriteVolumeReadOnlyError || nsError.code == NSFileWriteNoPermissionError {
                                errorMessage = "Insufficient storage or permission denied"
                            } else {
                                errorMessage = error.localizedDescription
                            }
                        } else {
                            errorMessage = error.localizedDescription
                        }
                    } else {
                        errorMessage = error.localizedDescription
                    }
                    
                    coordinator.showError(.fileOperationFailed(details: errorMessage))
                }
            }
        case .failure(let error):
            coordinator.showError(.fileOperationFailed(details: error.localizedDescription))
        }
    }
    
    private func startTransfer() {
        // Pass selected files to coordinator for transfer
        coordinator.selectedFiles = selectedFiles
        
        // Get the connected device from ConnectionStateManager
        guard let discoveredDevice = coordinator.selectedDevice else {
            print("Error: No device selected")
            coordinator.showError(.deviceNotFound)
            return
        }
        
        guard let connectedDevice = coordinator.connectionStateManager.getConnectedDevice(for: discoveredDevice) else {
            print("Error: Device not connected")
            coordinator.showError(.connectionFailed(transport: discoveredDevice.connectionType.rawValue, details: "Device not connected"))
            return
        }
        
        // ✅ FIXED: Remove duplicate navigation - AppCoordinator.sendSelectedFiles() handles navigation
        // Actually initiate the file transfer
        Task {
            if coordinator.transferMode == .send {
                await coordinator.sendSelectedFiles(to: connectedDevice)
            } else if coordinator.transferMode == .receive {
                await coordinator.receiveFiles(from: connectedDevice)
            }
        }
    }
}

// MARK: - File Type Card
struct FileTypeCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let count: Int
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(color)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(title)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        
                        if count > 0 {
                            Text("(\(count))")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(color)
                        }
                    }
                    
                    Text(description)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.all, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.12, green: 0.12, blue: 0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            )
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Selected Files Preview
struct SelectedFilesPreview: View {
    let files: [SelectedFile]
    let onRemove: (SelectedFile) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Selected Files (\(files.count))")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(files) { file in
                    FilePreviewCard(file: file) {
                        onRemove(file)
                    }
                }
            }
        }
        .padding(.all, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.08, green: 0.08, blue: 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - File Preview Card
struct FilePreviewCard: View {
    let file: SelectedFile
    let onRemove: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: 0.15, green: 0.15, blue: 0.15))
                    .frame(height: 60)
                
                Image(systemName: fileIcon)
                    .font(.system(size: 24))
                    .foregroundColor(fileColor)
                
                // Remove button
                VStack {
                    HStack {
                        Spacer()
                        Button(action: onRemove) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.7))
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                    }
                    Spacer()
                }
                .padding(4)
            }
            
            Text(file.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
    }
    
    private var fileIcon: String {
        switch file.type {
        case .photo:
            return "photo"
        case .video:
            return "video"
        case .document:
            return "doc.text"
        }
    }
    
    private var fileColor: Color {
        switch file.type {
        case .photo:
            return .pink
        case .video:
            return .purple
        case .document:
            return .blue
        }
    }
}

// MARK: - Supporting Models
struct SelectedFile: Identifiable, Equatable {
    let id: String
    let name: String
    let type: FileType
    let size: Int64
    let url: URL?
}

enum FileType {
    case photo
    case video
    case document
}

#Preview {
    FileSelectionView()
        .environmentObject({
            let coordinator = AppCoordinator()
            coordinator.transferMode = .send
            coordinator.selectedDevice = DiscoveredDevice(
                id: "1",
                name: "John's iPhone",
                type: .iPhone,
                connectionType: .wifiAware,
                isAvailable: true,
                avatarIndex: nil
            )
            return coordinator
        }())
}
