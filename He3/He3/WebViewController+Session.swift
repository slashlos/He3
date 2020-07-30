//
//  WebViewController+Session.swift
//  He3 (Helium 3)
//
//  Created by Carlos D. Santiago on 5/6/20.
//  Copyright © 2020 Carlos D. Santiago. All rights reserved.
//

import Foundation
import WebKit

//  MARK:- URLSessionDelegate
extension WebViewController: URLSessionDelegate {
    @available(OSX 10.9, *)
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        Swift.print(String(format: "SU: %p didBecomeInvalidWithError: %@", session, error?.localizedDescription ?? "?Error"))
        if let error = error {
            NSApp.presentError(error)
        }
    }
    
    @available(OSX 10.9, *)
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        Swift.print(String(format: "SU: %p challenge:", session))

    }
}

//  MARK: URLSessionTaskDelegate
extension WebViewController: URLSessionTaskDelegate {
    @available(OSX 10.13, *)
    func urlSession(_ session: URLSession, task: URLSessionTask, willBeginDelayedRequest request: URLRequest, completionHandler: @escaping (URLSession.DelayedRequestDisposition, URLRequest?) -> Void) {
        Swift.print(String(format: "SU: %p task: %ld willBeginDelayedRequest: request: %@", session, task.taskIdentifier, request.url?.absoluteString ?? "?url"))

    }
    
    @available(OSX 10.13, *)
    func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
        Swift.print(String(format: "SU: %p task: %ld taskIsWaitingForConnectivity:", session, task.taskIdentifier))

    }
    
    @available(OSX 10.9, *)
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        Swift.print(String(format: "SU: %p task: %ld willPerformHTTPRedirection:", session, task.taskIdentifier))

    }
    
    @available(OSX 10.9, *)
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        Swift.print(String(format: "SU: %p task: %ld challenge:", session, task.taskIdentifier))

    }
    
    @available(OSX 10.9, *)
    func urlSession(_ session: URLSession, task: URLSessionTask, needNewBodyStream completionHandler: @escaping (InputStream?) -> Void) {
        Swift.print(String(format: "SU: %p task: %ld needNewBodyStream:", session, task.taskIdentifier))

    }
    
    @available(OSX 10.9, *)
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        Swift.print(String(format: "SU: %p task: %ld didSendBodyData:", session))

    }
    
    @available(OSX 10.12, *)
    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        Swift.print(String(format: "SU: %p task: %ld didFinishCollecting:", session))

    }
    
    @available(OSX 10.9, *)
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        Swift.print(String(format: "SU: %p task: %ld didCompleteWithError:", session))

    }
}

//  MARK: URLSessionDataDelegate
extension WebViewController: URLSessionDataDelegate {

    @available(OSX 10.9, *)
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        Swift.print(String(format: "SU: %p dataTask: %ld didReceive response:", session))

    }
    
    @available(OSX 10.9, *)
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome downloadTask: URLSessionDownloadTask) {
        Swift.print(String(format: "SD: %p dataTask: %ld downloadTask:", session))

    }
    
    @available(OSX 10.11, *)
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome streamTask: URLSessionStreamTask) {
        Swift.print(String(format: "SD: %p dataTask: %ld streamTask:", session))

    }
    
    @available(OSX 10.9, *)
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        Swift.print(String(format: "SD: %p dataTask: %ld didReceive data:", session))

    }
    
    @available(OSX 10.9, *)
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, willCacheResponse proposedResponse: CachedURLResponse, completionHandler: @escaping (CachedURLResponse?) -> Void) {
        Swift.print(String(format: "SD: %p dataTask: %ld proposedResponse:", session, dataTask.taskIdentifier))
        
    }
}

//  MARK: URLSessionDownloadDelegate
extension WebViewController: URLSessionDownloadDelegate {
        
    @available(OSX 10.9, *)
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        Swift.print(String(format: "SU: %p downloadTask: %ld didFinishDownloadingTo:", session, downloadTask.taskIdentifier))

    }
    
    @available(OSX 10.9, *)
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        Swift.print(String(format: "session: %p downloadTask: %ld didWriteData bytesWritten:", session, downloadTask.taskIdentifier))

    }
    
    @available(OSX 10.9, *)
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        Swift.print(String(format: "session: %p downloadTask: %ld didResumeAtOffset:", session, downloadTask.taskIdentifier))

    }
}
