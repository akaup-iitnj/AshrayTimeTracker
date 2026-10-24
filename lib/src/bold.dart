import 'package:flutter/material.dart';

/// Chronicle's look: the "Bold" theme from the Eisenhower app
/// (apps/web/src/themes.css, [data-theme='bold']) as the Diwan Android app
/// wore it. Cream paper, black ink, 2dp black outlines, hard unblurred offset
/// shadows, bright flat tiles, Archivo ExtraBold headings over DM Sans, and
/// presses that push a control into its shadow. Light only, like the original.
abstract final class Bold {
  static const paper = Color(0xFFFFFDF5);
  static const panel = Color(0xFFFFFFFF);
  static const ink = Color(0xFF111111);
  static const muted = Color(0xFF4D4D47);
  static const faint = Color(0xFF77776F);
  static const soft = Color(0xFFF1F1EA);
  static const blue = Color(0xFF3D5AFE);
  static const blueTint = Color(0xFFE3E8FF);
  static const pink = Color(0xFFFF3D7F);
  static const coral = Color(0xFFFF8A80);
  static const sky = Color(0xFF7CC4FF);
  static const yellow = Color(0xFFFFD84D);
  static const stone = Color(0xFFE4E4DC);

  static const border = 2.0;
  static const radius = 10.0;
  static const radiusSm = 6.0;
  static const shadow = 4.0;
  static const shadowSm = 2.0;

  static const outline = BorderSide(color: ink, width: border);

  static List<BoxShadow> hardShadow(double offset) => offset == 0
      ? const []
      : [BoxShadow(color: ink, offset: Offset(offset, offset))];
}

/// A style in one of the two bundled variable fonts. Flutter only moves a
/// variable font's weight axis when told, so weight and variation travel
/// together.
TextStyle boldFont(
  String family,
  int weight, {
  double? size,
  Color? color,
  double? letterSpacing,
  double? height,
}) {
  return TextStyle(
    fontFamily: family,
    fontWeight: FontWeight.values[(weight ~/ 100) - 1],
    fontVariations: [FontVariation.weight(weight.toDouble())],
    fontSize: size,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );
}

/// Archivo's heavy weights set a narrow word space; widen it so headlines
/// like "Your day" don't read as one word.
TextStyle archivo(int weight, {double? size, Color? color, double? height}) =>
    boldFont(
      'Archivo',
      weight,
      size: size,
      color: color ?? Bold.ink,
      letterSpacing: -0.2,
      height: height,
    ).copyWith(wordSpacing: (size ?? 14) * 0.12);

TextStyle dmSans(int weight, {double? size, Color? color, double? height}) =>
    boldFont('DMSans', weight, size: size, color: color, height: height);

extension BoldWeight on TextStyle? {
  /// Copies this style at another weight, moving the variable axis with it.
  TextStyle? weight(int value) => this?.copyWith(
    fontWeight: FontWeight.values[(value ~/ 100) - 1],
    fontVariations: [FontVariation.weight(value.toDouble())],
  );
}

