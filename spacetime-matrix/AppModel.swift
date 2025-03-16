//
//  AppModel.swift
//  spacetime-matrix
//
//  Created by David Girardo on 3/15/25.
//

import SwiftUI

/// Maintains app-wide state
@MainActor
@Observable
class AppModel {
    let immersiveSpaceID = "ImmersiveSpace"
    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }
    var immersiveSpaceState = ImmersiveSpaceState.closed
    
    // Point cloud and video playback state
    var currentPoints: [SIMD3<Float>]? // Current points to render
    var plyVideoFrames: [[SIMD3<Float>]] = [] // Sequence of frames for video
    var currentFrameIndex: Int = 0
    var isPlayingPLYVideo: Bool = false
    var videoPlaybackTimer: Timer?
    var isDracoEncodedVideo: Bool = false // To track Draco video type
    
    /// Starts playback of a PLY video at the specified frame rate
    func startPLYVideoPlayback(frameRate: Double) {
        guard !plyVideoFrames.isEmpty else { return }
        currentFrameIndex = 0
        currentPoints = plyVideoFrames.first
        isPlayingPLYVideo = true
        let interval = 1.0 / frameRate
        videoPlaybackTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            self.advanceToNextFrame()
        }
    }
    
    /// Advances to the next frame in the video
    func advanceToNextFrame() {
        guard !plyVideoFrames.isEmpty else { return }
        currentFrameIndex = (currentFrameIndex + 1) % plyVideoFrames.count
        currentPoints = plyVideoFrames[currentFrameIndex]
    }
    
    /// Stops video playback
    func stopPLYVideoPlayback() {
        videoPlaybackTimer?.invalidate()
        videoPlaybackTimer = nil
        isPlayingPLYVideo = false
        isDracoEncodedVideo = false
    }
}
