//
//  AudioPlayer.swift
//  CBCListen
//
//  Created by Nelson Narciso on 2018-04-23.
//  Copyright © 2018 CBC. All rights reserved.
//

import Foundation
import AVFoundation
import MediaPlayer

class AudioPlayer: NSObject {
    
    static let shared = AudioPlayer()
    
    var player : AVPlayer = AVPlayer() {
        didSet {
            removeObserversForPlayer(oldValue)
            addObserversForPlayer(player)
            player.allowsExternalPlayback = false
        }
    }
    
    var assetDuration: Int? {
        didSet {
            if (assetDuration != nil) {
                notifyPlayerItemSet()
            }
        }
    }
    
    var isPlaying: Bool {
        return playbackState == .playing || playbackState == .buffering
    }
    
    var url: URL? {
        if let urlAsset = player.currentItem?.asset as? AVURLAsset {
            return urlAsset.url
        }
        return nil
    }
    
    override init() {
        super.init()
        addObserversForAudioSession()
        addObserversForPlayer(player)
        player.allowsExternalPlayback = false
    }
    
    deinit {
        if let playerItem = player.currentItem {
            removeObserversForPlayerItem(playerItem)
        }
        removeObserversForPlayer(player)
    }
    
    // Mark: - Commands
    
    func play(url: URL) {
        setPlayerItem(url: url)
        play()
    }
    
    func setPlayerItem(url: URL) {
        let asset = AVAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        setPlayerCurrentItem(playerItem)
    }
    
    func play() {
        activateAudioSession()
        player.play()
    }
    
