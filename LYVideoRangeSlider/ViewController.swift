//
//  ViewController.swift
//  LYVideoRangeSlider
//
//  Created by Leon.yan on 2/22/16.
//  Copyright © 2016 V+I. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController, LVVideoRangeSliderDelegate {
    @IBOutlet weak var videoRangeSlider : LYVideoRangeSlider!
    @IBOutlet weak var previewView : UIView!
    
    var playerLayer : AVPlayerLayer?
    var player : AVPlayer?
    var playerItem : AVPlayerItem?
    var startTime : CMTime = kCMTimeInvalid

    override func viewDidLoad() {
        super.viewDidLoad()
        videoRangeSlider.delegate = self
        // Do any additional setup after loading the view, typically from a nib.
        self.previewView.userInteractionEnabled = true
        self.previewView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: "tapHandler:"))
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func addAsset() {
        let videoAsset = AVURLAsset(URL: NSBundle.mainBundle().URLForResource("vid", withExtension: "mp4")!)
        let playerItem = AVPlayerItem(asset: videoAsset)
        if player == nil {
            player = AVPlayer(playerItem: playerItem)
            let playerLayer = AVPlayerLayer(player: player)
            playerLayer.frame = previewView.bounds
            previewView.layer.addSublayer(playerLayer)
            self.playerLayer = playerLayer
            
            NSNotificationCenter.defaultCenter().addObserver(self, selector: "playerDidReachEnd:", name: AVPlayerItemDidPlayToEndTimeNotification, object: nil)
        } else {
            player!.replaceCurrentItemWithPlayerItem(playerItem)
        }
        self.playerItem = playerItem
        
        videoRangeSlider!.setupVideoAsset(videoAsset, timeRange: videoAsset.timeRange, minClipDuration: -1, maxClipDuration: 4)
    }
    
    @IBAction func addAsset2() {
        let videoAsset = AVURLAsset(URL: NSBundle.mainBundle().URLForResource("IMG_0260", withExtension: "mp4")!)
        let playerItem = AVPlayerItem(asset: videoAsset)
        if player == nil {
            player = AVPlayer(playerItem: playerItem)
            let playerLayer = AVPlayerLayer(player: player)
            playerLayer.frame = previewView.bounds
            previewView.layer.addSublayer(playerLayer)
            self.playerLayer = playerLayer
        } else {
            player!.replaceCurrentItemWithPlayerItem(playerItem)
        }
        
        self.playerItem = playerItem
        
        videoRangeSlider!.setupVideoAsset(videoAsset, timeRange: videoAsset.timeRange, minClipDuration: -1, maxClipDuration: 2)
    }

    func timeRangeDidChanged(timeRange: CMTimeRange) {
        let start = timeRange.start
        if player != nil {
            player!.seekToTime(start, toleranceBefore: CMTimeMake(1, 30), toleranceAfter: CMTimeMake(1, 30))
        }
    }
    
    func timeRangeDidConfirm(timeRange: CMTimeRange) {
        startTime = timeRange.start
        let endTime = CMTimeRangeGetEnd(timeRange)
        if playerItem != nil {
            playerItem!.forwardPlaybackEndTime = endTime
            player!.seekToTime(startTime, toleranceBefore: CMTimeMake(1, 30), toleranceAfter: CMTimeMake(1, 30))
        }
    }
    
    func playerDidReachEnd(noti : NSNotification) {
        if CMTIME_IS_VALID(startTime) && player != nil {
            player!.seekToTime(startTime, toleranceBefore: CMTimeMake(1, 30), toleranceAfter: CMTimeMake(1, 30))
            player!.play()
        }
    }
    
    func tapHandler(tap : UITapGestureRecognizer) {
        if player != nil {
            if player!.rate != 0.0 {
                player!.pause()
            } else {
                player!.play()
            }
        }
    }
    
}

