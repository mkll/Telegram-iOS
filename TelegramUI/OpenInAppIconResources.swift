import Foundation
import TelegramCore
import SwiftSignalKit
import Postbox

public struct OpenInAppIconResourceId: MediaResourceId {
    public let appStoreId: Int64
    
    public var uniqueId: String {
        return "app-icon-\(appStoreId)"
    }
    
    public var hashValue: Int {
        return self.appStoreId.hashValue
    }
    
    public func isEqual(to: MediaResourceId) -> Bool {
        if let to = to as? OpenInAppIconResourceId {
            return self.appStoreId == to.appStoreId
        } else {
            return false
        }
    }
}

public class OpenInAppIconResource: TelegramMediaResource {
    public let appStoreId: Int64
    
    public init(appStoreId: Int64) {
        self.appStoreId = appStoreId
    }
    
    public required init(decoder: PostboxDecoder) {
        self.appStoreId = decoder.decodeInt64ForKey("i", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.appStoreId, forKey: "i")
    }
    
    public var id: MediaResourceId {
        return OpenInAppIconResourceId(appStoreId: self.appStoreId)
    }
    
    public func isEqual(to: TelegramMediaResource) -> Bool {
        if let to = to as? OpenInAppIconResource {
            return self.appStoreId == to.appStoreId
        } else {
            return false
        }
    }
}

func fetchOpenInAppIconResource(resource: OpenInAppIconResource) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> {
    return Signal { subscriber in
        subscriber.putNext(.reset)

        let metaUrl = "https://itunes.apple.com/lookup?id=\(resource.appStoreId)"
        
        let fetchDisposable = MetaDisposable()
        
        let disposable = fetchHttpResource(url: metaUrl).start(next: { result in
            if case let .dataPart(_, data, _, complete) = result, complete {
                guard let dict = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any] else {
                    subscriber.putNext(.dataPart(resourceOffset: 0, data: Data(), range: 0 ..< 0, complete: true))
                    subscriber.putCompletion()
                    return
                }
                
                guard let results = dict["results"] as? [Any] else {
                    subscriber.putNext(.dataPart(resourceOffset: 0, data: Data(), range: 0 ..< 0, complete: true))
                    subscriber.putCompletion()
                    return
                }
                
                guard let result = results.first as? [String: Any] else {
                    subscriber.putNext(.dataPart(resourceOffset: 0, data: Data(), range: 0 ..< 0, complete: true))
                    subscriber.putCompletion()
                    return
                }
                
                guard let artworkUrl = result["artworkUrl100"] as? String else {
                    subscriber.putNext(.dataPart(resourceOffset: 0, data: Data(), range: 0 ..< 0, complete: true))
                    subscriber.putCompletion()
                    return
                }
                
                if artworkUrl.isEmpty {
                    subscriber.putNext(.dataPart(resourceOffset: 0, data: Data(), range: 0 ..< 0, complete: true))
                    subscriber.putCompletion()
                    return
                } else {
                    fetchDisposable.set(fetchHttpResource(url: artworkUrl).start(next: { next in
                        subscriber.putNext(next)
                    }, completed: {
                        subscriber.putCompletion()
                    }))
                }
            }
        })
        
        return ActionDisposable {
            disposable.dispose()
            fetchDisposable.dispose()
        }
    }
}
