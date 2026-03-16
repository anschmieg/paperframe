import Foundation
import PaperWMCore

/// Concrete implementation of the observer-driven reconciliation hub.
///
/// This hub converts raw system events from an event source into `ReconcileReason`s
/// and coalesces bursts of events into a single reconcile pass to avoid thrashing.
@MainActor
public final class ObserverAndReconcileHub: ObserverAndReconcileHubProtocol {
  private let eventSource: any ObserverEventSourceProtocol
  private let coordinator: any ReconciliationTriggering

  private var isStarted = false
  private var reconcileTask: Task<Void, Never>?
  private var pendingReason: ReconcileReason?

  public init(
    eventSource: any ObserverEventSourceProtocol,
    coordinator: any ReconciliationTriggering
  ) {
    self.eventSource = eventSource
    self.coordinator = coordinator
  }

  public func start() {
    guard !isStarted else { return }
    isStarted = true

    eventSource.setEventHandler { [weak self] event in
      self?.handle(event: event)
    }
    eventSource.start()
  }

  public func stop() {
    guard isStarted else { return }
    isStarted = false

    eventSource.setEventHandler(nil)
    eventSource.stop()

    reconcileTask?.cancel()
    reconcileTask = nil
    pendingReason = nil
  }

  public func handle(event: ObservedSystemEvent) {
    let mapped = map(event: event)
    enqueue(reason: mapped)
  }

  // MARK: - Private

  /// Maps an observed system event to a reconcile reason.
  private func map(event: ObservedSystemEvent) -> ReconcileReason {
    switch event {
    case .wmEvent:
      return .wmEvent
    case .displayTopologyChanged:
      return .displayTopologyChanged
    case .spaceChanged:
      return .wmEvent
    }
  }

  /// Enqueues a reason for reconciliation, coalescing with any pending reason.
  private func enqueue(reason: ReconcileReason) {
    pendingReason = combine(current: pendingReason, incoming: reason)

    guard reconcileTask == nil else { return }

    reconcileTask = Task { [weak self] in
      guard let self else { return }

      try? await Task.sleep(nanoseconds: 10_000_000)

      while !Task.isCancelled, let nextReason = self.pendingReason {
        self.pendingReason = nil
        _ = await self.coordinator.reconcile(reason: nextReason)
      }

      self.reconcileTask = nil
    }
  }

  /// Combines two reconcile reasons, prioritizing the more significant one.
  ///
  /// Display topology changes are the most significant.
  private func combine(
    current: ReconcileReason?,
    incoming: ReconcileReason
  ) -> ReconcileReason {
    guard let current else { return incoming }

    let currentIsDisplay: Bool
    let incomingIsDisplay: Bool

    if case .displayTopologyChanged = current {
      currentIsDisplay = true
    } else {
      currentIsDisplay = false
    }

    if case .displayTopologyChanged = incoming {
      incomingIsDisplay = true
    } else {
      incomingIsDisplay = false
    }

    if currentIsDisplay || incomingIsDisplay {
      return .displayTopologyChanged
    }

    // Always prefer incoming for any other case
    return incoming
  }
}
