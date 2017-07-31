//
//  PURBufferedOutput.swift
//  Pods
//
//  Created by admin on 7/27/17.
//
//

import Foundation

private enum Constants {
    static let PURBufferedOutputSettingsLogLimitKey: String = "BufferedOutputLogLimit"
    static let PURBufferedOutputSettingsFlushIntervalKey: String = "BufferedOutputFlushInterval"
    static let PURBufferedOutputSettingsMaxRetryCountKey: String = "BufferedOutputMaxRetryCount"
    
    static let PURBufferedOutputDidStartNotification = NSNotification.Name("PURBufferedOutputDidStartNotification")
    static let PURBufferedOutputDidResumeNotification = NSNotification.Name("PURBufferedOutputDidResumeNotification")
    static let PURBufferedOutputDidFlushNotification = NSNotification.Name("PURBufferedOutputDidFlushNotification")
    static let PURBufferedOutputDidTryWriteChunkNotification = NSNotification.Name("PURBufferedOutputDidTryWriteChunkNotification")
    static let PURBufferedOutputDidSuccessWriteChunkNotification = NSNotification.Name("PURBufferedOutputDidSuccessWriteChunkNotification")
    static let PURBufferedOutputDidRetryWriteChunkNotification = NSNotification.Name("PURBufferedOutputDidRetryWriteChunkNotification")
    
    static let PURBufferedOutputDefaultLogLimit: Int = 5
    static let PURBufferedOutputDefaultFlushInterval: TimeInterval = 10
    static let PURBufferedOutputDefaultMaxRetryCount: Int = 3
}

class PURBufferedOutputChunk {
    private(set) var logs = [PURLog]()
    var retryCount: Int = 0
    
    init(logs: [PURLog]) {
        self.logs = logs
    }
}

class PURBufferedOutput: PUROutput {
    private(set) var buffer = [PURLog]()
    private(set) var logLimit: Int = 0
    private(set) var flushInterval = TimeInterval()
    private(set) var maxRetryCount: Int = 0
    private(set) var recentFlushTime = CFAbsoluteTime()
    private(set) var timer: Timer?
    
    deinit {
        timer?.invalidate()
    }
    
    func setUpTimer() {
        timer?.invalidate()
        timer = Timer(timeInterval: 1.0, target: self, selector: #selector(self.tick), userInfo: nil, repeats: true)
        RunLoop.current.add(timer!, forMode: RunLoopMode.commonModes)
    }
    
    override func configure(_ settings: [String: Any]) {
        super.configure(settings)
        var value: Any?
        
        value = settings[Constants.PURBufferedOutputSettingsLogLimitKey]
        if let value = value as? Bool {
            logLimit = value ? 1 : Constants.PURBufferedOutputDefaultLogLimit
        }
        
        value = settings[Constants.PURBufferedOutputSettingsFlushIntervalKey]
        if let value = value as? Bool {
            flushInterval = value ? 1 : Constants.PURBufferedOutputDefaultFlushInterval
        }
        
        value = settings[Constants.PURBufferedOutputSettingsFlushIntervalKey]
        if let value = value as? Bool {
            flushInterval = value ? 1 : Constants.PURBufferedOutputDefaultFlushInterval
        }
        
        value = settings[Constants.PURBufferedOutputSettingsMaxRetryCountKey]
        if let value = value as? Bool {
            maxRetryCount = value ? 1 : Constants.PURBufferedOutputDefaultMaxRetryCount
        }
        
        buffer = [PURLog]()
    }
    
    override func start() {
        super.start()
        buffer.removeAll()
        
        retrieveLogs({(_ logs: [PURLog]) -> Void in
            NotificationCenter.default.post(name: Constants.PURBufferedOutputDidStartNotification, object: self)
            
            if let timer = self.timer, timer.isValid == false {
                return
            }
            
            self.buffer += logs
            self.flush()
        })
        
        setUpTimer()
    }
    
    override func resume() {
        super.resume()
        buffer.removeAll()
        
        retrieveLogs({(_ logs: [PURLog]) -> Void in
            NotificationCenter.default.post(name: Constants.PURBufferedOutputDidResumeNotification, object: self)
            
            if let timer = self.timer, timer.isValid == false {
                return
            }
            
            self.buffer += logs
            self.flush()
        })
        
        setUpTimer()
    }
    
    override func suspend() {
        if let timer = timer {
            timer.invalidate()
        }
        
        super.suspend()
    }
    
    @objc func tick() {
        if (CFAbsoluteTimeGetCurrent() - recentFlushTime) > flushInterval {
            flush()
        }
    }
    
    func retrieveLogs(_ completion: @escaping PURLogStoreRetrieveCompletionBlock) {
        buffer.removeAll()
        logStore?.retrieveLogs(for: self, completion: completion)
    }
    
    override func emitLog(_ log: PURLog) {
        buffer.append(log)
        logStore?.add(log, for: self, completion: {() -> Void in
            if self.buffer.count >= self.logLimit {
                self.flush()
            }
        })
    }
    
    func flush() {
        recentFlushTime = CFAbsoluteTimeGetCurrent()
        
        if buffer.count == 0 {
            return
        }
        
        let logCount: Int = min(buffer.count, logLimit)
        
        let flushLogs = Array(buffer[0...logCount])
        let chunk = PURBufferedOutputChunk(logs: flushLogs)
        self.callWrite(chunk)
        
        buffer.removeSubrange(0...logCount)
        
        NotificationCenter.default.post(name: Constants.PURBufferedOutputDidFlushNotification, object: self)
    }
    
    func callWrite(_ chunk: PURBufferedOutputChunk) {
        self.write(chunk) { (success) in
            NotificationCenter.default.post(name: Constants.PURBufferedOutputDidTryWriteChunkNotification, object: self)
            
            if success {
                logStore?.removeLogs(chunk.logs, for: self, completion: nil)
                
                NotificationCenter.default.post(name: Constants.PURBufferedOutputDidSuccessWriteChunkNotification, object: self)
                
                return
            }
            
            chunk.retryCount += 1
            
            if chunk.retryCount <= self.maxRetryCount {
                let delay = 2.0 * pow(2, chunk.retryCount - 1) as? NSDecimalNumber
                let deadline = DispatchTime.now() + (Double(Int(delay!)) * Double(NSEC_PER_SEC))
                
                DispatchQueue.main.asyncAfter(deadline: deadline,
                                              execute: {
                                                NotificationCenter.default.post(name: Constants.PURBufferedOutputDidRetryWriteChunkNotification, object: self)
                                                
                                                self.callWrite(chunk)
                })
                
            }
            
        }
    }
    
    func write(_ chunk: PURBufferedOutputChunk, completion: (_: Bool) -> Void) {
        completion(true)
    }
}
