import XCTest
@testable import SillyPet

final class ClaudeHookParserTests: XCTestCase {
    func testPermissionRequestParsesAsPermissionEvent() throws {
        let result = ClaudeHookParser.parse(data: hookData(type: "permission_request", data: """
        {
          "session_id": "abc123",
          "tool_name": "Bash",
          "message": "Claude needs your permission to use Bash"
        }
        """))

        guard case .event(let event) = result else {
            return XCTFail("Expected event, got \(result)")
        }

        XCTAssertEqual(event.kind, .permissionRequest)
        XCTAssertEqual(event.sessionId, "abc123")
        XCTAssertEqual(event.toolName, "Bash")
        XCTAssertEqual(event.message, "Claude needs your permission to use Bash")
    }

    func testIdleNotificationIsIgnored() throws {
        let result = ClaudeHookParser.parse(data: hookData(type: "notification", data: """
        {
          "session_id": "abc123",
          "notification_type": "idle_prompt",
          "message": "Claude is waiting for your input"
        }
        """))

        XCTAssertEqual(result, .ignored)
    }

    func testStopParsesAsTaskCompleted() throws {
        let result = ClaudeHookParser.parse(data: hookData(type: "stop", data: """
        {
          "session_id": "abc123",
          "last_assistant_message": "I've finished the refactor."
        }
        """))

        guard case .event(let event) = result else {
            return XCTFail("Expected event, got \(result)")
        }

        XCTAssertEqual(event.kind, .taskCompleted)
        XCTAssertEqual(event.message, "I've finished the refactor.")
        XCTAssertEqual(event.sessionId, "abc123")
    }

    func testTaskCompletedRetainsTeammateContext() throws {
        let result = ClaudeHookParser.parse(data: hookData(type: "task_completed", data: """
        {
          "session_id": "abc123",
          "task_subject": "Implement auth",
          "teammate_name": "implementer"
        }
        """))

        guard case .event(let event) = result else {
            return XCTFail("Expected event, got \(result)")
        }

        XCTAssertEqual(event.kind, .taskCompleted)
        XCTAssertEqual(event.message, "implementer completed: Implement auth")
    }

    func testStopFailureParsesAsError() throws {
        let result = ClaudeHookParser.parse(data: hookData(type: "stop_failure", data: """
        {
          "session_id": "abc123",
          "error": "rate_limit",
          "error_details": "429 Too Many Requests",
          "last_assistant_message": "API Error: Rate limit reached"
        }
        """))

        guard case .event(let event) = result else {
            return XCTFail("Expected event, got \(result)")
        }

        XCTAssertEqual(event.kind, .error)
        XCTAssertEqual(event.message, "API Error: Rate limit reached")
    }

    func testInvalidJsonIsMarkedIncomplete() {
        let result = ClaudeHookParser.parse(data: Data("{".utf8))
        XCTAssertEqual(result, .incomplete)
    }

    private func hookData(type: String, data: String) -> Data {
        let json = """
        {
          "source": "claude",
          "type": "\(type)",
          "data": \(data),
          "ts": "2026-03-29T00:00:00Z"
        }
        """
        return Data(json.utf8)
    }
}
