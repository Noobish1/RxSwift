import Foundation

public typealias BetterSingle<T, E: Error> = Single<Result<T, E>>

extension BetterSingle {
    public static func create<T, E>(subscribe: @escaping (@escaping (Result<T, E>) -> Void) -> Disposable) -> BetterSingle<T, E> {
        let source = Observable<Result<T, E>>.create { (observer: AnyObserver<Result<T, E>>) in
            return subscribe { (event: Result<T, E>) in
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
    
    public func subscribe<T, E: Error>(_ observer: @escaping (Result<T, E>) -> Void) -> Disposable where Element == Result<T, E> {
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
    
    public func subscribe<T, E: Error>(onSuccess: ((T) -> Void)? = nil, onError: ((E) -> Void)? = nil) -> Disposable where Element == Result<T, E> {
        #if DEBUG
             let callStack = Hooks.recordCallStackOnError ? Thread.callStackSymbols : []
        #else
            let callStack = [String]()
        #endif
    
        return self.primitiveSequence.subscribe { (event: Result<T, E>) in
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
}
