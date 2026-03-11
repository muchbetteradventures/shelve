import SafariServices

class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
    func beginRequest(with context: NSExtensionContext) {
        let response = NSExtensionItem()
        response.userInfo = [ SFExtensionMessageKey: [ "status": "ok" ] ]
        context.completeRequest(returningItems: [response], completionHandler: nil)
    }
}
