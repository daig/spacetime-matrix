//
//  PLYVideoPlayer.swift
//  spacetime-matrix
//
//  Created by David Girardo on 3/16/25.
//

import RealityKit
import SwiftUI
import SceneKit

struct SceneKitViewContainer: UIViewRepresentable {
    let points: [SIMD3<Float>]?
    
    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView(frame: .zero)
        sceneView.backgroundColor = .black
        sceneView.scene = SCNScene()
        sceneView.allowsCameraControl = true // Built-in rotation and pan controls
        sceneView.autoenablesDefaultLighting = true
        
        // Create a persistent point cloud node that we'll update
        let pointCloudNode = SCNNode()
        pointCloudNode.name = "pointCloudNode"
        sceneView.scene?.rootNode.addChildNode(pointCloudNode)
        
        // Create a persistent camera node
        let cameraNode = SCNNode()
        cameraNode.name = "cameraNode"
        cameraNode.camera = SCNCamera()
        sceneView.scene?.rootNode.addChildNode(cameraNode)
        sceneView.pointOfView = cameraNode
        
        sceneView.scene?.background.contents = UIColor.black
        
        return sceneView
    }
    
    func updateUIView(_ sceneView: SCNView, context: Context) {
        guard let points = points, !points.isEmpty else { return }
        
        // Log point cloud update request
        print("🔄 SceneKit view update requested with \(points.count) points at \(Unmanaged.passUnretained(points as AnyObject).toOpaque())")
        
        // Get or create the point cloud node
        let pointCloudNode: SCNNode
        if let existingNode = sceneView.scene?.rootNode.childNode(withName: "pointCloudNode", recursively: false) {
            // Remove any existing geometry
            pointCloudNode = existingNode
            pointCloudNode.geometry = nil
        } else {
            // Create the node if it doesn't exist (shouldn't happen)
            pointCloudNode = SCNNode()
            pointCloudNode.name = "pointCloudNode"
            sceneView.scene?.rootNode.addChildNode(pointCloudNode)
        }
        
        // Create point cloud geometry
        let vertices = points.map { point in
            // Keep original coordinates - preserve the perspective
            SCNVector3(point.x, point.y, point.z)
        }
        
        // Update the point cloud geometry
        updatePointCloudGeometry(node: pointCloudNode, from: vertices)
        
        // Check if we need to initialize the camera
        if let cameraNode = sceneView.scene?.rootNode.childNode(withName: "cameraNode", recursively: false),
           cameraNode.camera != nil,
           // Only set up camera initially or if it hasn't been positioned yet
           (cameraNode.position.x == 0 && cameraNode.position.y == 0 && cameraNode.position.z == 0) {
            setupInitialCamera(cameraNode: cameraNode, points: vertices)
        }
        
        print("✅ Updated point cloud with \(points.count) points")
    }
    
    private func updatePointCloudGeometry(node: SCNNode, from vertices: [SCNVector3]) {
        // Create geometry source from vertices
        let source = SCNGeometrySource(vertices: vertices)
        
        // Create indices
        let indices = (0..<vertices.count).map { UInt32($0) }
        let indexData = Data(bytes: indices, count: indices.count * MemoryLayout<UInt32>.size)
        
        // Create geometry element for points
        let element = SCNGeometryElement(
            data: indexData,
            primitiveType: .point,
            primitiveCount: vertices.count,
            bytesPerIndex: MemoryLayout<UInt32>.size
        )
        
        // Create geometry
        let geometry = SCNGeometry(sources: [source], elements: [element])
        
        // Create material
        let material = SCNMaterial()
        
        material.diffuse.contents = UIColor.white
        
        material.lightingModel = .constant
        
        // Set point size (make it larger for visibility)
        material.setValue(3.0, forKey: "pointSize")
        
        geometry.materials = [material]
        
        // Set the geometry on the node
        node.geometry = geometry
        
        // Apply rotation to correct the orientation
        // Rotate 90 degrees clockwise around the Z-axis to counter the counter-clockwise rotation
        node.eulerAngles = SCNVector3(0, 0, -Float.pi/2)
        
        // Apply scale to flip the Z axis to correct backwards appearance
        node.scale = SCNVector3(1, 1, -1)
    }
    
    private func createPointCloudNode(from vertices: [SCNVector3]) -> SCNNode {
        // This method is kept for compatibility as a wrapper to our new function
        let node = SCNNode()
        updatePointCloudGeometry(node: node, from: vertices)
        return node
    }
    
    private func setupInitialCamera(cameraNode: SCNNode, points: [SCNVector3]) {
        // Calculate bounding box
        var minX: Float = .greatestFiniteMagnitude
        var minY: Float = .greatestFiniteMagnitude
        var minZ: Float = .greatestFiniteMagnitude
        var maxX: Float = -.greatestFiniteMagnitude
        var maxY: Float = -.greatestFiniteMagnitude
        var maxZ: Float = -.greatestFiniteMagnitude
        
        for point in points {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
            minZ = min(minZ, point.z)
            maxZ = max(maxZ, point.z)
        }
        
        // Calculate center
        let centerX = (minX + maxX) / 2
        let centerY = (minY + maxY) / 2
        let centerZ = (minZ + maxZ) / 2
        
        // Calculate dimensions
        let sizeX = max(abs(maxX - minX), 0.1)
        let sizeY = max(abs(maxY - minY), 0.1)
        let sizeZ = max(abs(maxZ - minZ), 0.1)
        
        let maxDimension = max(max(sizeX, sizeY), sizeZ)
        
        // Position camera at a distance from the point cloud
        cameraNode.position = SCNVector3(centerX, centerY, centerZ + maxDimension * 1.5)
        
        // Look directly at the center of the point cloud
        cameraNode.look(at: SCNVector3(centerX, centerY, centerZ))
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: SceneKitViewContainer
        
        init(_ parent: SceneKitViewContainer) {
            self.parent = parent
        }
    }
}
