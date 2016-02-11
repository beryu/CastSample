//
//  ViewController.swift
//  CastSample
//
//  Created by Ryuta Kibe on 2016/01/25.
//

import UIKit

class ViewController: UIViewController {
    
    // MARK: - Private properties
    
    private var tracks: [EntityTrack]?
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var castButton: UIButton!
    
    // for Google Cast
    private var deviceScanner: GCKDeviceScanner?
    private var connectedBlock: (() -> Void)?
    private var deviceManager: GCKDeviceManager?
    private let mediaControlChannel: GCKMediaControlChannel = GCKMediaControlChannel()
    private let receiverAppId: String = "YOUR_RECEIVER_APP_ID"
    
    // MARK: - Override methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        DataSourceService.sharedService.load(completion: { (tracks: [EntityTrack]?) -> Void in
            self.tracks = tracks
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.tableView.reloadData()
            })
        })
        
        self.scanDevices()
    }
    
    // MARK: - Private methods
    
    @IBAction private func castButtonWasTapped() {
        guard let tracks = self.tracks else {
            return
        }
        let connectionState = self.deviceManager?.applicationConnectionState ?? .Disconnected
        if connectionState == .Connected {
            self.disconnect()
        } else {
            self.connect(tracks: tracks, startIndex: 0)
        }
    }
    
    private func connect(tracks tracks: [EntityTrack], startIndex: UInt) {
        if tracks.count == 0 {
            return
        }
        let connectionState = self.deviceManager?.applicationConnectionState ?? .Disconnected
        if connectionState != .Connected {
            // Show device selector
            guard
                let deviceScanner = self.deviceScanner,
                let devices = deviceScanner.devices as? [GCKDevice] else {
                    return
            }
            
            self.castButton.hidden = true
            
            let alertController = UIAlertController(title: nil, message: "Select device to cast", preferredStyle: .ActionSheet)
            deviceScanner.passiveScan = false
            for device in devices {
                alertController.addAction(
                    UIAlertAction(
                        title: device.friendlyName,
                        style: .Default,
                        handler: { (action: UIAlertAction) -> Void in
                            
                            // Connect with device
                            self.connect(device: device, finishedBlock: { [weak self] () -> Void in
                                guard let me = self else {
                                    return
                                }
                                me.load(items: me.generateMediaQueueItems(tracks), startIndex: startIndex)
                            })
                            
                            deviceScanner.passiveScan = true
                            self.castButton.hidden = false
                    }))
            }
            alertController.addAction(
                UIAlertAction(
                    title: "キャンセル",
                    style: .Cancel,
                    handler: { (action: UIAlertAction) -> Void in
                        
                        deviceScanner.passiveScan = true
                        self.castButton.hidden = false
                }))
            presentViewController(alertController, animated: true, completion: nil)
        }
    }
}

// MARK: - UITableViewDataSource

extension ViewController: UITableViewDataSource {
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.tracks?.count ?? 0
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        guard let track = self.tracks?[indexPath.row] else {
            return UITableViewCell()
        }
        
        let cell = self.tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath)
        cell.textLabel?.text = track.trackName
        return cell
    }
}

// MARK: - UITableViewDelegate

extension ViewController: UITableViewDelegate {
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        self.tableView.deselectRowAtIndexPath(indexPath, animated: true)
        guard let tracks = self.tracks else {
            return
        }
        let connectionState = self.deviceManager?.applicationConnectionState ?? .Disconnected
        if connectionState == .Connected {
            self.load(items: self.generateMediaQueueItems(tracks), startIndex: UInt(indexPath.row))
        } else {
            NSLog("Not connected with Receiver")
        }
    }
}

// MARK: - Google Cast
extension ViewController {
    
    // MARK: - Internal methods
    
    func scanDevices() {
        // Receiverデバイスを検索（Receiver App Idによるフィルター有）
        self.deviceScanner = GCKDeviceScanner(filterCriteria: GCKFilterCriteria(forAvailableApplicationWithID: self.receiverAppId))
        
        // 検索開始
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
    
    func disconnect() {
        guard let deviceManager = self.deviceManager else {
            return
        }
        deviceManager.leaveApplication()
        deviceManager.disconnect()
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
        self.deviceManager?.addChannel(self.mediaControlChannel)
        self.mediaControlChannel.loadMedia(information)
    }
    
    func load(items items: [GCKMediaQueueItem], startIndex: UInt) {
        self.deviceManager?.addChannel(self.mediaControlChannel)
        self.mediaControlChannel.queueLoadItems(items, startIndex: startIndex, playPosition: 0, repeatMode: .Off, customData: nil)
    }
}

extension ViewController: GCKDeviceScannerListener {
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

extension ViewController: GCKDeviceManagerDelegate {
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
