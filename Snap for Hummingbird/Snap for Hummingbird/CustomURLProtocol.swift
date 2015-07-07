import UIKit
import CoreData
import SystemConfiguration.CaptiveNetwork

var requestCount = 0

class CustomURLProtocol: NSURLProtocol {
    
    var connection: NSURLConnection!
    var mutableData: NSMutableData!
    var response: NSURLResponse!
    
    override class func canInitWithRequest(request: NSURLRequest) -> Bool {
        print("Request #\(requestCount++): URL = ")
        println(request.URL!.absoluteString)
        if NSURLProtocol.propertyForKey("MyURLProtocolHandledKey", inRequest: request) != nil {
            return false
        }
        //Don't care about doing stuff with requests to localhost
        let url: NSString = NSString(string: request.URL!.absoluteString!.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()))
        let urlToIgnore: NSString = NSString(string: "http://localhost:22179/project.xml")
        
        if url == urlToIgnore {
            println("local")
            return false
        }
        println("Not equal")
        return true
    }
    
    override class func canonicalRequestForRequest(request: NSURLRequest) -> NSURLRequest {
        return request
    }
    
    override class func requestIsCacheEquivalent(aRequest: NSURLRequest,
        toRequest bRequest: NSURLRequest) -> Bool {
            return super.requestIsCacheEquivalent(aRequest, toRequest:bRequest)
    }
    
    override func startLoading() {
        // 1
        let possibleCachedResponse = self.cachedResponseForCurrentRequest()
        if let cachedResponse = possibleCachedResponse {
            if(!isConnectedToInternet()){
                println("Serving response from cache")
            
                // 2
                let data = cachedResponse.valueForKey("data") as! NSData!
                let mimeType = cachedResponse.valueForKey("mimeType") as! String!
                let encoding = cachedResponse.valueForKey("encoding") as! String!
                
                // 3
                let response = NSURLResponse(URL: self.request.URL!, MIMEType: mimeType, expectedContentLength: data.length, textEncodingName: encoding)
            
                // 4
                self.client!.URLProtocol(self, didReceiveResponse: response, cacheStoragePolicy: .NotAllowed)
                self.client!.URLProtocol(self, didLoadData: data)
                self.client!.URLProtocolDidFinishLoading(self)
            }
            else{
                println("Serving response from NSURLConnection")
                
                var newRequest = self.request.mutableCopy() as! NSMutableURLRequest
                NSURLProtocol.setProperty(true, forKey: "MyURLProtocolHandledKey", inRequest: newRequest)
                self.connection = NSURLConnection(request: newRequest, delegate: self)
            }
        } else {
            // 5
            println("Serving response from NSURLConnection")
            
            var newRequest = self.request.mutableCopy() as! NSMutableURLRequest
            NSURLProtocol.setProperty(true, forKey: "MyURLProtocolHandledKey", inRequest: newRequest)
            self.connection = NSURLConnection(request: newRequest, delegate: self)
        }
    }
    
    override func stopLoading() {
        if self.connection != nil {
            self.connection.cancel()
        }
        self.connection = nil
    }
    
    func connection(connection: NSURLConnection!, didReceiveResponse response: NSURLResponse!) {
        self.client!.URLProtocol(self, didReceiveResponse: response, cacheStoragePolicy: .NotAllowed)

        self.response = response
        self.mutableData = NSMutableData()
    }
    
    func connection(connection: NSURLConnection!, didReceiveData data: NSData!) {
        self.client!.URLProtocol(self, didLoadData: data)
        self.mutableData.appendData(data)
    }
    
    func connectionDidFinishLoading(connection: NSURLConnection!) {
        self.client!.URLProtocolDidFinishLoading(self)
        self.saveCachedResponse()
    }
    
    func connection(connection: NSURLConnection!, didFailWithError error: NSError!) {
        self.client!.URLProtocol(self, didFailWithError: error)
    }
    
    func saveCachedResponse () {
        println("Saving cached response")
        
        // 1
        let delegate = UIApplication.sharedApplication().delegate as! AppDelegate
        let context = delegate.managedObjectContext!
        
        // 2
        let cachedResponse = NSEntityDescription.insertNewObjectForEntityForName("CachedURLResponse", inManagedObjectContext: context) as! NSManagedObject
        
        cachedResponse.setValue(self.mutableData, forKey: "data")
        cachedResponse.setValue(self.request.URL!.absoluteString, forKey: "url")
        cachedResponse.setValue(NSDate(), forKey: "timestamp")
        cachedResponse.setValue(self.response.MIMEType, forKey: "mimeType")
        cachedResponse.setValue(self.response.textEncodingName, forKey: "encoding")
        
        // 3
        var error: NSError?
        let success = context.save(&error)
        if !success {
            println("Could not cache the response")
        }
    }
    
    func cachedResponseForCurrentRequest() -> NSManagedObject? {
        // 1
        let delegate = UIApplication.sharedApplication().delegate as! AppDelegate
        let context = delegate.managedObjectContext!
        
        // 2
        let fetchRequest = NSFetchRequest()
        let entity = NSEntityDescription.entityForName("CachedURLResponse", inManagedObjectContext: context)
        fetchRequest.entity = entity
        
        // 3
        let predicate = NSPredicate(format:"url == %@", self.request.URL!.absoluteString!)
        fetchRequest.predicate = predicate
        
        // 4
        var error: NSError?
        let possibleResult = context.executeFetchRequest(fetchRequest, error: &error) as! Array<NSManagedObject>?
        
        // 5
        if let result = possibleResult {
            if !result.isEmpty {
                return result[0]
            }
        }
        
        return nil
    }
    
    func isConnectedToInternet() -> Bool{
        var zeroAddress = sockaddr_in(sin_len: 0, sin_family: 0, sin_port: 0, sin_addr: in_addr(s_addr: 0), sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
        zeroAddress.sin_len = UInt8(sizeofValue(zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        let defaultRouteReachability = withUnsafePointer(&zeroAddress) {
            SCNetworkReachabilityCreateWithAddress(nil, UnsafePointer($0)).takeRetainedValue()
        }
        
        var flags: SCNetworkReachabilityFlags = 0
        if SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags) == 0 {
            return false
        }
        
        let isReachable = (flags & UInt32(kSCNetworkFlagsReachable)) != 0
        let needsConnection = (flags & UInt32(kSCNetworkFlagsConnectionRequired)) != 0
        
        return isReachable && !needsConnection
    }
}