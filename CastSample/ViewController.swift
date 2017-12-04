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
    private var connectedBlock: (() -> Void)?
    private let receiverAppId: String = "4CE4B3B9"
    
    // MARK: - Override methods
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Initialize shared instance of GCKCastContext
        let criteria = GCKDiscoveryCriteria(applicationID: self.receiverAppId)
        let options = GCKCastOptions(discoveryCriteria: criteria)
        GCKCastContext.setSharedInstanceWith(options)
        GCKLogger.sharedInstance().delegate = self
        GCKCastContext.sharedInstance().sessionManager.add(self)

        DataSourceService.sharedService.load(completion: { (tracks: [EntityTrack]?) -> Void in
            self.tracks = tracks
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        })
    }
    
    // MARK: - Private methods
    
    @IBAction private func castButtonWasTapped() {
        guard let tracks = self.tracks else {
            return
        }
        if GCKCastContext.sharedInstance().castState == .connected {
            self.disconnect()
        } else {
            self.connect(tracks: tracks, startIndex: 0)
        }
    }

    private func connect(tracks: [EntityTrack], startIndex: UInt) {
        if tracks.count == 0 {
            return
        }
        if GCKCastContext.sharedInstance().castState != .connected {
            // Show device selector
            let discoveryManager = GCKCastContext.sharedInstance().discoveryManager
            guard discoveryManager.deviceCount > 0 else {
                return
            }
            let devices: [GCKDevice] = stride(from: 0, to: discoveryManager.deviceCount, by: 1).map { discoveryManager.device(at: $0) }

            self.castButton.isHidden = true

            let alertController = UIAlertController(title: nil, message: "Select device to cast", preferredStyle: .actionSheet)
            for device in devices {
                alertController.addAction(
                    UIAlertAction(
                        title: device.friendlyName,
                        style: .default,
                        handler: { (action: UIAlertAction) -> Void in

                            // Connect with device
                            self.connect(device: device, finishedBlock: { [weak self] () -> Void in
                                guard let me = self else {
                                    return
                                }
                                me.load(items: me.generateMediaQueueItems(tracks: tracks), startIndex: startIndex)
                            })

                            self.castButton.isHidden = false
                    }))
            }
            alertController.addAction(
                UIAlertAction(
                    title: "キャンセル",
                    style: .cancel,
                    handler: { (action: UIAlertAction) -> Void in
                        self.castButton.isHidden = false
                }))
            self.present(alertController, animated: true, completion: nil)
        }
    }
}

// MARK: - UITableViewDataSource

extension ViewController: UITableViewDataSource {
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.tracks?.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let track = self.tracks?[indexPath.row] else {
            return UITableViewCell()
        }
        
        let cell = self.tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = track.trackName
        return cell
    }
}

// MARK: - UITableViewDelegate

extension ViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.tableView.deselectRow(at: indexPath, animated: true)
        guard let tracks = self.tracks else {
            return
        }
        if GCKCastContext.sharedInstance().castState == .connected {
            self.load(items: self.generateMediaQueueItems(tracks: tracks), startIndex: UInt(indexPath.row))
        } else {
            NSLog("Not connected with Receiver")
        }
    }
}

// MARK: - Google Cast
extension ViewController {
    
    // MARK: - Internal methods
    
    func connect(device: GCKDevice, finishedBlock: (() -> Void)?) {
        self.connectedBlock = finishedBlock
        GCKCastContext.sharedInstance().sessionManager.startSession(with: device)
    }
    
    func disconnect() {
        GCKCastContext.sharedInstance().sessionManager.endSessionAndStopCasting(true)
    }
    
    func generateMediaInformation(track: EntityTrack) -> GCKMediaInformation {
        let metadata = GCKMediaMetadata(metadataType: .musicTrack)
        metadata.setString(track.trackName, forKey: kGCKMetadataKeyTitle)
        metadata.setString(track.artistName, forKey: kGCKMetadataKeyArtist)
        metadata.setString(track.albumName, forKey: kGCKMetadataKeyAlbumTitle)
        if let url = URL(string: track.imageURLString) {
            metadata.addImage(GCKImage(url: url, width: track.imageHeight, height: track.imageHeight))
        }

        return GCKMediaInformation(contentID: track.previewURLString,
                                   streamType: .buffered,
                                   contentType: track.type,
                                   metadata: metadata,
                                   streamDuration: track.durationInSeconds,
                                   mediaTracks: nil,
                                   textTrackStyle: nil,
                                   customData: nil)
    }

    func generateMediaQueueItems(tracks: [EntityTrack]) -> [GCKMediaQueueItem] {
        var mediaQueueItems: [GCKMediaQueueItem] = []
        for track in tracks {
            let queueItemBuilder = GCKMediaQueueItemBuilder()
            queueItemBuilder.startTime = 0
            queueItemBuilder.autoplay = true
            queueItemBuilder.preloadTime = 20
            queueItemBuilder.mediaInformation = self.generateMediaInformation(track: track)
            mediaQueueItems.append(queueItemBuilder.build())
        }
        
        return mediaQueueItems
    }
    
    func load(items: [GCKMediaQueueItem], startIndex: UInt) {
        guard let castSession = GCKCastContext.sharedInstance().sessionManager.currentCastSession else {
            return
        }
        castSession.remoteMediaClient?.queueLoad(items, start: startIndex, repeatMode: .off)
    }
}

extension ViewController: GCKSessionManagerListener {
    func sessionManager(_ sessionManager: GCKSessionManager, didStart session: GCKSession) {
        self.connectedBlock?()
        self.connectedBlock = nil
    }
}

extension ViewController: GCKLoggerDelegate {
    func logMessage(_ message: String, at level: GCKLoggerLevel, fromFunction function: String, location: String) {
        switch level {
        case .error, .assert:
            NSLog("\(function) \(message)")
        default:
            break
        }
    }
}
