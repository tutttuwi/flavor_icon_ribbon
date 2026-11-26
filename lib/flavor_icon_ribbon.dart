/// Draw an environment ribbon on a launcher icon in memory.
///
/// The command-line tool writes that drawing into existing Android and iOS
/// launcher PNGs. The package README describes the YAML configuration.
library;

export 'src/ribbon.dart' show RibbonStyle, composeRibbonIcon;
