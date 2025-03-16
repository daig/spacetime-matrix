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
            // Create a parent entity for the point cloud
            let pointCloudEntity = Entity()
            pointCloudEntity.name = "pointCloud"
            content.add(pointCloudEntity)
            
            // Optional: Add a reference box at (0,0,0) for debugging
            let box = ModelEntity(mesh: .generateBox(size: 0.1), materials: [SimpleMaterial(color: .red, isMetallic: false)])
            content.add(box)
        } update: { content in
            if let pointCloudEntity = content.entities.first(where: { $0.name == "pointCloud" }),
               let points = appModel.currentPoints,
               !points.isEmpty {
                pointCloudEntity.children.removeAll()
                
                // Calculate the bounding box to find the center
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
                
                // Create spheres for the points
                let sphereMesh = MeshResource.generateSphere(radius: 0.01)
                let material = UnlitMaterial(color: .white)
                
                for point in points.prefix(1000) {
                    // Center the points by subtracting the center
                    let centeredPoint = [point.x, point.y, -point.z] - center
                    let pointEntity = ModelEntity(mesh: sphereMesh, materials: [material])
                    pointEntity.position = centeredPoint
                    pointCloudEntity.addChild(pointEntity)
                }
                
                // Translate the point cloud forward along Z-axis
                let distance: Float = 2.0  // 2 meters in front of the viewer
                pointCloudEntity.position = [0, 0, distance]
            }
        }
    }
}
