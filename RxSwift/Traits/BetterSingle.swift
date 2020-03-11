import Foundation

public typealias BetterSingle<T, E: Error> = Single<Result<T, E>>

extension BetterSingle where Trait == SingleTrait {
    public static func n1_create<T, E: Error>(
        subscribe: @escaping (@escaping (Result<T, E>) -> Void) -> Disposable
    ) -> BetterSingle<T, E> where Element == Result<T, E> {
        return self.create { (observer: @escaping (SingleEvent<Result<T, E>>) -> Void) -> Disposable in
            return subscribe { result in
                observer(.success(result))
            }
        }
    }
    
    public func n1_subscribe<T, E: Error>(_ observer: @escaping (Result<T, E>) -> Void) -> Disposable where Element == Result<T, E> {
        return self.subscribe { event in
            switch event {
                case .success(let result):
                    observer(result)
                case .error(_):
                    rxFatalErrorInDebug("BetterSingles shouldn't receive error events")
            }
        }
    }
    
    public func n1_subscribe<T, E: Error>(onSuccess: ((T) -> Void)? = nil, onError: ((E) -> Void)? = nil) -> Disposable where Element == Result<T, E> {
        return self.subscribe(
            onSuccess: { result in
                switch result {
                    case .success(let value): onSuccess?(value)
                    case .failure(let error): onError?(error)
                }
            },
            onError: { error in
                rxFatalErrorInDebug("BetterSingles shouldn't receive error events")
            }
        )
    }
    
    public func n1_do<T, E: Error>(
        onSuccess: ((T) throws -> Void)? = nil,
        afterSuccess: ((T) throws -> Void)? = nil,
        onError: ((E) throws -> Void)? = nil,
        afterError: ((E) throws -> Void)? = nil,
        onSubscribe: (() -> Void)? = nil,
        onSubscribed: (() -> Void)? = nil,
        onDispose: (() -> Void)? = nil
    ) -> Single<Element> where Element == Result<T, E> {
        return self.do(
            onSuccess: { result in
                switch result {
                    case .success(let value): try onSuccess?(value)
                    case .failure(let error): try onError?(error)
                }
            },
            afterSuccess: { result in
                switch result {
                    case .success(let value): try afterSuccess?(value)
                    case .failure(let error): try afterError?(error)
                }
            },
            onError: { _ in},
            afterError: { _ in },
            onSubscribe: onSubscribe,
            onSubscribed: onSubscribed,
            onDispose: onDispose
        )
    }
    
    public func n1_flatMap<OtherValue, T, E: Error>(
        _ selector: @escaping (T) throws -> BetterSingle<OtherValue, E>
    ) -> BetterSingle<OtherValue, E> where Element == Result<T, E> {
        return self.flatMap { (result: Result<T, E>) -> BetterSingle<OtherValue, E> in
            switch result {
                case .success(let value): return try selector(value)
                case .failure(let error): return BetterSingle<OtherValue, E>.just(.failure(error))
            }
        }
    }
}
