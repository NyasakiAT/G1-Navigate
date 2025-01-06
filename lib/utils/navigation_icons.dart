class NavigationIcons {
  static const String fork_left = """^  
\\ /
 Y """;

static const String fork_right = """  ^
\\ /
 Y """;

static const String keep_left = """^ |
| |
| |""";

static const String keep_right = """| ^
| |
| |""";

static const String merge_left = """^  
|\\ 
| |""";

static const String merge_right = """  ^
 /|
| |""";

static const String ramp_right = """| ^
|/ 
|  """;

static const String ramp_left = """^ |
 \\|
  |""";

static const String sharp_left = """<--
  |
   """;

static const String sharp_right = """-->
|  
   """;

static const String slight_left = """^  
 \\ 
  |""";

static const String slight_right = """  ^
 / 
|  """;

static const String straight = """ ^ 
 | 
 | """;

static const String turn_left = """
<--
   """;

static const String turn_right = """
-->
   """;

// Mapping string names to constants
  static const Map<String, String> icons = {
    "fork_left": fork_left,
    "fork_right": fork_right,
    "keep_left": keep_left,
    "keep_right": keep_right,
    "merge_left": merge_left,
    "merge_right": merge_right,
    "ramp_right": ramp_right,
    "ramp_left": ramp_left,
    "sharp_left": sharp_left,
    "sharp_right": sharp_right,
    "slight_left": slight_left,
    "slight_right": slight_right,
    "straight": straight,
    "turn_left": turn_left,
    "turn_right": turn_right,
  };

  static String getIcon(String name) {
    return icons[name] ?? "NOT\nFND\n   ";
  }

}
