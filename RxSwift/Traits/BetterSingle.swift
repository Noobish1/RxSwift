import Foundation

public typealias BetterSingle<T, E: Error> = Single<Result<T, E>>

extension BetterSingle where Trait == SingleTrait {
    public static func n1_create<T, E: Error>(
        subscribe: @escaping (@escaping (Result<T, E>) -> Void) -> Disposable
    ) -> BetterSingle<T, E> where Element == Result<T, E> {
        let source = Observable<Result<T, E>>.create { (observer: AnyObserver<Result<T, E>>) in
            return subscribe { event in
                switch event {
                case .success(let value):
                    observer.on(.next(.success(value)))
                    observer.on(.completed)
                case .failure(let error):
                    observer.on(.error(error))
                }
            }
        }
        
        return PrimitiveSequence<SingleTrait, Result<T, E>>(raw: source)
    }
    
    public func n1_subscribe<T, E: Error>(_ observer: @escaping (Result<T, E>) -> Void) -> Disposable where Element == Result<T, E> {
        var stopped = false
        
        return self.primitiveSequence.asObservable().subscribe { (event: Event<Result<T, E>>) in
            if stopped { return }
            stopped = true
            
            switch event {
            case .next(let element):
                observer(element)
            case .error(_):
                rxFatalErrorInDebug("BetterSingles can't emit an error event")
            case .completed:
                rxFatalErrorInDebug("BetterSingles can't emit a completion event")
            }
        }
    }
    
    public func n1_subscribe<T, E: Error>(onSuccess: ((T) -> Void)? = nil, onError: ((E) -> Void)? = nil) -> Disposable where Element == Result<T, E> {
        #if DEBUG
             let callStack = Hooks.recordCallStackOnError ? Thread.callStackSymbols : []
        #else
            let callStack = [String]()
        #endif
    
        return self.primitiveSequence.n1_subscribe { (event: Result<T, E>) in
            switch event {
            case .success(let element):
                onSuccess?(element)
            case .failure(let error):
                if let onError = onError {
                    onError(error)
                } else {
                    Hooks.defaultErrorHandler(callStack, error)
                }
            }
        }
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
