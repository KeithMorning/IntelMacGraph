import Foundation

let sample = """
Battery Power:
 gpuswitch            0
 sleep                1
AC Power:
 gpuswitch            1
"""
let mixed = GPUSettings(sample)
precondition(mixed.mode(for: "Battery Power") == .integrated)
precondition(mixed.mode(for: "AC Power") == .discrete)
precondition(mixed.mode(for: nil) == nil)
precondition(GPUPolicy.byPowerSource.matches(mixed))
precondition(!GPUPolicy.manual(.discrete).matches(mixed))
precondition(!GPUPolicy.manual(.integrated).matches(mixed))
precondition(!GPUPolicy.byPowerSource.matches(GPUSettings("AC Power:\n gpuswitch 1\n")))
let uniform = GPUSettings("Battery Power:\n gpuswitch 2\nAC Power:\n gpuswitch 2\n")
precondition(GPUPolicy.manual(.automatic).matches(uniform))
precondition(!GPUPolicy.byPowerSource.matches(uniform))
precondition(!GPUPolicy.manual(.automatic).matches(GPUSettings("")))
precondition(GPUPolicy.byPowerSource.command == "/usr/bin/pmset -b gpuswitch 0 -c gpuswitch 1")
precondition(GPUSettings("AC Power:\n gpuswitch 2\n").mode(for: nil) == .automatic)
precondition(GPUSettings("AC Power:\n gpuswitch 9\n").profiles.isEmpty)
precondition(GPUSettings("AC Power:\n notgpuswitch 1\n").profiles.isEmpty)
precondition(GPUSettings("").mode(for: "AC Power") == nil)
precondition(GPUSettings.powerSource("Now drawing from 'AC Power'\n other") == "AC Power")
precondition(GPUSettings.powerSource("Now drawing from 'Battery Power'\n") == "Battery Power")
precondition(GPUSettings.powerSource("unexpected output") == nil)
precondition(GPUMode.integrated.command == "/usr/bin/pmset -a gpuswitch 0")
precondition(GPUMode.discrete.command == "/usr/bin/pmset -a gpuswitch 1")
precondition(GPUMode.automatic.command == "/usr/bin/pmset -a gpuswitch 2")
let live = GPUSettings(try Shell.run("/usr/bin/pmset", ["-g", "custom"]))
print("PASS: profile parsing, mode mapping, fixed commands, power source parsing, power policy and manual override verification")
print("Live settings: \(live.profiles.map { "\($0.key)=\($0.value.rawValue)" }.sorted().joined(separator: ", "))")
