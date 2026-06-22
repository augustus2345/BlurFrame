import 'package:flutter/material.dart';

/// Lightweight shared scaffold wrapper for non-shell screens
/// (e.g. detail pages pushed on top of the bottom-nav shell).
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.title,
    required this.child,
    this.actions,
    this.leading,
    this.floatingActionButton,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;
  final Widget? leading;
  final Widget? floatingActionButton;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: actions,
        leading: leading,
      ),
      floatingActionButton: floatingActionButton,
      body: Padding(padding: padding, child: child),
    );
  }
}