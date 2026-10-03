import Darwin
import AppKit
import Foundation
import MaroCore

@main
struct MaroCLI {
    static let usage = """
    Usage: maroctl [--socket PATH] status|search|player|toggle|replay|previous|next
           maroctl [--socket PATH] select VIDEO_ID
           maroctl [--socket PATH] favorite toggle|remove VIDEO_ID
           maroctl bar-displays
    Select uses a video already known to Maro. Output is one JSON response line.
    """

    @MainActor static func main() async {
        var arguments = Array(CommandLine.arguments.dropFirst())
        if arguments == ["--help"] { print(usage); return }
        if arguments == ["bar-displays"] {
            let displays: [[String: Any]] = NSScreen.screens.compactMap { screen in
                guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
                return ["id": id.uint32Value, "notched": screen.safeAreaInsets.top > 0 &&
                    screen.auxiliaryTopLeftArea != nil && screen.auxiliaryTopRightArea != nil]
            }
            do {
                FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject: displays))
                print("")
            } catch { fail("Cannot read display safe areas.", code: 69) }
            return
        }
        var socket = CommandClient.defaultSocketURL
        var customSocket = false
        if arguments.first == "--socket" {
            guard arguments.count >= 3, arguments[1].hasPrefix("/") else {
                fail(usage, code: 64)
            }
            socket = URL(fileURLWithPath: arguments[1])
            customSocket = true
            arguments.removeFirst(2)
        }
        let request: CommandRequest
        do { request = try CommandRequest.arguments(arguments) }
        catch { fail(usage, code: 64) }
        do {
            let environment = ProcessInfo.processInfo.environment
            let explicitApp = environment["MARO_APP_BUNDLE"]
            let response: CommandResponse
            if !customSocket || explicitApp != nil {
                var launchArguments = ["-g"]
                if let path = explicitApp {
                    guard path.hasPrefix("/"), path.hasSuffix(".app"), socket.lastPathComponent == "maro.sock" else {
                        fail("MARO_APP_BUNDLE must name an absolute app bundle; recovery requires a maro.sock path.", code: 64)
                    }
                    launchArguments += ["-a", path, "--env", "MARO_DATA_DIRECTORY=" + socket.deletingLastPathComponent().path]
                    for key in ["MARO_EXTRACTOR", "MARO_NODE"] {
                        if let path = environment[key], path.hasPrefix("/") { launchArguments += ["--env", key + "=" + path] }
                    }
                } else { launchArguments += ["-b", "local.maro.player.development"] }
                let arguments = launchArguments
                response = try await CommandClient.sendRecovering(request, to: socket) {
                    let opened = try await ExtractorProcess.run(executable: URL(fileURLWithPath: "/usr/bin/open"),
                        arguments: arguments, timeout: 3, stdoutLimit: 1024, stderrLimit: 1024)
                    guard opened.exitCode == 0 else { throw CommandClientFailure.unavailable }
                }
            } else { response = try await CommandClient.send(request, to: socket) }
            FileHandle.standardOutput.write(try CommandWire.encode(response))
            if !response.ok { exit(1) }
        } catch CommandClientFailure.unavailable {
            fail("Maro is not running. Open the app and try again.", code: 69)
        } catch CommandClientFailure.outcomeUnknown {
            fail("Maro did not return a valid response. The action may have completed; check status before retrying.", code: 75)
        } catch {
            fail("Cannot connect safely to Maro. Check the local service and socket permissions.", code: 69)
        }
    }

    private static func fail(_ message: String, code: Int32) -> Never {
        FileHandle.standardError.write(Data((message + "\n").utf8))
        exit(code)
    }
}
