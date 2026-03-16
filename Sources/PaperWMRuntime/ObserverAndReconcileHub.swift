import Foundation
import PaperWMCore

/// System events observed by the adapter layer.
public enum ObservedSystemEvent: Sendable, Equatable {
  case wmEvent
  case displayTopologyChanged
  case spaceChanged
}

/// Protocol for triggering reconciliation passes.
///
/// Implemented by `ReconciliationCoordinator` to allow the hub to drive reconcile operations.
@MainActor
public protocol ReconciliationTriggering: AnyObject {
  @discardableResult
  func reconcile(reason: ReconcileReason) async -> ReconcileResult
}

/// Protocol for event sources that observe system changes.
///
/// The macOS adapter layer will implement this to emit raw system events
/// (AX notifications, display change notifications, space change notifications).
@MainActor
public protocol ObserverEventSourceProtocol: AnyObject {
  /// Sets the handler to call when an observed event occurs.
  /// Pass `nil` to disconnect.
  func setEventHandler(_ handler: (@MainActor @Sendable (ObservedSystemEvent) -> Void)?)

  /// Starts observing system events.
  func start()

  /// Stops observing system events.
  func stop()
}

/// Protocol for the hub that connects event sources to the reconciliation coordinator.
///
/// The hub is responsible for:
/// - Converting raw system events into `ReconcileReason`s
/// - Coalescing bursts of events into a single reconcile pass
/// - Calling the coordinator to perform the actual reconciliation
@MainActor
public protocol ObserverAndReconcileHubProtocol: AnyObject {
  /// Starts the hub and its connected event source.
  func start()

  /// Stops the hub and its connected event source.
  func stop()

  /// Handles an observed system event.
  /// This is exposed for testing purposes.
  func handle(event: ObservedSystemEvent)
}
