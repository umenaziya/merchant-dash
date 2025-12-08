

import Foundation
import UIKit
import Photos
import Combine
import OSLog

// MARK: - File Manager

class AwareShareFileManager: ObservableObject {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.srmist.AwareShare", category: "FileManager")
    
    @Published var selectedFiles: [SelectedFile] = []
    @Published var isSelectingFiles = false
    
    // MARK: - File Selection
    
    func selectPhotos() async -> [SelectedFile] {
        return await withCheckedContinuation { continuation in
            Task { @MainActor in
                // Create sample photo files for testing
                var sampleFiles: [SelectedFile] = []
                
                // Create sample images in documents directory
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                
                let sampleImages = [
                    ("sample_photo1.jpg", "Sample Photo 1"),
                    ("sample_photo2.jpg", "Sample Photo 2"),
                    ("sample_photo3.jpg", "Sample Photo 3")
                ]
                
                for (fileName, displayName) in sampleImages {
                    let fileURL = documentsPath.appendingPathComponent(fileName)
                    
                    // Create sample image data if file doesn't exist
                    if !FileManager.default.fileExists(atPath: fileURL.path) {
                        if let sampleImage = UIImage(systemName: "photo.fill"),
                           let imageData = sampleImage.jpegData(compressionQuality: 0.8) {
                            try? imageData.write(to: fileURL)
                        }
                    }
                    
                    if FileManager.default.fileExists(atPath: fileURL.path) {
                        let selectedFile = SelectedFile(
                            id: UUID().uuidString,
                            name: displayName,
                            type: .photo,
                            size: getFileSize(fileURL),
                            url: fileURL
                        )
                        sampleFiles.append(selectedFile)
                    }
                }
                
                continuation.resume(returning: sampleFiles)
            }
        }
    }
    
    func selectDocuments() async -> [SelectedFile] {
        return await withCheckedContinuation { continuation in
            Task { @MainActor in
                // Create sample document files for testing
                var sampleFiles: [SelectedFile] = []
                
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                
                let sampleDocs = [
                    ("sample_document.pdf", "Sample Document.pdf", "This is a sample PDF document for testing file transfer functionality."),
                    ("sample_text.txt", "Sample Text.txt", "This is a sample text file for testing file transfer functionality."),
                    ("sample_data.json", "Sample Data.json", "{\"message\": \"This is a sample JSON file for testing\", \"timestamp\": \"\(Date())\"}"),
                ]
                
                for (fileName, displayName, content) in sampleDocs {
                    let fileURL = documentsPath.appendingPathComponent(fileName)
                    
                    // Create sample document if it doesn't exist
                    if !FileManager.default.fileExists(atPath: fileURL.path) {
                        try? content.write(to: fileURL, atomically: true, encoding: .utf8)
                    }
                    
                    if FileManager.default.fileExists(atPath: fileURL.path) {
                        let selectedFile = SelectedFile(
                            id: UUID().uuidString,
                            name: displayName,
                            type: .document,
                            size: getFileSize(fileURL),
                            url: fileURL
                        )
                        sampleFiles.append(selectedFile)
                    }
                }
                
                continuation.resume(returning: sampleFiles)
            }
        }
    }
    
    func selectVideos() async -> [SelectedFile] {
        return await withCheckedContinuation { continuation in
            Task { @MainActor in
                // Create sample video files for testing
                var sampleFiles: [SelectedFile] = []
                
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                
                let sampleVideos = [
                    ("sample_video1.mp4", "Sample Video 1.mp4"),
                    ("sample_video2.mp4", "Sample Video 2.mp4")
                ]
                
                for (fileName, displayName) in sampleVideos {
                    let fileURL = documentsPath.appendingPathComponent(fileName)
                    
                    // Create placeholder video file if it doesn't exist
                    if !FileManager.default.fileExists(atPath: fileURL.path) {
                        let placeholderContent = "This is a placeholder video file for testing file transfer functionality. In a real app, this would be actual video data."
                        try? placeholderContent.write(to: fileURL, atomically: true, encoding: .utf8)
                    }
                    
                    if FileManager.default.fileExists(atPath: fileURL.path) {
                        let selectedFile = SelectedFile(
                            id: UUID().uuidString,
                            name: displayName,
                            type: .video,
                            size: getFileSize(fileURL),
                            url: fileURL
                        )
                        sampleFiles.append(selectedFile)
                    }
                }
                
                continuation.resume(returning: sampleFiles)
            }
        }
    }
    
