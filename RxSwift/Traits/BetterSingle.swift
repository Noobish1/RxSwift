import Foundation

public typealias BetterSingle<T, E: Error> = Single<Result<T, E>>

extension BetterSingle {
    public typealias BetterSingleObserver<E: Error> = (Result<Element, E>) -> Void
    
    public static func create<E>(subscribe: @escaping (@escaping BetterSingleObserver<E>) -> Disposable) -> BetterSingle<Element, E> {
        let source = Observable<Result<Element, E>>.create { (observer: AnyObserver<Result<Element, E>>) in
            return subscribe { (event: Result<Element, E>) in
                switch event {
                case .success(_):
                    observer.on(.next(event))
                    observer.on(.completed)
                case .failure(let error):
                    observer.on(.error(error))
                }
            }
        }
        
        return PrimitiveSequence<SingleTrait, Result<Element, E>>(raw: source)
    }
    
    public func subscribe<E>(_ observer: @escaping (Result<Element, E>) -> Void) -> Disposable {
        var stopped = false
        return self.primitiveSequence.asObservable().subscribe { event in
            if stopped { return }
            stopped = true
            
            switch event {
            case .next(let element):
                observer(.success(element))
            case .error(_):
                rxFatalErrorInDebug("BetterSingles can't emit an error event")
            case .completed:
                rxFatalErrorInDebug("BetterSingles can't emit a completion event")
            }
        }
    }
    
    public func subscribe<E: Error>(onSuccess: ((Element) -> Void)? = nil, onError: ((E) -> Void)? = nil) -> Disposable {
        #if DEBUG
             let callStack = Hooks.recordCallStackOnError ? Thread.callStackSymbols : []
        #else
            let callStack = [String]()
        #endif
    
        return self.primitiveSequence.subscribe { (event: Result<Element, E>) in
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
