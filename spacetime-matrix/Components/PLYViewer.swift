import SwiftUI
import SceneKit
import UniformTypeIdentifiers
import RealityKit

import UIKit

extension UTType {
    static var ply: UTType {
        UTType(filenameExtension: "ply")!
    }
    
    static var plyVideo: UTType {
        // Register a more specific type with a custom extension
        UTType(exportedAs: "com.spacetime-mic.plyvideo", 
               conformingTo: .directory)
    }
    
    static var drcPlyVideo: UTType {
        // Register a type for Draco-encoded PLY video packages
        UTType(exportedAs: "com.spacetime-mic.drcpack", 
               conformingTo: .package)
    }
}

struct PLYViewer: View {
    @State private var showFilePicker = false
    @State private var showDirectoryPicker = false
    @State private var showVideoFilePicker = false  // New state for video picker
    @State private var selectedPoints: [SIMD3<Float>]?
    @State private var isPlayingPLYVideo = false
    @State private var plyVideoFrames: [[SIMD3<Float>]] = []
    @State private var currentFrameIndex = 0
    @State private var videoPlaybackTimer: Timer?
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var plyVideoPaths: [URL] = []
    @State private var dracoFiles: [URL] = []
    @State private var showPLYVideoOptions = false
    @State private var showDracoFileOptions = false
    @State private var isDracoEncodedVideo = false
    @State private var showDracoFilePicker = false
    