    func pause() {
        player.pause()
    }
    
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func seek(to: CMTime, completionHandler: @escaping (Bool) -> Void) {
        if #available(iOS 11.0, *) {
            player.seek(to: to, completionHandler: completionHandler)
        } else {
            if player.status == .readyToPlay {
                player.seek(to: to, completionHandler: completionHandler)
            }
        }
    }
    
    func seek(seconds: Double, completionHandler: ((Bool) -> Void)? = nil) {
        let time = CMTime(seconds: seconds, preferredTimescale: 1)
        if let completionHandler = completionHandler {
            player.seek(to: time, completionHandler: completionHandler)
        } else {
            player.seek(to: time)
        }
    }

    var currentPlayerItem: AVPlayerItem? {
        willSet {
            if let oldPlayerItem = currentPlayerItem {
                removeObserversForPlayerItem(oldPlayerItem)
            }
        }
        didSet {
            if let newPlayerItem = currentPlayerItem {
                addObserversForPlayerItem(newPlayerItem)
            }
            player = AVPlayer()
            player.replaceCurrentItem(with: currentPlayerItem)
//            notifyPlayerItemSet()
        }
    }
    
    func setPlayerCurrentItem(_ playerItem: AVPlayerItem?) {
        currentPlayerItem = playerItem
        assetDuration = nil
    }
    
    
    // MARK - Initialization
    
    func activateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do{
            if #available(iOS 11.0, *) {
                try session.setCategory(.playback, mode: .default, policy: .longFormAudio , options: [])
            } else {
                try session.setCategory(.playback, mode: .default, options: [])
            }
            try session.setActive(true)
        } catch let error as NSError {
            print("Encountered error: \(error.localizedDescription)")
            playbackState = .failed
        }
    }
    
    var playbackState: PlaybackState = .unknown {
        didSet {
            guard playbackState != oldValue else { return }
            notifyPlaybackStateChanged(playbackState: playbackState)
            print("\(Date())Playbackstate AudioPlayer : \(playbackState)")
        }
    }
    
    func checkState() {
        //print("AudioPlayer checkState player.timeControlStatus: \(player.timeControlStatus.rawValue)")
        switch player.timeControlStatus {
        case .playing:
            playbackState = .playing
        case .paused:
            playbackState = .paused
        case .waitingToPlayAtSpecifiedRate:
            playbackState = .buffering
        @unknown default:
            return
        }
    }
    
    // MARK: - Clean up
    func endAudioUnusedAudioSession() {
        guard !isPlaying else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false)
    }
    
    
    // MARK: - External Observers
    
    // MARK: PlaybackObservers
    
    private var playbackObservers = [PlaybackObserver]()
    
    func addPlaybackObserver(observer: PlaybackObserver) {
        playbackObservers.append(observer)
    }
    
    func removePlaybackObserver(observer: PlaybackObserver) {
        if let index = playbackObservers.firstIndex(where: { $0 === observer }) {
            playbackObservers.remove(at: index)
        }
    }
    
    func notifyPlaybackStateChanged(playbackState: PlaybackState) {
        playbackObservers.forEach { $0.playbackStateChanged(state: playbackState)}
    }
    
    func notifyPlayerItemSet() {
        playbackObservers.forEach { $0.playerItemSet() }
    }
    
    //MARK: PeriodicTimeObservers
    
    private var periodicTimeObservers = [PeriodicTimeObserver]()
    
    func addPeriodicTimeObserver(observer: PeriodicTimeObserver) {
        periodicTimeObservers.append(observer)
    }
    
    func removePeriodicTimeObserver(observer: PeriodicTimeObserver) {
        if let index = periodicTimeObservers.firstIndex(where: { $0 === observer }) {
            periodicTimeObservers.remove(at: index)
        }
    }
    
    func notifiyPeriodicTimeObservers(time: CMTime) {
        periodicTimeObservers.forEach { $0.update(time: time) }
    }
    
    
    // MARK: - Internal Observers
    
    fileprivate var avPlayerTimeControlObserverContext = 0
    fileprivate var avPlayerItemObserverContext = 0
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        //logDebug("keyPath: \(keyPath ?? "nil") object: \(object ?? "nil") value: \(change?[NSKeyValueChangeKey.newKey] ?? "nil")")
        if context == &avPlayerTimeControlObserverContext {
            checkState()
        }
        
        if keyPath == #keyPath(AVPlayerItem.status), let statusNumber = change?[.newKey] as? NSNumber {
            switch statusNumber.intValue {
            case AVPlayerItem.Status.readyToPlay.rawValue:
                
                if let dur = currentPlayerItem?.asset.duration {
                    if dur.isIndefinite {
                        print("Ready to play. Indefinite. Live stream")
                        notifyPlayerItemSet()
                    } else {
                        print("Ready to play. Duration (in seconds): \(dur.seconds)")
                        assetDuration = Int(dur.seconds)
                    }
                }
            default: break
            }
        }
    }
    
    // MARK: Player Observers
    
    fileprivate var timeObserverToken: Any?
    
    func addObserversForPlayer(_ player: AVPlayer) {
        player.addObserver(self, forKeyPath: "timeControlStatus", options: .new, context: &avPlayerTimeControlObserverContext)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 1), queue: nil, using: { [weak self] (time) in
            self?.notifiyPeriodicTimeObservers(time: time) //using weak reference to avoid a retain cycle as per the documentation
        })
    }
    
    func removeObserversForPlayer(_ player:AVPlayer) {
        player.removeObserver(self, forKeyPath: "timeControlStatus", context: &avPlayerTimeControlObserverContext)
        if let timeObserverToken = timeObserverToken {
            player.removeTimeObserver(timeObserverToken)
        }
    }
    
    // MARK: Player Item Observers
    
    func addObserversForPlayerItem(_ playerItem: AVPlayerItem) {
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: playerItem, queue: OperationQueue.main, using: playerItemDidPlayToEndTime)
        playerItem.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), options: [.new], context: &avPlayerItemObserverContext)
        playerItem.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.playbackBufferEmpty), options: [.new], context: &avPlayerItemObserverContext)
        playerItem.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.playbackLikelyToKeepUp), options: [.new], context: &avPlayerItemObserverContext)
        playerItem.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.playbackBufferFull), options: [.new], context: &avPlayerItemObserverContext)
    }
    
    func removeObserversForPlayerItem(_ playerItem: AVPlayerItem) {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: playerItem)
        playerItem.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status))
        playerItem.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.playbackBufferEmpty))
        playerItem.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.playbackLikelyToKeepUp))
        playerItem.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.playbackBufferFull))
    }
    
    func playerItemDidPlayToEndTime(_ notification: Notification) {
        playbackState = .ended
    }
    
    // Mark: AudioSession Observers
    
    func addObserversForAudioSession() {
        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: OperationQueue.main, using: handleAudioSessionInterruption)
        NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: OperationQueue.main, using: handleAudioSessionRouteChange)
    }
    
    func handleAudioSessionInterruption(notification: Notification) {
        guard let interruptionTypeRaw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt else { return }
        guard let interruptionType = AVAudioSession.InterruptionType(rawValue: interruptionTypeRaw) else { return }
        if interruptionType == .ended {
            guard let interruptionOptionsRaw = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let interruptionOptions = AVAudioSession.InterruptionOptions(rawValue: interruptionOptionsRaw)
            if interruptionOptions.contains(.shouldResume) {
                play()
            }
        }
    }
    
    func handleAudioSessionRouteChange(notification: Notification) {
        guard let routeChangeReasonRaw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt else { return }
        guard let routeChangeReason = AVAudioSession.RouteChangeReason(rawValue: routeChangeReasonRaw) else { return }
        if routeChangeReason == .oldDeviceUnavailable {
            pause()
        }
    }
}


extension Notification.Name {
    static let playerManagerPlayedToEnd = Notification.Name("ca.cbc.cbclisten.PlayerManager.PlayedToEnd")
}

//  PlaybackObserver.swift
enum PlaybackState {
    case unknown
    case buffering
    case ready
    case playing
    case paused
    case ended
    case failed
    case stalled
    case scrubbing
}

protocol PlaybackObserver: AnyObject {
    func playbackStateChanged(state: PlaybackState)
    func playerItemSet()
}

extension PlaybackObserver {
    func playerItemSet() { }
}

//  PeriodicTimeObserver.swift
protocol PeriodicTimeObserver: AnyObject {
    func update(time: CMTime)
}


