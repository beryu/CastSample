//
//  DataSourceService.swift
//  CastSample
//
//  Created by Ryuta Kibe on 2016/01/26.
//

import UIKit

class DataSourceService: NSObject {
    
    // MARK: - Internal properties
    
    static let sharedService = DataSourceService()

    // MARK: - Private properties
    
    private let jsonURLString = "https://itunes.apple.com/jp/rss/topsongs/limit=20/json"
    
    func load(completion completion: (([EntityTrack]?) -> Void)?) {
        // Request JSON
        guard let jsonURL = NSURL(string: self.jsonURLString) else {
            return
        }
        let request = NSMutableURLRequest(URL: jsonURL)
        request.HTTPMethod = "GET"
        let task = NSURLSession.sharedSession().dataTaskWithRequest(request, completionHandler: { (data: NSData?, response: NSURLResponse?, error: NSError?) -> Void in
            guard let data = data where error == nil else {
                completion?(nil)
                return
            }
            
            do {
                let json = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
                
                guard
                    let feed = json["feed"] as? [String: AnyObject],
                    let results = feed["entry"] as? [[String: AnyObject]] else {
                        return
                }
                var tracks = [EntityTrack]()
                for result in results {
                    let track = EntityTrack()
                    
                    // Id
                    if
                        let idDict = result["id"] as? [String: AnyObject],
                        let attributesDict = idDict["attributes"] as? [String: String],
                        let id = attributesDict["im:id"] {
                            track.id = id
                    }
                    
                    // Track name
                    if
                        let trackDict = result["im:name"] as? [String: String],
                        let trackName = trackDict["label"] {
                            track.trackName = trackName
                    }
                    
                    // Artist name
                    if
                        let artistDict = result["im:artist"] as? [String: AnyObject],
                        let artistName = artistDict["label"] as? String {
                            track.artistName = artistName
                    }
                    
                    // Album name
                    if
                        let albumDict = result["im:collection"] as? [String: AnyObject],
                        let nameDict = albumDict["im:name"] as? [String: String],
                        let albumName = nameDict["label"] {
                            track.albumName = albumName
                    }
                    
                    // Image
                    if let images = result["im:image"] as? [[String: AnyObject]] {
                        var imageURLString = ""
                        var maxHeight = 0
                        for image in images {
                            if
                                let attributeDict = image["attributes"] as? [String: String],
                                let path = image["label"] as? String,
                                let heightStr = attributeDict["height"],
                                let height = Int(heightStr) where height > maxHeight {
                                    maxHeight = height
                                    imageURLString = path
                            }
                        }
                        track.imageURLString = imageURLString
                        track.imageHeight = maxHeight
                    }
                    
                    if let links = result["link"] as? [[String: AnyObject]] {
                        for linkDict in links {
                            // Duration
                            if
                                let durationDict = linkDict["im:duration"] as? [String: String],
                                let durationString = durationDict["label"],
                                let duration = Int(durationString) {
                                    track.durationInSeconds = Double(duration) / 1000 // Convert to seconds from milliseconds
                            }
                            
                            if let attributeDict = linkDict["attributes"] as? [String: String] where attributeDict["im:assetType"] != nil {
                                // Type
                                if let type = attributeDict["type"] {
                                    track.type = type
                                }
                                
                                // Preview URL
                                if let href = attributeDict["href"] {
                                    track.previewURLString = href
                                }
                            }
                        }
                    }
                    
                    tracks.append(track)
                }
                completion?(tracks)
            } catch {
                print("error serializing JSON: \(error)")
            }
        })
        task.resume()
    }
}
