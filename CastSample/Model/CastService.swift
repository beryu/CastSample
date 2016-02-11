//
//  CastService.swift
//  CastSample
//
//  Created by Ryuta Kibe on 2016/01/26.
//  Copyright © 2016年 blk. All rights reserved.
//

class CastService: NSObject {
    
    // MARK: - Internal properties
    
    static let sharedService = CastService()
    var deviceScanner: GCKDeviceScanner?
    var connectedBlock: (() -> Void)?
    var deviceManager: GCKDeviceManager?
    let mediaControlChannel: GCKMediaControlChannel = GCKMediaControlChannel()
    
    // MARK: - Private properties
    
    private let receiverAppId: String = "YOUR_RECEIVER_APP_ID"
    
    // MARK: - Internal methods
    
    func scanDevices() {
        self.deviceScanner = GCKDeviceScanner(filterCriteria: GCKFilterCriteria(forAvailableApplicationWithID: self.receiverAppId))
        if let deviceScanner = self.deviceScanner {
            deviceScanner.addListener(self)
            deviceScanner.startScan()
            deviceScanner.passiveScan = true
        }
    }
    
    func connect(device device: GCKDevice, finishedBlock: (() -> Void)?) {
        let deviceManager = GCKDeviceManager(device: device, clientPackageName: NSBundle.mainBundle().bundleIdentifier)
        self.deviceManager = deviceManager
        self.connectedBlock = finishedBlock
        deviceManager.delegate = self
        deviceManager.connect()
    }
    
    func generateMediaInformation(track: EntityTrack) -> GCKMediaInformation {
        let metadata = GCKMediaMetadata()
        metadata.setString(track.trackName, forKey: kGCKMetadataKeyTitle)
        metadata.setString(track.artistName, forKey: kGCKMetadataKeyArtist)
        metadata.setString(track.albumName, forKey: kGCKMetadataKeyAlbumTitle)
        if let url = NSURL(string: track.imageURLString) {
            metadata.addImage(GCKImage(URL: url, width: track.imageHeight, height: track.imageHeight))
        }
        
        return GCKMediaInformation(
            contentID: track.previewURLString,
            streamType: GCKMediaStreamType.Buffered,
            contentType: track.type,
            metadata: metadata,
            streamDuration: track.durationInSeconds,
            customData: nil)
    }
    
    func generateMediaQueueItems(tracks: [EntityTrack]) -> [GCKMediaQueueItem] {
        var mediaQueueItems: [GCKMediaQueueItem] = []
        for track in tracks {
            let queueItemBuilder = GCKMediaQueueItemBuilder()
            queueItemBuilder.startTime = 0
            queueItemBuilder.autoplay = true
            queueItemBuilder.preloadTime = 20
            queueItemBuilder.mediaInformation = self.generateMediaInformation(track)
            mediaQueueItems.append(queueItemBuilder.build())
        }
        
        return mediaQueueItems
    }
    
    func load(information information: GCKMediaInformation) {
        self.deviceManager?.removeChannel(self.mediaControlChannel)
        self.deviceManager?.addChannel(self.mediaControlChannel)
        self.mediaControlChannel.loadMedia(information)
    }
    
    func load(items items: [GCKMediaQueueItem], startIndex: UInt) {
        self.deviceManager?.removeChannel(self.mediaControlChannel)
        self.deviceManager?.addChannel(self.mediaControlChannel)
        self.mediaControlChannel.queueLoadItems(items, startIndex: startIndex, playPosition: 0, repeatMode: .Off, customData: nil)
    }
}

extension CastService: GCKDeviceScannerListener {
    /**
     * Called when a device has been discovered or has come online.
     */
    func deviceDidComeOnline(device: GCKDevice!) {
        NSLog("GoogleCast receiver is detected!")
    }
    
    /**
     * Called when a device has gone offline.
     */
    func deviceDidGoOffline(device: GCKDevice!) {
        NSLog("GoogleCast has gone offline.")
    }

}

extension CastService: GCKDeviceManagerDelegate {
    /**
     * Called when a connection has been established to the device.
     */
    func deviceManagerDidConnect(deviceManager: GCKDeviceManager!) {
        NSLog("Connected with GoogleCast device.")
        
        self.deviceManager?.launchApplication(self.receiverAppId)
    }
    
    /**
     * Called when an application has been launched or joined.
     */
    func deviceManager(deviceManager: GCKDeviceManager!, didConnectToCastApplication applicationMetadata: GCKApplicationMetadata!, sessionID: String!, launchedApplication: Bool) {
        NSLog("Connected with GoogleCast receiver application.")
        
        self.connectedBlock?()
    }
}