ThemeData boldTheme() {
  final colors = const ColorScheme.light(
    primary: Bold.blue,
    onPrimary: Colors.white,
    primaryContainer: Bold.blueTint,
    onPrimaryContainer: Bold.ink,
    secondary: Bold.pink,
    onSecondary: Colors.white,
    secondaryContainer: Bold.yellow,
    onSecondaryContainer: Bold.ink,
    tertiary: Bold.sky,
    onTertiary: Bold.ink,
    error: Color(0xFFD32F2F),
    errorContainer: Bold.coral,
    onErrorContainer: Bold.ink,
    surface: Bold.panel,
    onSurface: Bold.ink,
    onSurfaceVariant: Bold.muted,
    surfaceContainerLowest: Bold.panel,
    surfaceContainerLow: Bold.paper,
    surfaceContainer: Bold.panel,
    surfaceContainerHigh: Bold.panel,
    surfaceContainerHighest: Bold.soft,
    outline: Bold.ink,
    outlineVariant: Bold.ink,
  );
  final text = TextTheme(
    displaySmall: archivo(900, size: 34),
    headlineLarge: archivo(900, size: 32),
    headlineMedium: archivo(800, size: 28),
    headlineSmall: archivo(800, size: 24),
    titleLarge: archivo(800, size: 22),
    titleMedium: dmSans(600, size: 16),
    titleSmall: dmSans(600, size: 14),
    bodyLarge: dmSans(400, size: 16),
    bodyMedium: dmSans(400, size: 14),
    bodySmall: dmSans(400, size: 13, color: Bold.muted),
    labelLarge: dmSans(700, size: 14),
    labelMedium: dmSans(700, size: 12),
    labelSmall: dmSans(700, size: 11),
  ).apply(bodyColor: Bold.ink, displayColor: Bold.ink);

  final sm = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(Bold.radiusSm),
    side: Bold.outline,
  );
  final buttonText = dmSans(700, size: 14);
  OutlineInputBorder field(double width, Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(Bold.radiusSm),
    borderSide: BorderSide(color: color, width: width),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    textTheme: text,
    fontFamily: 'DMSans',
    scaffoldBackgroundColor: Bold.paper,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    dividerTheme: const DividerThemeData(color: Bold.ink, thickness: 2),
    appBarTheme: AppBarTheme(
      backgroundColor: Bold.paper,
      surfaceTintColor: Colors.transparent,
      foregroundColor: Bold.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: archivo(800, size: 22),
      shape: const Border(bottom: Bold.outline),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Bold.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Bold.radius),
        side: Bold.outline,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Bold.blue,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Bold.soft,
        disabledForegroundColor: Bold.faint,
        textStyle: buttonText,
        shape: sm,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: Bold.panel,
        foregroundColor: Bold.ink,
        textStyle: buttonText,
        shape: sm,
        side: Bold.outline,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Bold.blue,
        textStyle: buttonText,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Bold.radiusSm),
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: Bold.ink),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: Bold.blue,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Bold.radius),
        side: Bold.outline,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Bold.panel,
      selectedColor: Bold.yellow,
      checkmarkColor: Bold.ink,
      side: const BorderSide(color: Bold.ink, width: 1.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Bold.radiusSm),
      ),
      labelStyle: dmSans(600, size: 13, color: Bold.ink),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        side: const WidgetStatePropertyAll(Bold.outline),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Bold.radiusSm),
          ),
        ),
        textStyle: WidgetStatePropertyAll(buttonText),
        foregroundColor: const WidgetStatePropertyAll(Bold.ink),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? Bold.yellow : Bold.panel,
        ),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? Colors.white : Bold.ink,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? Bold.blue : Bold.panel,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Bold.ink),
      trackOutlineWidth: const WidgetStatePropertyAll(Bold.border),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: Bold.blue,
      inactiveTrackColor: Bold.stone,
      thumbColor: Bold.ink,
      trackHeight: 6,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: Bold.blue),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Bold.panel,
      border: field(Bold.border, Bold.ink),
      enabledBorder: field(Bold.border, Bold.ink),
      focusedBorder: field(2.5, Bold.blue),
      labelStyle: dmSans(600, color: Bold.muted),
      floatingLabelStyle: dmSans(700, color: Bold.ink),
      hintStyle: dmSans(400, color: Bold.faint),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: dmSans(600, size: 15, color: Bold.ink),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Bold.panel,
        border: field(Bold.border, Bold.ink),
        enabledBorder: field(Bold.border, Bold.ink),
        focusedBorder: field(2.5, Bold.blue),
      ),
      menuStyle: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(Bold.panel),
        side: const WidgetStatePropertyAll(Bold.outline),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Bold.radiusSm),
          ),
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Bold.paper,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Bold.radius),
        side: Bold.outline,
      ),
      titleTextStyle: archivo(800, size: 22),
      contentTextStyle: dmSans(400, size: 15, color: Bold.ink),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: Bold.paper,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Bold.radius),
        side: Bold.outline,
      ),
      headerHeadlineStyle: archivo(800, size: 28),
      todayBorder: Bold.outline,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Bold.ink,
      contentTextStyle: dmSans(600, color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Bold.radiusSm),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: Bold.ink,
      titleTextStyle: dmSans(600, size: 16, color: Bold.ink),
      subtitleTextStyle: dmSans(400, size: 13, color: Bold.muted),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Bold.paper,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: Bold.yellow,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Bold.radiusSm),
        side: Bold.outline,
      ),
      iconTheme: const WidgetStatePropertyAll(IconThemeData(color: Bold.ink)),
      labelTextStyle: WidgetStatePropertyAll(dmSans(700, size: 12)),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Bold.paper,
      indicatorColor: Bold.yellow,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Bold.radiusSm),
        side: Bold.outline,
      ),
      selectedIconTheme: const IconThemeData(color: Bold.ink),
      unselectedIconTheme: const IconThemeData(color: Bold.ink),
      selectedLabelTextStyle: dmSans(800, size: 12, color: Bold.ink),
      unselectedLabelTextStyle: dmSans(600, size: 12, color: Bold.muted),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: Bold.blue,
      selectionColor: Bold.blueTint,
      selectionHandleColor: Bold.blue,
    ),
  );
}

