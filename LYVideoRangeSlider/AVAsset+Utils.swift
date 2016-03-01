//
//  AVAsset+Utils.swift
//  LYVideoRangeSlider
//
//  Created by Leon.yan on 2/22/16.
//  Copyright © 2016 V+I. All rights reserved.
//

import Foundation
import AVFoundation

extension AVAsset {
    
    func aVideoTrack() -> AVAssetTrack? {
        return _aTrack(AVMediaTypeVideo)
    }
    
    func aAudioTrack() -> AVAssetTrack? {
        return _aTrack(AVMediaTypeAudio)
    }
    
    func hasVideoTrack() -> Bool {
        return _hasTrack(AVMediaTypeVideo)
    }
    
    func hasAudioTrack() -> Bool {
        return _hasTrack(AVMediaTypeAudio)
    }
    
    /**
     * get the video size which applyed the orientation
     */
    var videoSize : CGSize {
        if !_hasTrack(AVMediaTypeVideo) {
            return CGSizeZero
        }
        let videoTrack = aVideoTrack()
        return videoTrack!.videoSize
    }
    
    var timeRange : CMTimeRange {
        if !_hasTrack(AVMediaTypeVideo) {
            return kCMTimeRangeInvalid
        }
        
        let videoTrack = aVideoTrack()
        return videoTrack!.timeRange
    }
    
    private func _aTrack(mediaType : String) -> AVAssetTrack? {
        if self._hasTrack(mediaType) {
            return self.tracksWithMediaType(mediaType).first
        } else {
            return nil
        }
    }
    private func _hasTrack(mediaType : String) -> Bool {
        return self.tracksWithMediaType(mediaType).count > 0
    }
}

extension AVAssetTrack
{
    var videoSize : CGSize {
        if self.mediaType != AVMediaTypeVideo {
            return CGSizeZero
        }
        let preferredSize = CGSizeApplyAffineTransform(naturalSize, preferredTransform)
        return CGSizeMake(abs(preferredSize.width), abs(preferredSize.height))
    }
}