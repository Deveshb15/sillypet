import Foundation

protocol AgentMonitor: AnyObject {
    var onEvent: ((AgentEvent) -> Void)? { get set }
    func start()
    func stop()
}