/// The Bold surface: a flat fill, a 2dp black outline and a hard shadow.
/// With [onTap] it lifts on hover and presses into its shadow on tap.
class BoldCard extends StatefulWidget {
  const BoldCard({
    super.key,
    required this.child,
    this.color = Bold.panel,
    this.onTap,
    this.shadow = Bold.shadow,
    this.radius = Bold.radius,
    this.padding,
    this.semanticLabel,
  });

  final Widget child;
  final Color color;
  final VoidCallback? onTap;
  final double shadow;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final String? semanticLabel;

  @override
  State<BoldCard> createState() => _BoldCardState();
}

class _BoldCardState extends State<BoldCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onTap != null;
    final pressed = interactive && _pressed;
    final offset = pressed ? widget.shadow : 0.0;
    Widget box = AnimatedContainer(
      duration: const Duration(milliseconds: 90),
      transform: Matrix4.translationValues(offset, offset, 0),
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(color: Bold.ink, width: Bold.border),
        boxShadow: Bold.hardShadow(pressed ? 0 : widget.shadow),
      ),
      padding: widget.padding,
      // Tiles and ink inside paint on this, not hidden under the fill.
      child: Material(type: MaterialType.transparency, child: widget.child),
    );
    if (interactive) {
      box = Semantics(
        button: true,
        label: widget.semanticLabel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          onTap: widget.onTap,
          child: MouseRegion(cursor: SystemMouseCursors.click, child: box),
        ),
      );
    }
    // Leave room for the shadow so neighbours never overlap it.
    return Padding(
      padding: EdgeInsets.only(right: widget.shadow, bottom: widget.shadow),
      child: box,
    );
  }
}

/// The main action: a solid tile that presses into its shadow.
class BoldButton extends StatelessWidget {
  const BoldButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = Bold.blue,
    this.foreground = Colors.white,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final Color color;
  final Color foreground;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final ink = enabled ? foreground : Bold.faint;
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          IconTheme(
            data: IconThemeData(color: ink, size: 20),
            child: icon!,
          ),
          const SizedBox(width: 8),
        ],
        Text(label, style: dmSans(800, size: 16, color: ink)),
      ],
    );
    return Semantics(
      button: true,
      enabled: enabled,
      child: BoldCard(
        color: enabled ? color : Bold.soft,
        radius: Bold.radiusSm,
        shadow: enabled ? Bold.shadow : 0,
        onTap: onPressed,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: content,
      ),
    );
  }
}

/// A small outlined label with a flat fill.
class BoldTag extends StatelessWidget {
  const BoldTag({
    super.key,
    required this.label,
    this.color = Bold.yellow,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Bold.ink, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: Bold.ink),
            const SizedBox(width: 4),
          ],
          Text(label, style: dmSans(700, size: 11, color: Bold.ink)),
        ],
      ),
    );
  }
}

/// Bold's chunky outlined progress bar.
class BoldProgress extends StatelessWidget {
  const BoldProgress({
    super.key,
    required this.value,
    this.color = Bold.blue,
    this.height = 16,
  });

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final fraction = value.clamp(0.0, 1.0);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Bold.panel,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Bold.ink, width: Bold.border),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: fraction,
          heightFactor: 1,
          child: fraction == 0
              ? null
              : DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                    border: const Border(right: Bold.outline),
                  ),
                ),
        ),
      ),
    );
  }
}

/// Chronicle's mark, "Hours to blocks": an hourglass whose sand lands as
/// hour blocks. The image comes from tool/brand/build_icons.py, the same
/// source as the launcher and browser icons, and carries its own tile,
/// outline and shadow.
class ChronicleMark extends StatelessWidget {
  const ChronicleMark({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Chronicle',
      image: true,
      child: Image.asset(
        'assets/brand/chronicle-icon.png',
        width: size,
        height: size,
        filterQuality: FilterQuality.medium,
        excludeFromSemantics: true,
      ),
    );
  }
}

/// A category as Eisenhower's Bold chips draw it: white, outlined, with the
/// category's colour as a dot.
class CategoryChip extends StatelessWidget {
  const CategoryChip({super.key, required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Bold.panel,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Bold.ink, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Bold.ink),
            ),
          ),
          const SizedBox(width: 5),
          Text(name, style: dmSans(700, size: 11, color: Bold.ink)),
        ],
      ),
    );
  }
}

/// The productive rating as a tag: sky for productive, coral for not.
class ProductiveTag extends StatelessWidget {
  const ProductiveTag({super.key, required this.productive});

  final bool productive;

  @override
  Widget build(BuildContext context) {
    return BoldTag(
      label: productive ? 'Productive' : 'Not productive',
      color: productive ? Bold.sky : Bold.coral,
      icon: productive
          ? Icons.thumb_up_alt_rounded
          : Icons.thumb_down_alt_rounded,
    );
  }
}
