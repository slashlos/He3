//
//  WebViewController+Navigation+UI.swift
//  He3
//
//  Created by Carlos D. Santiago on 5/6/20.
//  Copyright © 2020 Carlos D. Santiago. All rights reserved.
//

import Foundation
import WebKit

fileprivate var defaults : UserDefaults {
    get {
        return UserDefaults.standard
    }
}
fileprivate var appDelegate : AppDelegate {
    get {
        return NSApp.delegate as! AppDelegate
    }
}
fileprivate var docController : DocumentController {
    get {
        return NSDocumentController.shared as! DocumentController
    }
}

// MARK:- Navigation Delegate

extension WebViewController: WKNavigationDelegate {
	// Redirect Hulu and YouTube to pop-out videos
	func webView(_ webView: WKWebView,
				 decidePolicyFor navigationAction: WKNavigationAction,
				 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
		Swift.print(String(format: "0DP: navigationAction: %p", webView))

		let viewOptions = appDelegate.getViewOptions
		var url = navigationAction.request.url!
		
		guard navigationAction.buttonNumber < 2 else {
			Swift.print("newWindow with url:\(String(describing: url))")
			if viewOptions.contains(.t_view) {
				_ = appDelegate.openURLInNewWindow(url, context: webView.window )
			}
			else
			{
				_ = appDelegate.openURLInNewWindow(url)
			}
			decisionHandler(WKNavigationActionPolicy.cancel)
			return
		}
		
		guard !UserSettings.DisabledMagicURLs.value else {
			if let selectedURL = (webView as! MyWebView).selectedURL {
				url = selectedURL
			}
			if navigationAction.buttonNumber > 1 {
				if viewOptions.contains(.t_view) {
					_ = appDelegate.openURLInNewWindow(url, context: webView.window )
				}
				else
				{
					_ = appDelegate.openURLInNewWindow(url)
				}
				decisionHandler(WKNavigationActionPolicy.cancel)
			}
			else
			{
				decisionHandler(WKNavigationActionPolicy.allow)
			}
			return
		}

		if let newUrl = UrlHelpers.doMagic(url), newUrl != url {
			decisionHandler(WKNavigationActionPolicy.cancel)
			if let selectedURL = (webView as! MyWebView).selectedURL {
				url = selectedURL
			}
			if navigationAction.buttonNumber > 1
			{
				if viewOptions.contains(.t_view) {
					_ = appDelegate.openURLInNewWindow(newUrl, context: webView.window )
				}
				else
				{
					_ = appDelegate.openURLInNewWindow(newUrl)
				}
			}
			else
			{
				_ = loadURL(url: newUrl)
			}
		}
		
		Swift.print("navType: \(navigationAction.navigationType.name)")
		
		decisionHandler(WKNavigationActionPolicy.allow)
	}
	/*  OPTIONAL @available(OSX 10.15, *)
	 /** @abstract Decides whether to allow or cancel a navigation after its
	 response is known.
	 @param webView The web view invoking the delegate method.
	 @param navigationResponse Descriptive information about the navigation
	 response.
	 @param decisionHandler The decision handler to call to allow or cancel the
	 navigation. The argument is one of the constants of the enumerated type WKNavigationResponsePolicy.
	 @discussion If you do not implement this method, the web view will allow the response, if the web view can show it.
	 */
	func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: WKWebpagePreferences, decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
	}
	*/
	func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
		guard let response = navigationResponse.response as? HTTPURLResponse,
			let url = navigationResponse.response.url else {
				decisionHandler(.allow)
				return
		}
		
		Swift.print(String(format: "1DP navigationResponse: %p <= %@", webView, url.absoluteString))
		
		//  load cookies
		if let headerFields = response.allHeaderFields as? [String:String] {
			Swift.print("\(url.absoluteString) allHeaderFields:\n\(headerFields)")
			let waitGroup = DispatchGroup()

			let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: url)
			cookies.forEach({ cookie in
				waitGroup.enter()
				webView.configuration.websiteDataStore.httpCookieStore.setCookie(cookie, completionHandler: { waitGroup.leave() })
			})
		}
		
		guard !url.hasUserContent(), url.hasDataContent(), let suggestion = response.suggestedFilename else { decisionHandler(.allow); return }
		let downloadDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
		let saveURL = downloadDir.appendingPathComponent(suggestion)
		saveURL.saveAs(responseHandler: { saveAsURL in
			if let saveAsURL = saveAsURL {
				self.loadFileAsync(url, to: saveAsURL, completion: { (path, error) in
					if let error = error {
						NSApp.presentError(error)
					}
					else
					{
						if appDelegate.isSandboxed { _ = appDelegate.storeBookmark(url: saveAsURL, options: [.withSecurityScope]) }
					}
				})
			}

			decisionHandler(.cancel)
			self.backPress(self)
		 })
	}

	func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
		Swift.print(String(format: "1LD: %p didStartProvisionalNavigation: %p %@", navigation, webView, webView.url!.debugDescription))
		
		//  Restore setting not done by document controller
		if let hpc = heliumPanelController { hpc.documentDidLoad() }
		
		//	Capture AV menu items
		if let webView = webView as? MyWebView, let event = NSApp.currentEvent, let menu = webView.menu(for: event) {
			webView.captureMenuItems(menu)
		}
	}

	func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
		Swift.print(String(format: "2SR: %p didReceiveServerRedirectForProvisionalNavigation: %p", navigation, webView))
	}

	func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
		Swift.print(String(format: "?LD: %p didFailProvisionalNavigation: %p", navigation, webView) + " \((error as NSError).code): \(error.localizedDescription)")
		handleError(error)
	}

	func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
		Swift.print(String(format: "2NV: %p - didCommit: %p", navigation, webView))
	}

	func webView(_ webView: WKWebView, didFinish navigation: WKNavigation) {
		guard let url = webView.url else { return }
		
		Swift.print(String(format: "3NV: %p didFinish: %p", navigation, webView) + " \"\(String(describing: webView.title))\" => \(url.absoluteString)")
		if let doc = self.document, let dict = defaults.dictionary(forKey: url.absoluteString) {
			doc.restoreSettings(with: dict)
		}
		
		//  Finish recording of for this url session
		if UserSettings.HistorySaves.value, let webView = (webView as? MyWebView), !webView.incognito {
			let notif = Notification(name: Notification.Name(rawValue: "NewURL"), object: url, userInfo: [k.fini : true, k.view : webView as Any])
			NotificationCenter.default.post(notif)
		}
	}

	func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
		Swift.print(String(format: "?NV: %p didFail: %p", navigation, webView) + " \((error as NSError).code): \(error.localizedDescription)")
		handleError(error)
	}

	fileprivate func handleError(_ error: Error) {
		let message = error.localizedDescription
		if (error as NSError).code >= 400 {
			NSApp.presentError(error)
		}
		else
		if (error as NSError).code < 0 {
			if let info = error._userInfo as? [String: Any] {
				if let url = info["NSErrorFailingURLKey"] as? URL {
					userAlertMessage(message, info: url.absoluteString)
				}
				else
				if let urlString = info["NSErrorFailingURLStringKey"] as? String {
					userAlertMessage(message, info: urlString)
				}
			}
		}
	}

	func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
		let authMethod = challenge.protectionSpace.authenticationMethod
		Swift.print(String(format: "2AC: didReceive: %p \(authMethod)", webView))

		guard let serverTrust = challenge.protectionSpace.serverTrust else { return completionHandler(.useCredential, nil) }
		let exceptions = SecTrustCopyExceptions(serverTrust)
		SecTrustSetExceptions(serverTrust, exceptions)
		completionHandler(.useCredential, URLCredential(trust: serverTrust))
	}

	func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
		Swift.print(String(format: "3DT: webViewWebContentProcessDidTerminate: %p", webView))
		
		//  If incognito tear down...
		if let webView = (webView as? MyWebView), webView.incognito {
			Swift.print("webView specific tear down for incognito...")
		}
	}

}