    var body: some View {
        ZStack {
//            SceneKitViewContainer(points: selectedPoints)
            RealityKitViewContainer(points: selectedPoints)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            VStack {
                if isPlayingPLYVideo {
                    HStack {
                        Button(action: {
                            stopPLYVideoPlayback()
                        }) {
                            Image(systemName: "stop.fill")
                                .foregroundColor(.red)
                                .padding()
                                .background(Color.white.opacity(0.7))
                                .clipShape(Circle())
                        }
                        
                        Text("Playing: Frame \(currentFrameIndex + 1) of \(plyVideoFrames.count)\(isDracoEncodedVideo ? " (Draco)" : "")")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                    }
                    .padding(.top, 50)
                }
                Spacer()
                
                Button(action: {
                    showVideoFilePicker = true
                }) {
                    Text("Load PLY Video")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.purple)
                        .cornerRadius(10)
                } .padding(.bottom, 30)
            }
        }
        .sheet(isPresented: $showFilePicker) {
            DocumentPicker(contentTypes: [.ply]) { url in
                loadPLYFile(from: url)
            }
        }
        .sheet(isPresented: $showVideoFilePicker) {
            DirectoryPicker { url in
                loadDracoPLYVideo(from: url)
            }
        }
    }
    
    private func loadPLYFile(from url: URL) {
        if url.pathExtension == "drcpack" {
            loadDracoPLYVideo(from: url)
        } else {
            do {
                let contents = try String(contentsOf: url, encoding: .utf8)
                let points = parsePLYFile(contents)
                selectedPoints = points
            } catch {
                print("Error loading PLY file: \(error)")
                showAlert(title: "Error", message: "Failed to load PLY file: \(error.localizedDescription)")
            }
        }
    }
    
    private func parsePLYFile(_ contents: String) -> [SIMD3<Float>] {
        var points: [SIMD3<Float>] = []
        let lines = contents.components(separatedBy: .newlines)
        var dataStartIndex = 0
        var numVertices = 0
        
        // Find where the vertex data begins and get number of vertices
        for (index, line) in lines.enumerated() {
            if line.contains("element vertex") {
                numVertices = Int(line.components(separatedBy: " ").last ?? "0") ?? 0
            }
            if line == "end_header" {
                dataStartIndex = index + 1
                break
            }
        }
        
        // Parse vertex data
        let endIndex = min(dataStartIndex + numVertices, lines.count)
        for i in dataStartIndex..<endIndex {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            
            let coordinates = line.split(separator: " ").compactMap { Float($0) }
            if coordinates.count >= 3 {
                points.append(SIMD3<Float>(coordinates[0], coordinates[1], coordinates[2]))
            }
        }
        
        return points
    }
    
    
    private func startPLYVideoPlayback(frameRate: Double) {
        guard !plyVideoFrames.isEmpty else { return }
        
        // Create a fresh copy of each frame to ensure SwiftUI sees changes
        var freshFrames: [[SIMD3<Float>]] = []
        for frame in plyVideoFrames {
            // Force create a new array for each frame
            let freshFrame = frame.map { SIMD3<Float>($0.x, $0.y, $0.z) }
            freshFrames.append(freshFrame)
        }
        
        // Use the fresh frames for playback
        plyVideoFrames = freshFrames
        
        // Reset to first frame
        currentFrameIndex = 0
        selectedPoints = plyVideoFrames.first
        isPlayingPLYVideo = true
        
        // Set up timer for playback (default to 1 frame per second)
        let interval = 1.0 / frameRate
        videoPlaybackTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            // No need for weak self since PLYViewer is a struct (value type)
            self.advanceToNextFrame()
        }
    }
    
    private func advanceToNextFrame() {
        guard !plyVideoFrames.isEmpty else { return }
        
        // Store previous frame's point count for comparison
        let previousFrameIndex = currentFrameIndex
        let previousPointCount = plyVideoFrames[previousFrameIndex].count
        
        // Move to next frame
        currentFrameIndex = (currentFrameIndex + 1) % plyVideoFrames.count
        
        // Get current frame
        let currentFramePoints = plyVideoFrames[currentFrameIndex]
        let currentPointCount = currentFramePoints.count
        
        print("Frame transition: \(previousFrameIndex) -> \(currentFrameIndex)")
        print("Point counts: \(previousPointCount) -> \(currentPointCount)")
        
        // Create a fresh copy of the frame to ensure SwiftUI detects the change
        // This forces SwiftUI to see it as a brand new array
        let freshFrame = currentFramePoints.map { SIMD3<Float>($0.x, $0.y, $0.z) }
        
        // Update state with the fresh frame
        // This ensures that even if the frame data is the same,
        // SwiftUI will see it as a new array and update the view
        selectedPoints = freshFrame
        
        // If we've completed a loop, stop playback
//        if currentFrameIndex == 0 { stopPLYVideoPlayback() }
    }
    
    private func stopPLYVideoPlayback() {
        videoPlaybackTimer?.invalidate()
        videoPlaybackTimer = nil
        isPlayingPLYVideo = false
        isDracoEncodedVideo = false
    }
    
    // New method to open picker for Draco-encoded PLY video bundles
    private func openDracoPLYVideoDirectoryPicker() {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let fileManager = FileManager.default
                guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                    print("Could not access documents directory")
                    return
                }
                
                // Get list of directories in the Documents folder
                let contents = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: [.isDirectoryKey], options: [])
                
                // Filter for only directories that match our naming pattern for Draco PLY video bundles
                var dracoPLYVideoPaths: [URL] = []
                
                for url in contents {
                    let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
                    let isDirectory = resourceValues.isDirectory ?? false
                    
                    if isDirectory && url.lastPathComponent.contains(".drc.bundle") {
                        dracoPLYVideoPaths.append(url)
                    }
                }
                
                DispatchQueue.main.async {
                    if dracoPLYVideoPaths.isEmpty {
                        self.showAlert(title: "No Draco PLY Videos Found", 
                                       message: "No Draco-encoded PLY video folders were found in your Documents directory. Record a PLY video first.")
                    } else {
                        // Show list of available Draco PLY videos
                        self.showDracoPLYVideoSelectionMenu(videos: dracoPLYVideoPaths)
                    }
                }
            } catch {
                print("Error listing documents directory: \(error)")
                
                DispatchQueue.main.async {
                    self.showAlert(title: "Error",
                                   message: "Failed to access Draco PLY video directories: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // Helper method to show alerts with platform-specific implementations
    private func showAlert(title: String, message: String) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            let alert = UIAlertController(
                title: title,
                message: message,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            rootViewController.present(alert, animated: true)
        }
    }
    
    // New method to show a menu of available Draco PLY videos
    private func showDracoPLYVideoSelectionMenu(videos: [URL]) {
        guard !videos.isEmpty else { return }
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            
            let alert = UIAlertController(
                title: "Select Draco PLY Video",
                message: "Choose a Draco-encoded PLY video to play:",
                preferredStyle: .actionSheet
            )
            
            // Add an action for each video
            for video in videos {
                let name = video.lastPathComponent
                alert.addAction(UIAlertAction(title: name, style: .default) { _ in
                    self.loadDracoPLYVideo(from: video)
                })
            }
            
            // Add cancel button
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            
            rootViewController.present(alert, animated: true)
        }
    }
    
    // Method to load and play a Draco-encoded PLY video
    private func loadDracoPLYVideo(from url: URL) {
        print("Loading Draco video from directory: \(url.path)")
        
        // Load all DRC files from the directory
        do {
            let fileManager = FileManager.default
            let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            let drcFiles = contents.filter { $0.pathExtension == "drc" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent } // Sort by filename
            
            print("Found \(drcFiles.count) DRC files")
            
            // Load each DRC file
            var frames: [[SIMD3<Float>]] = []
            for drcFile in drcFiles {
                if let points = DracoService.shared.loadDracoPointCloudFromFile(url: drcFile) {
                    frames.append(points)
                }
            }
            
            if !frames.isEmpty {
                print("Successfully loaded \(frames.count) frames")
                self.plyVideoFrames = frames
                self.isDracoEncodedVideo = true
                
                // Find metadata file to get frame rate, default to 30fps if not found
                let metadataURL = url.appendingPathComponent("metadata.json")
                var frameRate: Double = 30.0
                
                if let metadataData = try? Data(contentsOf: metadataURL),
                   let metadata = try? JSONSerialization.jsonObject(with: metadataData) as? [String: Any],
                   let rate = metadata["frameRate"] as? Double {
                    frameRate = rate
                }
                
                // Start playback
                self.startPLYVideoPlayback(frameRate: frameRate)
            } else {
                DispatchQueue.main.async {
                    self.showAlert(title: "Error",
                                 message: "No valid Draco files found in directory")
                }
            }
        } catch {
            print("Error loading Draco video: \(error)")
            DispatchQueue.main.async {
                self.showAlert(title: "Error",
                             message: "Failed to load Draco video: \(error.localizedDescription)")
            }
        }
    }

// Modified DocumentPicker to accept content types
struct DocumentPicker: UIViewControllerRepresentable {
    let contentTypes: [UTType]
    let onPick: (URL) -> Void
    
    init(contentTypes: [UTType] = [.ply, .drcPlyVideo], onPick: @escaping (URL) -> Void) {
        self.contentTypes = contentTypes
        self.onPick = onPick
    }
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes)
        documentPicker.delegate = context.coordinator
        documentPicker.allowsMultipleSelection = false
        documentPicker.shouldShowFileExtensions = true
        return documentPicker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        
        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            // Start accessing the security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                print("Failed to access the file")
                return
            }
            
            // Make sure to release the security-scoped resource when finished
            defer { url.stopAccessingSecurityScopedResource() }
            
            onPick(url)
        }
    }
}