    // MARK: - File Operations
    
    func getFileSize(_ fileURL: URL) -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            logger.error("Failed to get file size: \(error)")
            return 0
        }
    }
    
    func getFileType(_ fileURL: URL) -> FileType {
        let pathExtension = fileURL.pathExtension.lowercased()
        
        switch pathExtension {
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "heif":
            return .photo
        case "mp4", "mov", "avi", "mkv", "wmv", "flv", "webm":
            return .video
        case "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "rtf", "md":
            return .document
        default:
            return .document
        }
    }
    
    func createThumbnail(for fileURL: URL) async -> UIImage? {
        let fileType = getFileType(fileURL)
        
        switch fileType {
        case .photo:
            return await createImageThumbnail(fileURL)
        case .video:
            return await createVideoThumbnail(fileURL)
        case .document:
            return createDefaultThumbnail(for: fileType)
        }
    }
    
    private func createImageThumbnail(_ fileURL: URL) async -> UIImage? {
        guard let image = UIImage(contentsOfFile: fileURL.path) else { return nil }
        
        let thumbnailSize = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: thumbnailSize)
        
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: thumbnailSize))
        }
    }
    
    private func createVideoThumbnail(_ fileURL: URL) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            let asset = AVURLAsset(url: fileURL)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            
            let time = CMTime(seconds: 1, preferredTimescale: 60)
            
            imageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, image, _, _, _ in
                if let cgImage = image {
                    let uiImage = UIImage(cgImage: cgImage)
                    continuation.resume(returning: uiImage)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    private func createDefaultThumbnail(for fileType: FileType) -> UIImage? {
        let systemName: String
        
        switch fileType {
        case .document:
            systemName = "doc.text.fill"
        case .photo:
            systemName = "photo.fill"
        case .video:
            systemName = "video.fill"
        }
        
        return UIImage(systemName: systemName)
    }
    
    // MARK: - File Storage
    
    func saveReceivedFile(_ fileURL: URL, to destination: FileDestination = .documents) -> URL? {
        let destinationURL: URL
        
        switch destination {
        case .documents:
            destinationURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        case .downloads:
            destinationURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        case .photos:
            // Save to photo library
            return saveToPhotoLibrary(fileURL)
        }
        
        let finalURL = destinationURL.appendingPathComponent(fileURL.lastPathComponent)
        
        do {
            if FileManager.default.fileExists(atPath: finalURL.path) {
                try FileManager.default.removeItem(at: finalURL)
            }
            try FileManager.default.moveItem(at: fileURL, to: finalURL)
            return finalURL
        } catch {
            logger.error("Failed to save received file: \(error)")
            return nil
        }
    }
    
    private func saveToPhotoLibrary(_ fileURL: URL) -> URL? {
        // This would save to photo library
        // For now, return the original URL
        return fileURL
    }
    
    // MARK: - File Validation
    
    func validateFile(_ fileURL: URL) -> FileValidationResult {
        // Check if file exists
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .invalid("File does not exist")
        }
        
        // Check file size (limit to 1GB)
        let fileSize = getFileSize(fileURL)
        if fileSize > 1_000_000_000 { // 1GB
            return .invalid("File size exceeds 1GB limit")
        }
        
        // Check file type
        _ = getFileType(fileURL)
        // All file types in our simplified enum are supported
        
        return .valid
    }
}

// MARK: - Supporting Types

// Note: SelectedFile and FileType are defined in FileSelectionView.swift

enum FileDestination {
    case documents
    case downloads
    case photos
}

enum FileValidationResult {
    case valid
    case warning(String)
    case invalid(String)
}

// MARK: - Import AVFoundation for video thumbnails

import AVFoundation
