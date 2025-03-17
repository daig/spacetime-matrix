import SwiftUI
import RealityKit
import simd

struct ImmersiveView: View {
    @Environment(AppModel.self) var appModel

    // Replace this with the actual number of points per frame from your data
    let fixedPointCount = 49152 // Example value; adjust to your known point count

    var body: some View {
        RealityView { content in
            // Create a parent entity for the point cloud
            let pointCloudEntity = Entity()
            pointCloudEntity.name = "pointCloud"
            content.add(pointCloudEntity)
            
            // Initialize with placeholder points (all zeros) using the fixed count
            let initialPoints = Array(repeating: SIMD3<Float>(0, 0, 0), count: fixedPointCount)
            let initialMesh = try! createPointCloudMesh(points: initialPoints)
            let initialMeshResource = try! MeshResource(from: initialMesh)
            let modelEntity = ModelEntity(mesh: initialMeshResource, materials: [UnlitMaterial(color: .white)])
            modelEntity.name = "pointCloudModel"
            pointCloudEntity.addChild(modelEntity)
            
            // Position the point cloud 2 meters in front of the viewer
            pointCloudEntity.position = [0, 0, 2.0]
            
            // Add a reference box at origin for debugging
            let box = ModelEntity(mesh: .generateBox(size: 0.1), materials: [SimpleMaterial(color: .red, isMetallic: false)])
            content.add(box)
        } update: { content in
            // Find the point cloud and model entities
            if let pointCloudEntity = content.entities.first(where: { $0.name == "pointCloud" }),
               let modelEntity = pointCloudEntity.children.first(where: { $0.name == "pointCloudModel" }) as? ModelEntity,
               var modelComponent = modelEntity.model {
                // Get current points, falling back to placeholder if nil
                var points = appModel.currentPoints ?? Array(repeating: SIMD3<Float>(0, 0, 0), count: fixedPointCount)
                
                // Ensure the point count matches fixedPointCount
                if points.count != fixedPointCount {
                    print("Warning: Expected \(fixedPointCount) points, got \(points.count). Using placeholder.")
                    points = Array(repeating: SIMD3<Float>(0, 0, 0), count: fixedPointCount)
                }
                
                // Transform points (center them and flip z-axis)
                var minPt = points[0]
                var maxPt = points[0]
                for pt in points {
                    minPt = min(minPt, pt)
                    maxPt = max(maxPt, pt)
                }
                let center = (minPt + maxPt) / 2
                let transformedPoints = points.map { SIMD3<Float>($0.x - center.x, $0.y - center.y, -$0.z - center.z) }
                
                // Create and assign a new mesh
                let newMesh = try! createPointCloudMesh(points: transformedPoints)
                let newMeshResource = try! MeshResource(from: newMesh)
                modelComponent.mesh = newMeshResource
                modelEntity.model = modelComponent
            }
        }
    }
    
    /// Creates a LowLevelMesh for rendering points with .point topology
    private func createPointCloudMesh(points: [SIMD3<Float>]) throws -> LowLevelMesh {
        // Define vertex attributes (position only)
        let positionAttribute = LowLevelMesh.Attribute(
            semantic: .position,
            format: .float3,
            offset: 0
        )
        let vertexAttributes = [positionAttribute]

        // Define vertex layout
        let vertexLayouts = [
            LowLevelMesh.Layout(
                bufferIndex: 0,
                bufferStride: MemoryLayout<SIMD3<Float>>.stride
            )
        ]

        // Create mesh descriptor
        let descriptor = LowLevelMesh.Descriptor(
            vertexCapacity: points.count,
            vertexAttributes: vertexAttributes,
            vertexLayouts: vertexLayouts,
            indexCapacity: 0
        )

        // Initialize the mesh
        let mesh = try LowLevelMesh(descriptor: descriptor)

        // Fill vertex buffer
        mesh.withUnsafeMutableBytes(bufferIndex: 0) { rawBytes in
            let vertexData = rawBytes.baseAddress!
            points.withUnsafeBytes { pointsBuffer in
                let pointsData = pointsBuffer.baseAddress!
                memcpy(vertexData, pointsData, points.count * MemoryLayout<SIMD3<Float>>.stride)
            }
        }

        // Compute bounding box
        var minBounds = SIMD3<Float>(repeating: Float.greatestFiniteMagnitude)
        var maxBounds = SIMD3<Float>(repeating: -Float.greatestFiniteMagnitude)
        for point in points {
            minBounds = min(minBounds, point)
            maxBounds = max(maxBounds, point)
        }
        let bounds = BoundingBox(min: minBounds, max: maxBounds)

        // Define mesh part for point topology
        let part = LowLevelMesh.Part(
            indexOffset: 0,
            indexCount: 49152,
            topology: .point,
            materialIndex: 0,
            bounds: bounds
        )
        mesh.parts.replaceAll([part])

        return mesh
    }
}