// Helper class for presenting document picker modally
class DocumentPickerDelegate: NSObject, UIDocumentPickerDelegate {
    let onPick: (URL) -> Void
    
    init(onPick: @escaping (URL) -> Void) {
        self.onPick = onPick
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        
        // Start accessing the security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            print("Failed to access the file")
            return
        }
        
        // Make sure to release the security-scoped resource when finished
        defer { url.stopAccessingSecurityScopedResource() }
        
        onPick(url)
    }
}

// Function to handle Draco file selection
private func handleDracoFileSelection() {
    DispatchQueue.global(qos: .userInitiated).async {
        do {
            let fileManager = FileManager.default
            guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                print("Could not access documents directory")
                return
            }
            
            // Get list of .drc files in the Documents folder
            let contents = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
            let dracoFiles = contents.filter { $0.pathExtension == "drc" }
            
            DispatchQueue.main.async {
                if dracoFiles.isEmpty {
                    self.showAlert(title: "No Draco Files", 
                                 message: "No Draco files found in documents directory.\nFirst save a point cloud as Draco format.")
                } else {
                    self.showDracoFileSelectionMenu(files: dracoFiles)
                }
            }
        } catch {
            print("Error accessing documents directory: \(error)")
            
            DispatchQueue.main.async {
                self.showAlert(title: "Error",
                             message: "Failed to access Draco files: \(error.localizedDescription)")
            }
        }
    }
}

// Function to display a menu with available Draco files
private func showDracoFileSelectionMenu(files: [URL]) {
    guard !files.isEmpty else { return }
    
    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
       let rootViewController = windowScene.windows.first?.rootViewController {
        
        let alert = UIAlertController(
            title: "Select Draco File",
            message: "Choose a Draco file to load:",
            preferredStyle: .actionSheet
        )
        
        // Add an action for each file
        for file in files {
            let name = file.lastPathComponent
            alert.addAction(UIAlertAction(title: name, style: .default) { _ in
                self.loadDracoFile(from: file)
            })
        }
        
        // Add cancel button
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        rootViewController.present(alert, animated: true)
    }
}

// Function to load a Draco file and display the points
private func loadDracoFile(from url: URL) {
    DispatchQueue.global(qos: .userInitiated).async {
        // Create a separate autorelease pool for this work
        autoreleasepool {
            do {
                // First verify the file exists and is readable
                print("[Draco] Loading file: \(url.lastPathComponent)")
                
                // Use DracoService to load the points
                guard let points = DracoService.shared.loadDracoPointCloudFromFile(url: url) else {
                    throw NSError(domain: "DracoDecoding", code: 1, 
                                userInfo: [NSLocalizedDescriptionKey: "Failed to load Draco file (null result)"])
                }
                
                // Make a copy of the points array to ensure memory safety
                let pointsCopy = Array(points)
                print("[Draco] Successfully loaded \(pointsCopy.count) points")
                
                // Send the points to the main thread
                DispatchQueue.main.async {
                    print("[Draco] Updating UI with \(pointsCopy.count) points")
                    self.selectedPoints = pointsCopy
                    
                    // Show success message
                    self.showAlert(title: "Draco File Loaded",
                                 message: "Loaded \(pointsCopy.count) points from \(url.lastPathComponent)")
                }
            } catch {
                print("[Draco] Error loading file: \(error)")
                
                DispatchQueue.main.async {
                    self.showAlert(title: "Error",
                                 message: "Failed to load Draco file: \(url.lastPathComponent)\nError: \(error.localizedDescription)")
                }
            }
        }
    }
}

// Directory picker for selecting PLY video folders
struct DirectoryPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        
        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            // Start accessing the security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                print("Failed to access the directory")
                return
            }
            
            // Make sure to release the security-scoped resource when finished
            defer { url.stopAccessingSecurityScopedResource() }
            
            onPick(url)
        }
    }
}
}
