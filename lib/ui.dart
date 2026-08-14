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
