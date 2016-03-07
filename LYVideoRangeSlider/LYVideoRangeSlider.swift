//
//  LYVideoRangeSlider.swift
//  LYVideoRangeSlider
//
//  Created by Leon.yan on 2/22/16.
//  Copyright © 2016 V+I. All rights reserved.
//

import AVFoundation
import UIKit

protocol LVVideoRangeSliderDelegate : NSObjectProtocol {
    func timeRangeDidChanged(timeRange : CMTimeRange)
    func timeRangeDidConfirm(timeRange : CMTimeRange)
}

class LYVideoRangeSlider: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    /** delegate */
    weak var delegate : LVVideoRangeSliderDelegate?
    /** min value for clip duration */
    var minClipDuration : Float64 = -1
    /** max value for clip duration */
    var maxClipDuration : Float64 = -1
    /** min clip Width */
    private var _minClipWidth : CGFloat = -1
    /** max clip Width */
    private var _maxClipWidth : CGFloat = -1
    // MARK: proerty for asset
    private var _videoAsset : AVAsset?
    private var _videoDuration : Float64 = -1
    /** time range */
    private var timeRange : CMTimeRange = kCMTimeRangeInvalid
    
    // MARK: property for collectionView
    private var _collectionView : UICollectionView?
    private var _normallCellSize : CGSize = CGSizeZero
    private var _lastCellSize : CGSize = CGSizeZero
    
    private var _imageGenerator : AVAssetImageGenerator?
    private var _images : [UIImage] = [UIImage]()
    private var _imageCount : Int = 0
    
    private var _leftCover : UIView?
    private var _leftSlider : UIView?
    private var _rightCover : UIView?
    private var _rightSlider : UIView?
    private var _rangeView : UIView?
    private var _leftPanStartPoint : CGPoint = CGPointZero
    private var _rightPanStartPoint : CGPoint = CGPointZero
    private var _rangePanStartPoint : CGPoint = CGPointZero
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        _commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    deinit {
        // stop image generation when deinit
        if _imageGenerator != nil {
            _imageGenerator!.cancelAllCGImageGeneration()
        }
    }
    
    // MARK: public methods
    func setupVideoAsset(videoAsset : AVAsset) {
        if videoAsset.hasVideoTrack() {
            let track = videoAsset.aVideoTrack()
            let timeRange = track!.timeRange
            setupVideoAsset(videoAsset, timeRange: timeRange, minClipDuration : -1, maxClipDuration: -1)
        }
    }
    
    func reset() {
        timeRange = kCMTimeRangeInvalid
        _imageCount = 0
        _images.removeAll()
        
        maxClipDuration = -1
        _maxClipWidth = -1
        minClipDuration = -1
        _minClipWidth = -1
    }
    
    
    func setupVideoAsset(videoAsset : AVAsset, timeRange : CMTimeRange, minClipDuration : Float64, maxClipDuration : Float64) {
        if (_videoAsset == nil) || (_videoAsset != nil && !_videoAsset!.isEqual(videoAsset)) {
            reset()
            _videoAsset = videoAsset
            _videoDuration = CMTimeGetSeconds(videoAsset.timeRange.duration)
            
            // adjust timeRange
            if (minClipDuration > 0 || maxClipDuration > 0) && minClipDuration < maxClipDuration {
                self.minClipDuration = minClipDuration
                self.maxClipDuration = maxClipDuration
                
                var duration = CMTimeGetSeconds(timeRange.duration)
                let widthPerSeconds = self.frame.size.width / CGFloat(_videoDuration)
                
                if self.maxClipDuration > 0 && duration > self.maxClipDuration {
                    duration = self.maxClipDuration
                    _maxClipWidth = CGFloat(self.maxClipDuration) * widthPerSeconds
                }
                
                if self.minClipDuration > 0 && duration > self.minClipDuration {
                    duration = self.minClipDuration
                    _minClipWidth = CGFloat(self.minClipDuration) * widthPerSeconds
                }
                
                self.timeRange = CMTimeRangeMake(timeRange.start, CMTimeMakeWithSeconds(duration, timeRange.duration.timescale))
            } else {
                self.timeRange = timeRange
            }
            
            _setupSlider()
        }
    }
    
    override func awakeFromNib() {
        _commonInit()
    }
    
    override func layoutSubviews() {
        if _collectionView != nil && !CGRectEqualToRect(_collectionView!.frame, self.bounds) {
            // do frame setting
            _collectionView!.frame = self.bounds
            _changeRangeView()
            _adjustStartAndLength()
        }
    }
    
    //MARK: UICollectionViewDataSource
    internal func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return _imageCount
    }
    
    internal func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("Cell", forIndexPath: indexPath) as! _LYVideoCell
        return cell
    }
    
    //MARK: UICollectionViewDelegateFlowLayout
    internal func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAtIndex section: Int) -> CGFloat {
        return 0
    }
    
    internal func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAtIndex section: Int) -> CGFloat {
        return 0
    }
    
    internal func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        if _imageCount > 0 {
            if indexPath.row >= 0 && indexPath.row < _imageCount - 1 {
                return _normallCellSize
            } else {
                return _lastCellSize
            }
        }
        return CGSizeZero
    }
    
    // MARK: private methods
    private func _commonInit() {
        let collectionViewLayout = UICollectionViewFlowLayout()
        collectionViewLayout.minimumInteritemSpacing = 0
        collectionViewLayout.minimumLineSpacing = 0
        collectionViewLayout.scrollDirection = .Horizontal
        
        _collectionView = UICollectionView(frame: self.bounds, collectionViewLayout: collectionViewLayout)
        _collectionView!.dataSource = self
        _collectionView!.delegate = self
        _collectionView!.registerClass(_LYVideoCell.self, forCellWithReuseIdentifier: "Cell")
        
        // add initial for these views
        _leftCover = UIView(frame: CGRectMake(0, 0, 0, self.bounds.size.height))
        _leftSlider = UIView(frame: CGRectMake(0, 0, 10, self.bounds.size.height))
        _rangeView = UIView(frame: CGRectMake(0, 0, self.bounds.size.width - 10, self.bounds.size.height))
        _rightSlider = UIView(frame: CGRectMake(self.bounds.size.width - 10, 0, 10, self.bounds.size.height))
        _rightCover = UIView(frame: CGRectMake(self.bounds.size.width, 0, 0, self.bounds.size.height))
        //
        _leftCover!.hidden = true
        _leftSlider!.hidden = true
        _rangeView!.hidden = true
        _rightSlider!.hidden = true
        _rightCover!.hidden = true
        
        _leftSlider!.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: "_leftSliderMoved:"))
        _leftSlider!.userInteractionEnabled = true
        
        _rightSlider!.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: "_rightSliderMoved:"))
        _rightSlider!.userInteractionEnabled = true
        
        _rangeView!.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: "_rangeViewMoved:"))
        _rangeView!.userInteractionEnabled = true
        
        _leftSlider!.backgroundColor = UIColor(red: 0xaa, green: 0xaa, blue: 0xaa, alpha: 0.8)
        _rightSlider!.backgroundColor = UIColor(red: 0xaa, green: 0xaa, blue: 0xaa, alpha: 0.8)
        _rangeView!.backgroundColor = UIColor(red: 0xff, green: 0xff, blue: 0xff, alpha: 0.5)
        _leftCover!.backgroundColor = UIColor(red: 0x00, green: 0x00, blue: 0x00, alpha: 0.5)
        _rightCover!.backgroundColor = UIColor(red: 0x00, green: 0x00, blue: 0x00, alpha: 0.5)
        
        // add collection view first
        self.addSubview(_collectionView!)
        // then rangeView
        self.addSubview(_rangeView!)
        //
        self.addSubview(_leftSlider!)
        self.addSubview(_rightSlider!)
        self.addSubview(_leftCover!)
        self.addSubview(_rightCover!)
    }
    
    private func _setupSlider() {
        if let asset = _videoAsset {
            if !asset.hasVideoTrack() {
                // NO video track
                return
            }
            if let videoTrack = asset.aVideoTrack() {
                _changeRangeView()
                _adjustStartAndLength()
                _changeViewsVisibility(false)
                
                let preferredSize = videoTrack.videoSize
                let thumbnailSize = CGSizeMake(preferredSize.width * (self.bounds.size.height / preferredSize.height), self.bounds.size.height)
                
                let imageCount = Int(ceil(self.bounds.size.width / thumbnailSize.width))
                precondition(imageCount >= 0)
                
                _imageCount = imageCount
                _normallCellSize = thumbnailSize
                _lastCellSize = CGSizeMake(self.bounds.size.width - CGFloat(imageCount - 1) * thumbnailSize.width, self.bounds.size.height);
                _collectionView!.reloadData()
                //
                
                let imageGenerator = AVAssetImageGenerator(asset: asset)
                imageGenerator.maximumSize = thumbnailSize
                imageGenerator.appliesPreferredTrackTransform = true
                
                var requestedTimes = [NSValue]()
                var time = videoTrack.timeRange.start
                let duration = CMTimeGetSeconds(videoTrack.timeRange.duration)
                let clipTime = CMTimeMakeWithSeconds(duration / Float64(imageCount), videoTrack.naturalTimeScale)
                for _ in 0 ..< imageCount {
                    requestedTimes.append(NSValue(CMTime : time))
                    time = CMTimeAdd(time, clipTime)
                }
                
                imageGenerator.generateCGImagesAsynchronouslyForTimes(requestedTimes, completionHandler: { (requestedTime, cgimage, actucalTime, result, error) -> Void in
                    
                    if cgimage != nil {
                        let image = UIImage(CGImage: cgimage!)
                        dispatch_async(dispatch_get_main_queue(), {() -> Void in
                            if let index = requestedTimes.indexOf(NSValue(CMTime : requestedTime)) {
                                //print("index->\(index) -- \(requestedTime)\n")
                                let indexPath = NSIndexPath(forRow: index, inSection: 0)
                                if let cell = self._collectionView!.cellForItemAtIndexPath(indexPath) {
                                    let c = cell as! _LYVideoCell
                                    c.imageView?.image = image
                                }
                            }
                        })
                    }
                })
            }
        }
    }
    private func _changeRangeView() {
        if _videoDuration > 0 {
            let startSeconds = CMTimeGetSeconds(timeRange.start)
            let duration = CMTimeGetSeconds(timeRange.duration)
            let widthPerSecond = self.bounds.size.width / CGFloat(_videoDuration)
            
            let startX = CGFloat(startSeconds) * widthPerSecond
            let durationWidth = CGFloat(duration) * widthPerSecond
            
            _rangeView!.frame = CGRectMake(startX, 0, durationWidth, self.bounds.size.height)
        }
    }
    
    private func _changeViewsVisibility(hidden : Bool) {
        _leftCover!.hidden = hidden
        _leftSlider!.hidden = hidden
        _rangeView!.hidden = hidden
        _rightSlider!.hidden = hidden
        _rightCover!.hidden = hidden
    }
    
    private func _adjustStartAndLength() {
        let rangeViewFrame = _rangeView!.frame
        let x = rangeViewFrame.origin.x
        let width = rangeViewFrame.size.width
        
        let startTime = CMTimeMakeWithSeconds(Float64(x / self.frame.size.width) * _videoDuration, 600)
        let durationTime = CMTimeMakeWithSeconds(Float64(width / self.frame.size.width) * _videoDuration, 600)
        
        timeRange = CMTimeRangeMake(startTime, durationTime)
        
        _leftSlider!.frame = CGRectMake(rangeViewFrame.origin.x, 0, _leftSlider!.frame.size.width, _leftSlider!.frame.size.height)
        _rightSlider!.frame = CGRectMake(rangeViewFrame.origin.x + rangeViewFrame.size.width - _rightSlider!.frame.size.width, 0, _rightSlider!.frame.size.width, _rightSlider!.frame.size.height)
        _leftCover!.frame = CGRectMake(0, 0, _leftSlider!.frame.origin.x, self.frame.size.height)
        _rightCover!.frame = CGRectMake(rangeViewFrame.origin.x + rangeViewFrame.size.width, 0, self.frame.size.width - (rangeViewFrame.origin.x + rangeViewFrame.size.width), self.frame.size.height)
    }
    
    private func _notiRangeChanged() {
        if delegate != nil && delegate!.respondsToSelector("timeRangeDidChanged:") {
            delegate!.timeRangeDidChanged(timeRange)
        }
    }
    
    private func _notiRangeConfirm() {
        if delegate != nil && delegate!.respondsToSelector("timeRangeDidConfirm:") {
            delegate!.timeRangeDidConfirm(timeRange)
        }
    }
    
    func _leftSliderMoved(pan : UIPanGestureRecognizer) {
        switch(pan.state) {
        case .Began:
            _leftPanStartPoint = pan.locationInView(self)
            break
        case .Changed:
            let curr = pan.locationInView(self)
            let offsetX = curr.x - _leftPanStartPoint.x
            _leftPanStartPoint = curr
            
            var newX = _rangeView!.frame.origin.x + offsetX
            
            if newX < 0 {
                newX = 0
            }
            
            var newWidth = _rangeView!.frame.origin.x + _rangeView!.frame.size.width - newX
            if _maxClipWidth > 0 && _maxClipWidth > _minClipWidth {
                if newWidth > _maxClipWidth {
                    newWidth = _maxClipWidth
                }
            }
            
            let minWidth = max(_minClipWidth, _leftSlider!.bounds.size.width + _rightSlider!.bounds.size.width)
            
            if newWidth < minWidth {
                newWidth = minWidth
            }
            
            if newX + newWidth > self.frame.size.width {
                newWidth = self.frame.size.width - newX
                if newWidth < minWidth {
                    newWidth = minWidth
                    newX = self.frame.size.width - newWidth
                }
            }
           
            
            _rangeView!.frame = CGRectMake(newX, 0, newWidth, _rangeView!.frame.size.height)
            _adjustStartAndLength()
            _notiRangeChanged()
            break
        case .Ended, .Cancelled, .Failed:
            _leftPanStartPoint = CGPointZero
            _notiRangeConfirm()
            break
        default:
            break
        }
    }
    
    func _rightSliderMoved(pan: UIPanGestureRecognizer) {
        switch(pan.state) {
        case .Began:
            _rightPanStartPoint = pan.locationInView(self)
            break
        case .Changed:
            let curr = pan.locationInView(self)
            var offsetX = curr.x - _rightPanStartPoint.x
            _rightPanStartPoint = curr
            
            var right = _rangeView!.frame.origin.x + _rangeView!.frame.size.width + offsetX
            
            if right > self.frame.size.width {
                offsetX -= (right - self.frame.size.width)
                right = self.frame.size.width
            }
            
            var width = _rangeView!.frame.size.width + offsetX
            if width > _maxClipWidth {
                width = _maxClipWidth
            }
            
            let minWidth = max(_minClipWidth, _leftSlider!.bounds.size.width + _rightSlider!.bounds.size.width)
            
            if width < minWidth {
                width = minWidth
            }
            
            var newX = right - width
            if newX < 0 {
                newX = 0
                right = width
            }
            
            _rangeView!.frame = CGRectMake(newX, _rangeView!.frame.origin.y, width, _rangeView!.frame.size.height)
            _adjustStartAndLength()
            _notiRangeChanged()
            break
        case .Ended, .Cancelled, .Failed:
            _rightPanStartPoint = CGPointZero
            _notiRangeConfirm()
            break
        default:
            break
        }
    }
    
    func _rangeViewMoved(pan : UIPanGestureRecognizer) {
        switch(pan.state) {
        case .Began:
            _rangePanStartPoint = pan.locationInView(self)
            break
        case .Changed:
            let curr = pan.locationInView(self)
            let offsetX = curr.x - _rangePanStartPoint.x
            _rangePanStartPoint = curr
            _rangeView!.center = CGPointMake(_rangeView!.center.x + offsetX, _rangeView!.center.y)
            if _rangeView!.frame.origin.x < 0 {
                _rangeView!.frame = CGRectMake(0, 0, _rangeView!.frame.size.width, _rangeView!.frame.size.height)
            }
            
            if _rangeView!.frame.origin.x + _rangeView!.frame.size.width > self.frame.size.width {
                _rangeView!.frame = CGRectMake(self.frame.size.width - _rangeView!.frame.size.width, 0, _rangeView!.frame.size.width, _rangeView!.frame.size.height)
            }
            
            _adjustStartAndLength()
            _notiRangeChanged()
            break
        case .Ended, .Cancelled, .Failed:
            _rangePanStartPoint = CGPointZero
            _notiRangeConfirm()
            break
        default:
            break
        }
    }
}

//
private class _LYVideoCell : UICollectionViewCell {
    var imageView : UIImageView?
    private func _initCommont() {
        if imageView == nil {
            imageView = UIImageView(frame: self.contentView.bounds)
            // make the image align with imageView's left side
            imageView!.contentMode = .Left
            self.contentView.addSubview(imageView!)
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        _initCommont()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func awakeFromNib() {
        _initCommont()
    }
}
