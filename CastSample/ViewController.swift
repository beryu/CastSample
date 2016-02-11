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
    
    // MARK: - Override methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        DataSourceService.sharedService.load(completion: { (tracks: [EntityTrack]?) -> Void in
            self.tracks = tracks
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.tableView.reloadData()
            })
        })
        
        CastService.sharedService.scanDevices()
    }
    
    // MARK: - Private methods
    
    @IBAction private func castButtonWasTapped() {
        guard let tracks = self.tracks else {
            return
        }
        self.connect(tracks: tracks, startIndex: 0)
    }
    
    private func connect(tracks tracks: [EntityTrack], startIndex: UInt) {
        if tracks.count == 0 {
            return
        }
        let connectionState = CastService.sharedService.deviceManager?.applicationConnectionState ?? .Disconnected
        if connectionState == .Connected {
            CastService.sharedService.load(items: CastService.sharedService.generateMediaQueueItems(tracks), startIndex: startIndex)
        } else {
            // Show device selector
            guard
                let deviceScanner = CastService.sharedService.deviceScanner,
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
                            CastService.sharedService.connect(device: device, finishedBlock: { () -> Void in
                                CastService.sharedService.load(items: CastService.sharedService.generateMediaQueueItems(tracks), startIndex: startIndex)
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
    @IBAction func castPlayButtonWasTapped(sender: AnyObject) {
        guard let mediaStatus = CastService.sharedService.mediaControlChannel.mediaStatus else {
            return
        }
        if mediaStatus.playerState == .Playing {
            CastService.sharedService.mediaControlChannel.pause()
        } else {
            CastService.sharedService.mediaControlChannel.play()
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
        self.connect(tracks: tracks, startIndex: UInt(indexPath.row))
    }
}