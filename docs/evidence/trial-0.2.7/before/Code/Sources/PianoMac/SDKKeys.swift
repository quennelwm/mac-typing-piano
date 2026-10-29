import Carbon
import PianoCore

// SDK constant resolution only. Physical-to-MIDI/label mapping stays in the contract JSON.
public enum SDKKeys {
    public static let codes: [String: UInt16] = [
        "kVK_ANSI_Grave": UInt16(kVK_ANSI_Grave),
        "kVK_ANSI_1": UInt16(kVK_ANSI_1),
        "kVK_ANSI_2": UInt16(kVK_ANSI_2),
        "kVK_ANSI_3": UInt16(kVK_ANSI_3),
        "kVK_ANSI_4": UInt16(kVK_ANSI_4),
        "kVK_ANSI_5": UInt16(kVK_ANSI_5),
        "kVK_ANSI_6": UInt16(kVK_ANSI_6),
        "kVK_ANSI_7": UInt16(kVK_ANSI_7),
        "kVK_ANSI_8": UInt16(kVK_ANSI_8),
        "kVK_ANSI_9": UInt16(kVK_ANSI_9),
        "kVK_ANSI_0": UInt16(kVK_ANSI_0),
        "kVK_ANSI_Minus": UInt16(kVK_ANSI_Minus),
        "kVK_ANSI_Equal": UInt16(kVK_ANSI_Equal),
        "kVK_Delete": UInt16(kVK_Delete),
        "kVK_Tab": UInt16(kVK_Tab),
        "kVK_ANSI_Q": UInt16(kVK_ANSI_Q),
        "kVK_ANSI_W": UInt16(kVK_ANSI_W),
        "kVK_ANSI_E": UInt16(kVK_ANSI_E),
        "kVK_ANSI_R": UInt16(kVK_ANSI_R),
        "kVK_ANSI_T": UInt16(kVK_ANSI_T),
        "kVK_ANSI_Y": UInt16(kVK_ANSI_Y),
        "kVK_ANSI_U": UInt16(kVK_ANSI_U),
        "kVK_ANSI_I": UInt16(kVK_ANSI_I),
        "kVK_ANSI_O": UInt16(kVK_ANSI_O),
        "kVK_ANSI_P": UInt16(kVK_ANSI_P),
        "kVK_ANSI_LeftBracket": UInt16(kVK_ANSI_LeftBracket),
        "kVK_ANSI_RightBracket": UInt16(kVK_ANSI_RightBracket),
        "kVK_ANSI_Backslash": UInt16(kVK_ANSI_Backslash),
        "kVK_CapsLock": UInt16(kVK_CapsLock),
        "kVK_ANSI_A": UInt16(kVK_ANSI_A),
        "kVK_ANSI_S": UInt16(kVK_ANSI_S),
        "kVK_ANSI_D": UInt16(kVK_ANSI_D),
        "kVK_ANSI_F": UInt16(kVK_ANSI_F),
        "kVK_ANSI_G": UInt16(kVK_ANSI_G),
        "kVK_ANSI_H": UInt16(kVK_ANSI_H),
        "kVK_ANSI_J": UInt16(kVK_ANSI_J),
        "kVK_ANSI_K": UInt16(kVK_ANSI_K),
        "kVK_ANSI_L": UInt16(kVK_ANSI_L),
        "kVK_ANSI_Semicolon": UInt16(kVK_ANSI_Semicolon),
        "kVK_ANSI_Quote": UInt16(kVK_ANSI_Quote),
        "kVK_Return": UInt16(kVK_Return),
        "kVK_Shift": UInt16(kVK_Shift),
        "kVK_ANSI_Z": UInt16(kVK_ANSI_Z),
        "kVK_ANSI_X": UInt16(kVK_ANSI_X),
        "kVK_ANSI_C": UInt16(kVK_ANSI_C),
        "kVK_ANSI_V": UInt16(kVK_ANSI_V),
        "kVK_ANSI_B": UInt16(kVK_ANSI_B),
        "kVK_ANSI_N": UInt16(kVK_ANSI_N),
        "kVK_ANSI_M": UInt16(kVK_ANSI_M),
        "kVK_ANSI_Comma": UInt16(kVK_ANSI_Comma),
        "kVK_ANSI_Period": UInt16(kVK_ANSI_Period),
        "kVK_ANSI_Slash": UInt16(kVK_ANSI_Slash),
        "kVK_RightShift": UInt16(kVK_RightShift),
        "kVK_Function": UInt16(kVK_Function),
        "kVK_Control": UInt16(kVK_Control),
        "kVK_Option": UInt16(kVK_Option),
        "kVK_Command": UInt16(kVK_Command),
        "kVK_Space": UInt16(kVK_Space),
        "kVK_RightCommand": UInt16(kVK_RightCommand),
        "kVK_RightOption": UInt16(kVK_RightOption),
        "kVK_LeftArrow": UInt16(kVK_LeftArrow),
        "kVK_DownArrow": UInt16(kVK_DownArrow),
        "kVK_UpArrow": UInt16(kVK_UpArrow),
        "kVK_RightArrow": UInt16(kVK_RightArrow),
    ]
    public static func resolve(_ mapping: KeyMapping) throws -> [UInt16: KeyMapping.Key] {
        var result: [UInt16: KeyMapping.Key] = [:]
        for key in mapping.keys {
            guard let code = codes[key.sdkConstantCandidate], result[code] == nil else {
                throw ProbeError.invalid("Unknown or repeated SDK key constant")
            }
            result[code] = key
        }
        return result
    }
}
