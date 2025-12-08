import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// MARK: - AirDrop File Selection View
struct AirDropFileSelectionView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @Environment(\.dismiss) private var dismiss
    let onFilesSelected: ([URL]) -> Void
    
    // MARK: - Constants
    private static let MAX_SELECTION = 10
    private static let photoVideoExtensions = ["jpg", "jpeg", "png", "gif", "heic", "mov", "mp4", "avi"]
    
    @State private var selectedFiles: [URL] = []
    @State private var showingPhotoPicker = false
    @State private var showingDocumentPicker = false
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var temporaryFiles: [URL] = []
    @State private var errorMessage: String?
    @State private var showError: Bool = false
    @State private var showSelectionLimitAlert: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Spacer()
                    
                    // Photos & Videos
                    FileTypeCard(
                        title: "Photos & Videos",
                        description: "Select from your photo library",
                        icon: "photo.on.rectangle",
                        color: .pink,
                        count: selectedFiles.filter { url in
                            let ext = url.pathExtension.lowercased()
                            return Self.photoVideoExtensions.contains(ext)
                        }.count
                    ) {
                        showingPhotoPicker = true
                    }
                    
                    // Documents
                    FileTypeCard(
                        title: "Documents",
                        description: "PDF, Word, Excel and more",
                        icon: "doc.on.doc",
                        color: .blue,
                        count: selectedFiles.filter { url in
                            let ext = url.pathExtension.lowercased()
                            return !Self.photoVideoExtensions.contains(ext)
                        }.count
                    ) {
                        showingDocumentPicker = true
                    }
                    
                    // Selected files preview
                    if !selectedFiles.isEmpty {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Selected Files (\(selectedFiles.count))")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal)
                                
                                ForEach(selectedFiles.indices, id: \.self) { index in
                                    HStack {
                                        Image(systemName: fileIcon(for: selectedFiles[index]))
                                            .foregroundColor(.blue)
                                        Text(selectedFiles[index].lastPathComponent)
                                            .font(.system(size: 14))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                        Spacer()
                                        Button(action: {
                                            let urlToRemove = selectedFiles[index]
                                            // If it's a temporary file, remove it from tracking and delete it
                                            if temporaryFiles.contains(urlToRemove) {
                                                temporaryFiles.removeAll { $0 == urlToRemove }
                                                try? FileManager.default.removeItem(at: urlToRemove)
                                            }
                                            selectedFiles.remove(at: index)
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            .padding(.vertical)
                        }
                        .frame(maxHeight: 200)
                    }
                    
                    Spacer()
                    
                    // Share via AirDrop button
                    if !selectedFiles.isEmpty {
                        Button(action: {
                            onFilesSelected(selectedFiles)
                            cleanupTemporaryFiles()
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 18, weight: .semibold))
                                Text("Share via AirDrop")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.04, green: 0.52, blue: 1.0),
                                        Color(red: 0.04, green: 0.68, blue: 0.94)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(16)
                        }
                        .padding(.horizontal, 32)
            .fileImporter(isPresented: $showingDocumentPicker, allowedContentTypes: [.pdf, .text, .data, .spreadsheet, .presentation, .archive], allowsMultipleSelection: true) { result in
                handleDocumentSelection(result)
            }
                    }
                }
            }
            .navigationTitle("Select Files")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        cleanupTemporaryFiles()
                        dismiss()
                    }
                }
            }
            .photosPicker(isPresented: $showingPhotoPicker, selection: $photoPickerItems, maxSelectionCount: Self.MAX_SELECTION, matching: .any(of: [.images, .videos]))
            .fileImporter(isPresented: $showingDocumentPicker, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
                handleDocumentSelection(result)
            }
            .onChange(of: photoPickerItems) { _, items in
                handlePhotoSelection(items)
            }
            .onDisappear {
                cleanupTemporaryFiles()
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
            .alert("Selection Limit Reached", isPresented: $showSelectionLimitAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("You can select a maximum of \(Self.MAX_SELECTION) files. Only the first \(Self.MAX_SELECTION) files have been added.")
            }
        }
    }
    
    private func handlePhotoSelection(_ items: [PhotosPickerItem]) {
        Task {
            // Calculate how many more files can be added
            let currentCount = await MainActor.run { selectedFiles.count }
            let remainingSlots = Self.MAX_SELECTION - currentCount
            
            // If no slots remaining, show alert and return
            guard remainingSlots > 0 else {
                await MainActor.run {
                    showSelectionLimitAlert = true
                    // Clear photoPickerItems to prevent reprocessing
                    photoPickerItems = []
                }
                return
            }
            
            // Trim selection to fit within the limit
            let itemsToProcess = Array(items.prefix(remainingSlots))
            let wasTrimmed = items.count > remainingSlots
            
            // Show alert if selection was trimmed
            if wasTrimmed {
                await MainActor.run {
                    showSelectionLimitAlert = true
                }
            }
            
            for item in itemsToProcess {
                // Check if we've reached the limit before processing each item
                let currentCount = await MainActor.run { selectedFiles.count }
                guard currentCount < Self.MAX_SELECTION else {
                    break
                }
                
                do {
                    if let fileURL = try await item.loadTransferable(type: URL.self) {
                        await MainActor.run {
                            if !selectedFiles.contains(fileURL) && selectedFiles.count < Self.MAX_SELECTION {
                                selectedFiles.append(fileURL)
                            }
                        }
                    } else if let data = try await item.loadTransferable(type: Data.self) {
                        // Get file extension from UTType or detect from data bytes, fall back to safe default
                        let fileExtension = getFileExtension(for: item, data: data) ?? "bin"
                        let tempDir = FileManager.default.temporaryDirectory
                        let uniqueFileName = "\(UUID().uuidString).\(fileExtension)"
                        let tempURL = tempDir.appendingPathComponent(uniqueFileName)
                        
                        try data.write(to: tempURL)
                        
                        await MainActor.run {
                            if !selectedFiles.contains(tempURL) && selectedFiles.count < Self.MAX_SELECTION {
                                selectedFiles.append(tempURL)
                                temporaryFiles.append(tempURL)
                            }
                        }
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = "Failed to load photo: \(error.localizedDescription)"
                        showError = true
                    }
                }
            }
            
            // Clear photoPickerItems after processing to prevent reprocessing on subsequent view updates
            await MainActor.run {
                photoPickerItems = []
            }
        }
    }
    
  
    private func getFileExtension(for item: PhotosPickerItem, data: Data) -> String? {
        // Try to get the supported content types from the item
        if let supportedTypes = item.supportedContentTypes.first {
            // Get the preferred file extension from the UTType
            if let preferredExtension = supportedTypes.preferredFilenameExtension {
                return preferredExtension
            }
            
            // Fallback: map common UTTypes to extensions
            let typeIdentifier = supportedTypes.identifier
            if typeIdentifier.contains("jpeg") || typeIdentifier == "public.jpeg" {
                return "jpg"
            } else if typeIdentifier.contains("png") || typeIdentifier == "public.png" {
                return "png"
            } else if typeIdentifier.contains("heic") || typeIdentifier == "public.heic" {
                return "heic"
            } else if typeIdentifier.contains("gif") || typeIdentifier == "com.compuserve.gif" {
                return "gif"
            } else if typeIdentifier.contains("quicktime") || typeIdentifier == "public.movie" {
                return "mov"
            } else if typeIdentifier.contains("mpeg4") || typeIdentifier == "public.mpeg-4" {
                return "mp4"
            } else if typeIdentifier.contains("tiff") || typeIdentifier == "public.tiff" {
                return "tiff"
            } else if typeIdentifier.contains("webp") || typeIdentifier == "org.webmproject.webp" {
                return "webp"
            }
        }
        
        // Fallback: detect file type from data bytes (magic numbers)
        return detectFileExtension(from: data)
    }
    
    /// Detects file extension from data bytes using magic numbers
    private func detectFileExtension(from data: Data) -> String? {
        guard data.count >= 12 else { return nil }
        
        let bytes = data.prefix(12)
        
        // JPEG: FF D8 FF
        if bytes.starts(with: [0xFF, 0xD8, 0xFF]) {
            return "jpg"
        }
        
        // PNG: 89 50 4E 47 0D 0A 1A 0A
        if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) {
            return "png"
        }
        
        // GIF: 47 49 46 38 (GIF8)
        if bytes.starts(with: [0x47, 0x49, 0x46, 0x38]) {
            return "gif"
        }
        
        // HEIC: Check for ftyp box at offset 4
        if data.count >= 12 && bytes.dropFirst(4).starts(with: [0x66, 0x74, 0x79, 0x70]) {
            // Check for HEIC brand
            if data.count >= 16 {
                let brandBytes = data.subdata(in: 8..<12)
                if String(data: brandBytes, encoding: .ascii)?.uppercased().contains("HEIC") == true ||
                   String(data: brandBytes, encoding: .ascii)?.uppercased().contains("MIF1") == true {
                    return "heic"
                }
            }
        }
        
        // QuickTime/MOV: Check for ftyp box
        if data.count >= 12 && bytes.dropFirst(4).starts(with: [0x66, 0x74, 0x79, 0x70]) {
            if data.count >= 16 {
                let brandBytes = data.subdata(in: 8..<12)
                if String(data: brandBytes, encoding: .ascii)?.uppercased().contains("QT") == true {
                    return "mov"
                }
            }
        }
        
        // MP4: Check for ftyp box with mp4/isom brands
        if data.count >= 12 && bytes.dropFirst(4).starts(with: [0x66, 0x74, 0x79, 0x70]) {
            if data.count >= 16 {
                let brandBytes = data.subdata(in: 8..<12)
                let brandString = String(data: brandBytes, encoding: .ascii)?.uppercased() ?? ""
                if brandString.contains("MP4") || brandString.contains("ISOM") {
                    return "mp4"
                }
            }
        }
        
        // TIFF: 49 49 2A 00 (little-endian) or 4D 4D 00 2A (big-endian)
        if bytes.starts(with: [0x49, 0x49, 0x2A, 0x00]) || bytes.starts(with: [0x4D, 0x4D, 0x00, 0x2A]) {
            return "tiff"
        }
        
        // WebP: Check for RIFF...WEBP
        if data.count >= 12 && bytes.starts(with: [0x52, 0x49, 0x46, 0x46]) {
            if data.count >= 12 && data.subdata(in: 8..<12) == "WEBP".data(using: .ascii) {
                return "webp"
            }
        }
        
        return nil
    }
    
    /// Cleans up all temporary files created during photo selection
    private func cleanupTemporaryFiles() {
        for tempURL in temporaryFiles {
            do {
                if FileManager.default.fileExists(atPath: tempURL.path) {
                    try FileManager.default.removeItem(at: tempURL)
                }
            } catch {
                // Log cleanup errors but don't show alerts for cleanup failures
                print("Failed to cleanup temporary file \(tempURL.lastPathComponent): \(error)")
            }
        }
        temporaryFiles.removeAll()
    }
    
    private func handleDocumentSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            // Calculate how many more files can be added
            let currentCount = selectedFiles.count
            let remainingSlots = Self.MAX_SELECTION - currentCount
            
            // If no slots remaining, show alert and return
            guard remainingSlots > 0 else {
                showSelectionLimitAlert = true
                return
            }
            
            // Trim selection to fit within the limit
            let urlsToProcess = Array(urls.prefix(remainingSlots))
            let wasTrimmed = urls.count > remainingSlots
            
            // Show alert if selection was trimmed
            if wasTrimmed {
                showSelectionLimitAlert = true
            }
            
            for url in urlsToProcess {
                guard url.startAccessingSecurityScopedResource() else {
                    errorMessage = "Unable to access selected document. Please try again."
                    showError = true
                    continue
                }
                defer { url.stopAccessingSecurityScopedResource() }
                
                // Check if we've reached the limit before processing each URL
                guard selectedFiles.count < Self.MAX_SELECTION else {
                    break
                }
                
                // Copy to temporary directory for AirDrop sharing
                let tempDir = FileManager.default.temporaryDirectory
                let destinationURL = tempDir.appendingPathComponent(url.lastPathComponent)
                
                do {
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    try FileManager.default.copyItem(at: url, to: destinationURL)
                    
                    if !selectedFiles.contains(destinationURL) {
                        selectedFiles.append(destinationURL)
                        temporaryFiles.append(destinationURL)
                    }
                } catch {
                    errorMessage = "Failed to copy document \"\(url.lastPathComponent)\": \(error.localizedDescription)"
                    showError = true
                }
            }
        case .failure(let error):
            errorMessage = "Document selection failed: \(error.localizedDescription)"
            showError = true
        }
    }
    
    private func fileIcon(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        if ["jpg", "jpeg", "png", "gif", "heic"].contains(ext) {
            return "photo"
        } else if ["mov", "mp4", "avi"].contains(ext) {
            return "video"
        } else {
            return "doc.text"
        }
    }
}


