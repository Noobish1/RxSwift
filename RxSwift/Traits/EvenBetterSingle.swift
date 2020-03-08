//
//  Single.swift
//  RxSwift
//
//  Created by sergdort on 19/08/2017.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

#if DEBUG
import Foundation
#endif

/// Sequence containing exactly 1 element
public enum BetterSingleTrait { }
/// Represents a push style sequence containing 1 element.
public typealias BetterSingle<Element, E: Error> = PrimitiveSequence<BetterSingleTrait, Result<Element, E>>

public typealias BetterSingleEvent<Element, E: Error> = Result<Element, E>

extension PrimitiveSequenceType where Trait == BetterSingleTrait {
    public typealias BetterSingleObserver<E: Error> = (BetterSingleEvent<Element, E>) -> Void
    
    /**
     Creates an observable sequence from a specified subscribe method implementation.
     
     - seealso: [create operator on reactivex.io](http://reactivex.io/documentation/operators/create.html)
     
     - parameter subscribe: Implementation of the resulting observable sequence's `subscribe` method.
     - returns: The observable sequence with the specified implementation for the `subscribe` method.
     */
    public static func create<E: Error>(subscribe: @escaping (@escaping BetterSingleObserver<E>) -> Disposable) -> BetterSingle<Element, E> {
        let source = Observable<Result<Element, E>>.create { observer in
            return subscribe { event in
                switch event {
                case .success(let element):
                    observer.on(.next(.success(element)))
                    observer.on(.completed)
                case .failure(let error):
                    observer.on(.next(.failure(error)))
                }
            }
        }
        
        return PrimitiveSequence<BetterSingleTrait, Result<Element, E>>(raw: source)
    }
    
    
    /**
     Subscribes `observer` to receive events for this sequence.
     
     - returns: Subscription for `observer` that can be used to cancel production of sequence elements and free resources.
     */
    public func subscribe<E: Error>(_ observer: @escaping (BetterSingleEvent<Element, E>) -> Void) -> Disposable {
        var stopped = false
        
        return self.primitiveSequence.asObservable().subscribe { event in
            if stopped { return }
            stopped = true
            
            switch event {
            case .next(let element):
                observer(.success(element))
            case .error(let error):
                guard let ourError = error as? E else {
                    rxFatalErrorInDebug("BetterSingles can't emit an errors of different types")
                    
                    return
                }
                
                observer(.failure(ourError))
            case .completed:
                rxFatalErrorInDebug("Singles can't emit a completion event")
            }
        }
    }
    
    /**
     Subscribes a success handler, and an error handler for this sequence.
     
     - parameter onSuccess: Action to invoke for each element in the observable sequence.
     - parameter onError: Action to invoke upon errored termination of the observable sequence.
     - returns: Subscription object used to unsubscribe from the observable sequence.
     */
    public func subscribe<E: Error>(onSuccess: ((Element) -> Void)? = nil, onError: ((E) -> Void)? = nil) -> Disposable {
        #if DEBUG
             let callStack = Hooks.recordCallStackOnError ? Thread.callStackSymbols : []
        #else
            let callStack = [String]()
        #endif
    
        return self.primitiveSequence.subscribe { (result: Result<Element, E>) in
            switch result {
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
