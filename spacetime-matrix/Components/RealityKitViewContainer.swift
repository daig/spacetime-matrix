import RealityKit
import SwiftUI

struct RealityKitViewContainer: View {
    let points: [SIMD3<Float>]?
    
    var body: some View {
        RealityView { content in
            // Create parent entity
            let pointCloudEntity = Entity()
            pointCloudEntity.name = "pointCloud"
            content.add(pointCloudEntity)
            
            // Add a test box at (0,0,0)
            let box = ModelEntity(mesh: .generateBox(size: 0.1), materials: [SimpleMaterial(color: .red, isMetallic: false)])
            content.add(box)
        } update: { content in
            if let pointCloudEntity = content.entities.first(where: { $0.name == "pointCloud" }) {
                pointCloudEntity.children.removeAll()
                
                if let points = points, !points.isEmpty {
                    // Calculate bounding box
                    var minPt = points[0]
                    var maxPt = points[0]
                    for pt in points {
                        minPt.x = min(minPt.x, pt.x)
                        minPt.y = min(minPt.y, pt.y)
                        minPt.z = min(minPt.z, pt.z)
                        maxPt.x = max(maxPt.x, pt.x)
                        maxPt.y = max(maxPt.y, pt.y)
                        maxPt.z = max(maxPt.z, pt.z)
                    }
                    let center = (minPt + maxPt) / 2
                    let centeredPoints = points.map { $0 - center }
                    
                    // Create spheres with larger radius
                    let sphereMesh = MeshResource.generateSphere(radius: 0.01)
                    let material = UnlitMaterial(color: .white)
                    
                    // For testing, limit to 1000 points if too many
                    for point in centeredPoints.prefix(1000) {
                        let pointEntity = ModelEntity(mesh: sphereMesh, materials: [material])
                        pointEntity.position = point
                        pointCloudEntity.addChild(pointEntity)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Optional: Preview provider for development (comment out if not needed in VisionOS context)
#if false
struct RealityKitViewContainer_Previews: PreviewProvider {
    static var previews: some View {
        RealityKitViewContainer(points: [
            SIMD3<Float>(0, 0, 0),
            SIMD3<Float>(1, 1, 1),
            SIMD3<Float>(-1, -1, -1)
        ])
    }
}
#endif
