import 'package:flutter/material.dart';

import 'store.dart';
import 'theme.dart';

/// Gives every widget the store and the resolved palette.
class AppScope extends InheritedNotifier<Store> {
  final AppColors colors;

  const AppScope({super.key, required Store store, required this.colors, required super.child})
      : super(notifier: store);

  static Store of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppColors colorsOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.colors;

  @override
  bool updateShouldNotify(covariant InheritedNotifier<Store> oldWidget) => true;
}

/// The rounded surface card used everywhere.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final double radius;

  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.radius = 18,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    return Material(
      color: color ?? c.surf,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 10),
      child: Text(text.toUpperCase(),
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: c.txt3)),
    );
  }
}

class SwitchRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const SwitchRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: c.txt)),
            const SizedBox(height: 3),
            Text(subtitle, style: TextStyle(fontSize: 12, color: c.txt3)),
          ]),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: c.accTxt,
          activeTrackColor: c.acc,
          inactiveThumbColor: c.txt3,
          inactiveTrackColor: c.surf2,
          trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
        ),
      ]),
    );
  }
}

class NavRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const NavRow({super.key, required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    return Panel(
      onTap: onTap,
      child: Row(children: [
        Icon(icon, size: 21, color: c.acc),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: c.txt)),
            const SizedBox(height: 3),
            Text(subtitle, style: TextStyle(fontSize: 12, color: c.txt3)),
          ]),
        ),
        Icon(Icons.chevron_right, size: 20, color: c.txt3),
      ]),
    );
  }
}

/// The segmented control used for theme, layout and zoom choices.
class Segmented<T> extends StatelessWidget {
  final List<T> values;
  final List<String> labels;
  final T value;
  final ValueChanged<T> onChanged;

  const Segmented({
    super.key,
    required this.values,
    required this.labels,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: c.surf2, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(values[i]),
                child: Container(
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: values[i] == value ? c.acc : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(labels[i],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: values[i] == value ? c.accTxt : c.txt2,
                      )),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ScreenTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const ScreenTitle({super.key, required this.title, required this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 22, 18, 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: c.txt)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 13.5, color: c.txt2)),
          ]),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  const EmptyState({super.key, required this.icon, required this.title, required this.body, this.action});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 90, 30, 0),
      child: Column(children: [
        Icon(icon, size: 46, color: c.acc),
        const SizedBox(height: 18),
        Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: c.txt)),
        const SizedBox(height: 10),
        Text(body, textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, height: 1.5, color: c.txt2)),
        if (action != null) ...[const SizedBox(height: 24), action!],
      ]),
    );
  }
}

/// A big rounded primary button.
class PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final Color? background;
  final Color? foreground;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.background,
    this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    return Material(
      color: background ?? c.acc,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 54,
          alignment: Alignment.center,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[Icon(icon, size: 21, color: foreground ?? c.accTxt), const SizedBox(width: 9)],
            Text(label,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: foreground ?? c.accTxt)),
          ]),
        ),
      ),
    );
  }
}

/// Small pill used for durations, ±5/±15 steps and quick times.
class PillButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double height;

  const PillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.height = 44,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    return Material(
      color: selected ? c.acc : c.surf2,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: height,
          alignment: Alignment.center,
          child: Text(label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: selected ? c.accTxt : c.txt,
              )),
        ),
      ),
    );
  }
}

/// A red row for something that cannot simply be tapped back.
class DangerRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const DangerRow({super.key, required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    return Material(
      color: c.danger.withOpacity(c.isDark ? 0.14 : 0.10),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: SizedBox(
          height: 54,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 20, color: c.danger),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.danger)),
          ]),
        ),
      ),
    );
  }
}

/// Asks before anything that replaces or removes a lot at once. Resolves to
/// false if the dialog is dismissed any other way.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
  bool danger = false,
}) async {
  final c = AppScope.colorsOf(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialog) => Dialog(
      backgroundColor: c.surf,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: c.txt)),
          const SizedBox(height: 10),
          Text(body, style: TextStyle(fontSize: 14, height: 1.5, color: c.txt2)),
          const SizedBox(height: 22),
          Row(children: [
            Expanded(
              child: PrimaryButton(
                label: 'Cancel',
                background: c.surf2,
                foreground: c.txt2,
                onTap: () => Navigator.pop(dialog, false),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: PrimaryButton(
                label: action,
                background: danger ? c.danger : c.acc,
                foreground: danger ? c.onDanger : c.accTxt,
                onTap: () => Navigator.pop(dialog, true),
              ),
            ),
          ]),
        ]),
      ),
    ),
  );
  return ok ?? false;
}

/// A short message at the foot of the screen.
void showNotice(BuildContext context, String message, {bool bad = false}) {
  final c = AppScope.colorsOf(context);
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      backgroundColor: c.surf2,
      behavior: SnackBarBehavior.floating,
      duration: Duration(milliseconds: bad ? 4200 : 2400),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      content: Row(children: [
        Icon(bad ? Icons.error_outline : Icons.check_circle, size: 19, color: bad ? c.danger : c.acc),
        const SizedBox(width: 9),
        Expanded(
          child: Text(message, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: c.txt)),
        ),
      ]),
    ));
}

/// The colour something wears: its own, or the accent when item colours are
/// switched off in Settings.
Color toneOf(BuildContext context, int? color) {
  final c = AppScope.colorsOf(context);
  return AppScope.of(context).blockColorIcons ? c.item(color) : c.acc;
}

/// [tone] laid thinly over the card surface: the tint a card takes when the
/// thing on it is done, selected or simply has a colour of its own.
Color washOf(AppColors c, Color tone, [double strength = 1]) =>
    Color.alphaBlend(tone.withOpacity((c.isDark ? 0.13 : 0.10) * strength), c.surf);

/// A rounded tile holding an icon in its colour.
class IconTile extends StatelessWidget {
  final IconData icon;
  final Color tone;
  final double size;

  const IconTile({super.key, required this.icon, required this.tone, this.size = 46});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tone.withOpacity(c.isDark ? 0.18 : 0.14),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, size: size * 0.5, color: tone),
    );
  }
}

/// The round tick used wherever something is marked done. The touch area is
/// larger than the ring it draws, and the tick eases in rather than snapping.
class CheckCircle extends StatelessWidget {
  final bool done;
  final Color color;
  final double size;
  final VoidCallback onTap;
  final String label;

  const CheckCircle({
    super.key,
    required this.done,
    required this.color,
    required this.onTap,
    this.size = 30,
    this.label = 'Done',
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      checked: done,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(size >= 44 ? 2 : 8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: done ? color : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: size >= 40 ? 3 : 2.5),
            ),
            child: AnimatedScale(
              scale: done ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutBack,
              child: Icon(Icons.check, size: size * 0.58, color: AppColors.onColor(color)),
            ),
          ),
        ),
      ),
    );
  }
}

/// A ring that fills as the day's count is met, with the count inside it.
class ProgressRing extends StatelessWidget {
  final double value;
  final String label;
  final Color? color;

  const ProgressRing({super.key, required this.value, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.colorsOf(context);
    return SizedBox(
      width: 50,
      height: 50,
      child: Stack(alignment: Alignment.center, children: [
        SizedBox(
          width: 46,
          height: 46,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.clamp(0, 1).toDouble()),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
            builder: (_, v, __) => CircularProgressIndicator(
              value: v,
              strokeWidth: 4.5,
              strokeCap: StrokeCap.round,
              backgroundColor: c.surf2,
              valueColor: AlwaysStoppedAnimation(color ?? c.acc),
            ),
          ),
        ),
        Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: c.txt)),
      ]),
    );
  }
}
