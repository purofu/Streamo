//
//  ContentView.swift
//  Streamo
//
//  Created by Kostja Paschalidis on 29/05/2023.
//

import SwiftUI
import CoreData
import SwiftUI
import AVFoundation
import MediaPlayer
import Combine
import AVKit
import ShazamKit

struct ContentView: View {
    @StateObject private var player = AudioPlayer()
    @State private var isPlaying = false
    @State private var volume: Float = 0.5
    @State private var frameNumber = 1
    let timer = Timer.publish(every: 1/24, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack {
            Spacer()
            Text(player.currentSong)
                .font(.title)
                .padding()
            Image("frame\(frameNumber)")
                .resizable()
                .scaledToFit()
                .frame(width: 400, height: 400)
                .onReceive(timer) { _ in
                    if isPlaying {
                        frameNumber = frameNumber % 47 + 1
                    }
                }
                .onTapGesture {
                    if isPlaying {
                        player.stop()
                    } else {
                        player.play()
                    }
                    isPlaying.toggle()
                }
            Spacer()
            HStack {
                AirPlayRoutePicker(player: $player.player).frame(width: 40, height: 40)
                Spacer()
            }
            .padding()
        }
        .onAppear {
            player.requestRecordingPermission()
        }
    }
}

class AudioPlayer: NSObject, ObservableObject, SHSessionDelegate {
    var player: AVPlayer
    private var cancellables: Set<AnyCancellable> = []

    private var shazamSession: SHSession?
    private var currentMatchedMediaItem: SHMatchedMediaItem?
    @Published var currentSong: String = "Unknown song"

    override init() {
        let url = URL(string: "http://192.168.1.116:8000/rapi.mp3")!
        player = AVPlayer(url: url)
        
        super.init()
        
        setupShazam()
    }

    func requestRecordingPermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            if granted {
                print("Recording permission granted")
            } else {
                print("Recording permission denied")
            }
        }
    }

    func play() {
        player.play()
        startShazamRecognition()
        print("Playing and started Shazam recognition")
        print("AVPlayer status: \(player.status.rawValue)")
        print("AVPlayer item status: \(player.currentItem?.status.rawValue ?? -1)")
    }

    func stop() {
        player.pause()
        stopShazamRecognition()
        print("Stopped playing and Shazam recognition")
    }

    private func setupShazam() {
        shazamSession = SHSession()
        shazamSession?.delegate = self
    }

    private func startShazamRecognition() {
        guard let shazamSession = shazamSession else {
            print("Shazam session is not set up properly.")
            return
        }

        let audioEngine = AVAudioEngine()
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.inputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            print("Processing audio buffer")
            shazamSession.matchStreamingBuffer(buffer, at: nil)
        }

        do {
            try audioEngine.start()
            print("Audio engine started successfully.")
        } catch {
            print("Failed to start audio engine: \(error.localizedDescription)")
        }
    }

    private func stopShazamRecognition() {
        guard let audioEngine = player.currentItem?.asset as? AVAudioEngine else { return }

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
    }

    func session(_ session: SHSession, didFind match: SHMatch) {
        guard let matchedMediaItem = match.mediaItems.first else { return }

        if matchedMediaItem != currentMatchedMediaItem {
            currentMatchedMediaItem = matchedMediaItem

            currentSong = "\(matchedMediaItem.title ?? "Unknown title") by \(matchedMediaItem.artist ?? "Unknown artist")"
        }
    }

    func session(_ session: SHSession, didNotFindMatchFor signature: SHSignature, error: Error?) {
        print("Did not find match for signature: \(error?.localizedDescription ?? "No error")")

        if currentMatchedMediaItem != nil {
            currentMatchedMediaItem = nil
            currentSong = "Unknown song"
        }
    }

    func session(_ session: SHSession, didFailWithError error: Error) {
        print("Shazam session failed with error: \(error.localizedDescription)")
        
        // Handle the failure accordingly
    }
    
}

struct AirPlayRoutePicker: UIViewRepresentable {
    @Binding var player: AVPlayer

    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.activeTintColor = .darkGray
        picker.tintColor = .blue
        return picker
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        // No need to assign player to uiView.player
    }
}
