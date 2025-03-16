//
//  ImmersiveView.swift
//  spacetime-matrix
//
//  Created by David Girardo on 3/15/25.
//

import SwiftUI
import RealityKit

struct ImmersiveView: View {
    @Environment(AppModel.self) var appModel

    var body: some View {
        RealityView { content in
            // Create parent entity for point cloud
            let pointCloudEntity = Entity()
            pointCloudEntity.name = "pointCloud"
            content.add(pointCloudEntity)
            
            // Add a test box at (0,0,0)
            let box = ModelEntity(mesh: .generateBox(size: 0.1), materials: [SimpleMaterial(color: .red, isMetallic: false)])
            content.add(box)
        } update: { content in
            if let pointCloudEntity = content.entities.first(where: { $0.name == "pointCloud" }),
               let points = appModel.currentPoints,
               !points.isEmpty {
                pointCloudEntity.children.removeAll()
                
                // Calculate bounding box and center points
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
                
                // Create spheres for points
                let sphereMesh = MeshResource.generateSphere(radius: 0.01)
                let material = UnlitMaterial(color: .white)
                
                // Limit to 1000 points for performance (adjust as needed)
                for point in centeredPoints.prefix(1000) {
                    let pointEntity = ModelEntity(mesh: sphereMesh, materials: [material])
                    pointEntity.position = point
                    pointCloudEntity.addChild(pointEntity)
                }
            }
        }
    }
}
