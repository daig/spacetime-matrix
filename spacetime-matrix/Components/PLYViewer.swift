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
        UTType(exportedAs: "com.spacetime-mic.plyvideo", conformingTo: .directory)
    }
    
    static var drcPlyVideo: UTType {
        UTType(exportedAs: "com.spacetime-mic.drcpack", conformingTo: .package)
    }
}

struct PLYViewer: View {
    @Environment(AppModel.self) private var appModel
    @State private var showFilePicker = false
    @State private var showDirectoryPicker = false
    @State private var showVideoFilePicker = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var plyVideoPaths: [URL] = []
    @State private var dracoFiles: [URL] = []
    @State private var showPLYVideoOptions = false
    @State private var showDracoFileOptions = false
    @State private var showDracoFilePicker = false
    
    var body: some View {
        ZStack {
            VStack {
                if appModel.isPlayingPLYVideo {
                    HStack {
                        Button(action: {
                            appModel.stopPLYVideoPlayback()
                        }) {
                            Image(systemName: "stop.fill")
                                .foregroundColor(.red)
                                .padding()
                                .background(Color.white.opacity(0.7))
                                .clipShape(Circle())
                        }
                        
                        Text("Playing: Frame \(appModel.currentFrameIndex + 1) of \(appModel.plyVideoFrames.count)\(appModel.isDracoEncodedVideo ? " (Draco)" : "")")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                    }
                    .padding(.top, 50)
                }
                Spacer()
                
                HStack {
                    Button(action: {
                        showFilePicker = true
                    }) {
                        Text("Load PLY File")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        showVideoFilePicker = true
                    }) {
                        Text("Load PLY Video")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.purple)
                            .cornerRadius(10)
                    }
                }
                .padding(.bottom, 30)
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
                appModel.currentPoints = points
                appModel.plyVideoFrames = []
                appModel.stopPLYVideoPlayback()
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
        
        for (index, line) in lines.enumerated() {
            if line.contains("element vertex") {
                numVertices = Int(line.components(separatedBy: " ").last ?? "0") ?? 0
            }
            if line == "end_header" {
                dataStartIndex = index + 1
                break
            }
        }
        
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
    
    private func loadDracoPLYVideo(from url: URL) {
        print("Loading Draco video from directory: \(url.path)")
        
        do {
            let fileManager = FileManager.default
            let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            let drcFiles = contents.filter { $0.pathExtension == "drc" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            
            print("Found \(drcFiles.count) DRC files")
            
            var frames: [[SIMD3<Float>]] = []
            for drcFile in drcFiles {
                if let points = DracoService.shared.loadDracoPointCloudFromFile(url: drcFile) {
                    frames.append(points)
                }
            }
            
            if !frames.isEmpty {
                print("Successfully loaded \(frames.count) frames")
                appModel.plyVideoFrames = frames
                appModel.isDracoEncodedVideo = true
                
                let metadataURL = url.appendingPathComponent("metadata.json")
                var frameRate: Double = 30.0
                
                if let metadataData = try? Data(contentsOf: metadataURL),
                   let metadata = try? JSONSerialization.jsonObject(with: metadataData) as? [String: Any],
                   let rate = metadata["frameRate"] as? Double {
                    frameRate = rate
                }
                
                appModel.startPLYVideoPlayback(frameRate: frameRate)
            } else {
                DispatchQueue.main.async {
                    self.showAlert(title: "Error", message: "No valid Draco files found in directory")
                }
            }
        } catch {
            print("Error loading Draco video: \(error)")
            DispatchQueue.main.async {
                self.showAlert(title: "Error", message: "Failed to load Draco video: \(error.localizedDescription)")
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            rootViewController.present(alert, animated: true)
        }
    }
    
    struct DocumentPicker: UIViewControllerRepresentable {
        let contentTypes: [UTType]
        let onPick: (URL) -> Void
        
        init(contentTypes: [UTType], onPick: @escaping (URL) -> Void) {
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
                guard url.startAccessingSecurityScopedResource() else {
                    print("Failed to access the file")
                    return
                }
                defer { url.stopAccessingSecurityScopedResource() }
                onPick(url)
            }
        }
    }
    
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
                guard url.startAccessingSecurityScopedResource() else {
                    print("Failed to access the directory")
                    return
                }
                defer { url.stopAccessingSecurityScopedResource() }
                onPick(url)
            }
        }
    }
}