//  MARK:- UI Delegate

extension WebViewController: WKUIDelegate {
	func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
				 for navigationAction: WKNavigationAction,
				 windowFeatures: WKWindowFeatures) -> WKWebView? {
		Swift.print(String(format: "UI: %p createWebViewWith:", webView))

		if navigationAction.targetFrame == nil {
			_ = appDelegate.openURLInNewWindow(navigationAction.request.url!)
			return nil
		}
		
		//  We really want to use the supplied config, so use custom setup
		var newWebView : WKWebView?
		
		if let newURL = navigationAction.request.url {
			do {
				let doc = try NSDocumentController.shared.makeDocument(withContentsOf: newURL, ofType: k.Custom)
				if let hpc = doc.windowControllers.first, let window = hpc.window, let wvc = window.contentViewController as? WebViewController {
					newWebView = MyWebView()
					wvc.webView = newWebView as! MyWebView
					wvc.viewDidLoad()
					
					_ = wvc.loadURL(url: newURL)
				 }
			} catch let error {
				NSApp.presentError(error)
			}
		}

		return newWebView
	}

	func webViewDidClose(_ webView: WKWebView) {
		Swift.print(String(format: "UI: %p webViewDidClose:", webView))
		webView.stopLoading()
	}

	func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: () -> Void) {
		Swift.print(String(format: "UI: %p runJavaScriptAlertPanelWithMessage: %@", webView, message))

		userAlertMessage(message, info: nil)
		completionHandler()
	}

	func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: (Bool) -> Void) {
		Swift.print(String(format: "UI: %p runJavaScriptConfirmPanelWithMessage: %@", webView, message))

		completionHandler( userConfirmMessage(message, info: nil) )
	}

	func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: (String?) -> Void) {
		Swift.print(String(format: "UI: %p runJavaScriptTextInputPanelWithPrompt: %@", webView, prompt))

		completionHandler( userTextInput(prompt, defaultText: defaultText) )
	}

	func webView(_ webView: WKWebView, didFinishLoad navigation: WKNavigation) {
		Swift.print(String(format: "3LD: %p didFinishLoad: %p", navigation, webView))
		//  deprecated
	}

	func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters,
				 initiatedByFrame frame: WKFrameInfo,
				 completionHandler: @escaping ([URL]?) -> Void) {
		Swift.print(String(format: "UI: %p runOpenPanelWith:", webView))
		
		let openPanel = NSOpenPanel()
				
		openPanel.allowsMultipleSelection = parameters.allowsMultipleSelection
		openPanel.canChooseFiles = false
		openPanel.canChooseDirectories = parameters.allowsDirectories
		
		openPanel.begin() { (result) -> Void in
			if result == .OK {
				completionHandler(openPanel.urls)
			}
			else
			{
				completionHandler(nil)
			}
		}
	}
}