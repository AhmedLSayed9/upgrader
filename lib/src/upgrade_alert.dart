/*
 * Copyright (c) 2021-2023 Larry Aasen. All rights reserved.
 */

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'upgrade_messages.dart';
import 'upgrader.dart';

/// There are two different dialog styles: Cupertino and Material
enum UpgradeDialogStyle { cupertino, material }

/// A widget to display the upgrade dialog.
/// Override the [createState] method to provide a custom class
/// with overridden methods.
class UpgradeAlert extends StatefulWidget {
  /// Creates a new [UpgradeAlert].
  UpgradeAlert({
    super.key,
    Upgrader? upgrader,
    this.canDismissDialog = false,
    this.dialogStyle = UpgradeDialogStyle.material,
    this.onIgnore,
    this.onLater,
    this.onUpdate,
    this.shouldPopScope,
    this.showIgnore = true,
    this.showLater = true,
    this.showReleaseNotes = true,
    this.cupertinoButtonTextStyle,
    this.navigatorKey,
    this.child,
  }) : upgrader = upgrader ?? Upgrader.sharedInstance;

  /// The upgraders used to configure the upgrade dialog.
  final Upgrader upgrader;

  /// Can alert dialog be dismissed on tap outside of the alert dialog. Not used by [UpgradeCard]. (default: false)
  final bool canDismissDialog;

  /// The upgrade dialog style. Used only on UpgradeAlert. (default: material)
  final UpgradeDialogStyle dialogStyle;

  /// Called when the ignore button is tapped or otherwise activated.
  /// Return false when the default behavior should not execute.
  final BoolCallback? onIgnore;

  /// Called when the later button is tapped or otherwise activated.
  final BoolCallback? onLater;

  /// Called when the update button is tapped or otherwise activated.
  /// Return false when the default behavior should not execute.
  final BoolCallback? onUpdate;

  /// Called when the user taps outside of the dialog and [canDismissDialog]
  /// is false. Also called when the back button is pressed. Return true for
  /// the screen to be popped.
  final BoolCallback? shouldPopScope;

  /// Hide or show Ignore button on dialog (default: true)
  final bool showIgnore;

  /// Hide or show Later button on dialog (default: true)
  final bool showLater;

  /// Hide or show release notes (default: true)
  final bool showReleaseNotes;

  /// The text style for the cupertino dialog buttons. Used only for
  /// [UpgradeDialogStyle.cupertino]. Optional.
  final TextStyle? cupertinoButtonTextStyle;

  /// For use by the Router architecture as part of the RouterDelegate.
  final GlobalKey<NavigatorState>? navigatorKey;

  /// The [child] contained by the widget.
  final Widget? child;

  @override
  UpgradeAlertState createState() => UpgradeAlertState();
}

/// The [UpgradeAlert] widget state.
class UpgradeAlertState extends State<UpgradeAlert> {
  /// Is the alert dialog being displayed right now?
  bool displayed = false;

  late Upgrader _upgrader;

  @override
  void initState() {
    super.initState();
    _initUpgrader();
  }

  @override
  void dispose() {
    _upgrader.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant UpgradeAlert oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.upgrader.minAppVersion != oldWidget.upgrader.minAppVersion) {
      oldWidget.upgrader.dispose();
      _initUpgrader();
    }
  }

  void _initUpgrader() {
    _upgrader = widget.upgrader;
    _upgrader.initialize();
  }

  /// Describes the part of the user interface represented by this widget.
  @override
  Widget build(BuildContext context) {
    if (_upgrader.debugLogging) {
      print('upgrader: build UpgradeAlert');
    }

    return StreamBuilder(
      // The key is necessary until https://github.com/flutter/flutter/issues/64916 is fixed.
      key: ValueKey(_upgrader.hashCode),
      initialData: _upgrader.evaluationReady,
      stream: _upgrader.evaluationStream,
      builder:
          (BuildContext context, AsyncSnapshot<UpgraderEvaluateNeed> snapshot) {
        if ((snapshot.connectionState == ConnectionState.waiting ||
                snapshot.connectionState == ConnectionState.active) &&
            snapshot.data != null &&
            snapshot.data!) {
          if (_upgrader.debugLogging) {
            print("upgrader: need to evaluate version");
          }

          if (!displayed) {
            final checkContext = widget.navigatorKey != null &&
                    widget.navigatorKey!.currentContext != null
                ? widget.navigatorKey!.currentContext!
                : context;
            checkVersion(context: checkContext);
          }
        }
        return widget.child ?? const SizedBox.shrink();
      },
    );
  }

  /// Will show the alert dialog when it should be dispalyed.
  /// Only called by [UpgradeAlert] and not used by [UpgradeCard].
  void checkVersion({required BuildContext context}) {
    final shouldDisplay = _upgrader.shouldDisplayUpgrade();
    if (_upgrader.debugLogging) {
      print('upgrader: shouldDisplayReleaseNotes: shouldDisplayReleaseNotes');
    }
    if (shouldDisplay) {
      displayed = true;
      final appMessages = _upgrader.determineMessages(context);

      Future.delayed(const Duration(milliseconds: 0), () {
        showTheDialog(
          context: context,
          title: appMessages.message(UpgraderMessage.title),
          message: _upgrader.body(appMessages),
          releaseNotes:
              shouldDisplayReleaseNotes ? _upgrader.releaseNotes : null,
          canDismissDialog: widget.canDismissDialog,
          messages: appMessages,
        );
      });
    }
  }

  void onUserIgnored(BuildContext context, bool shouldPop) {
    if (_upgrader.debugLogging) {
      print('upgrader: button tapped: ignore');
    }

    // If this callback has been provided, call it.
    final doProcess = widget.onIgnore?.call() ?? true;

    if (doProcess) {
      _upgrader.saveIgnored();
    }

    if (shouldPop) {
      popNavigator(context);
    }
  }

  void onUserLater(BuildContext context, bool shouldPop) {
    if (_upgrader.debugLogging) {
      print('upgrader: button tapped: later');
    }

    // If this callback has been provided, call it.
    widget.onLater?.call();

    if (shouldPop) {
      popNavigator(context);
    }
  }

  void onUserUpdated(BuildContext context, bool shouldPop) {
    if (_upgrader.debugLogging) {
      print('upgrader: button tapped: update now');
    }

    // If this callback has been provided, call it.
    final doProcess = widget.onUpdate?.call() ?? true;

    if (doProcess) {
      _upgrader.sendUserToAppStore();
    }

    if (shouldPop) {
      popNavigator(context);
    }
  }

  void popNavigator(BuildContext context) {
    Navigator.of(context).pop();
    displayed = false;
  }

  bool get shouldDisplayReleaseNotes =>
      widget.showReleaseNotes && (_upgrader.releaseNotes?.isNotEmpty ?? false);

  /// Show the alert dialog.
  void showTheDialog({
    required BuildContext context,
    required String? title,
    required String message,
    required String? releaseNotes,
    required bool canDismissDialog,
    required UpgraderMessages messages,
  }) {
    if (_upgrader.debugLogging) {
      print('upgrader: showTheDialog title: $title');
      print('upgrader: showTheDialog message: $message');
      print('upgrader: showTheDialog releaseNotes: $releaseNotes');
    }

    // Save the date/time as the last time alerted.
    _upgrader.saveLastAlerted();

    showDialog(
      barrierDismissible: canDismissDialog,
      context: context,
      builder: (BuildContext context) {
        return WillPopScope(
            onWillPop: () async => onWillPop(),
            child: alertDialog(
              title ?? '',
              message,
              releaseNotes,
              context,
              widget.dialogStyle == UpgradeDialogStyle.cupertino,
              messages,
            ));
      },
    );
  }

  /// Called when the user taps outside of the dialog and [canDismissDialog]
  /// is false. Also called when the back button is pressed. Return true for
  /// the screen to be popped. Defaults to false.
  bool onWillPop() {
    if (_upgrader.debugLogging) {
      print('upgrader: onWillPop called');
    }
    if (widget.shouldPopScope != null) {
      final should = widget.shouldPopScope!();
      if (_upgrader.debugLogging) {
        print('upgrader: shouldPopScope=$should');
      }
      return should;
    }

    return false;
  }

  Widget alertDialog(String title, String message, String? releaseNotes,
      BuildContext context, bool cupertino, UpgraderMessages messages) {
    // If installed version is below minimum app version, or is a critical update,
    // disable ignore and later buttons.
    final isBlocked = _upgrader.blocked();
    final showIgnore = isBlocked ? false : widget.showIgnore;
    final showLater = isBlocked ? false : widget.showLater;

    Widget? notes;
    if (releaseNotes != null) {
      notes = Padding(
          padding: const EdgeInsets.only(top: 15.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: cupertino
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: <Widget>[
              Text(messages.message(UpgraderMessage.releaseNotes) ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(releaseNotes),
            ],
          ));
    }
    final textTitle = Text(title, key: const Key('upgrader.dialog.title'));
    final content = Container(
        constraints: const BoxConstraints(maxHeight: 400),
        child: SingleChildScrollView(
            child: Column(
          crossAxisAlignment:
              cupertino ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(message),
            Padding(
                padding: const EdgeInsets.only(top: 15.0),
                child: Text(messages.message(UpgraderMessage.prompt) ?? '')),
            if (notes != null) notes,
          ],
        )));
    final actions = <Widget>[
      if (showIgnore)
        button(cupertino, messages.message(UpgraderMessage.buttonTitleIgnore),
            context, () => onUserIgnored(context, true)),
      if (showLater)
        button(cupertino, messages.message(UpgraderMessage.buttonTitleLater),
            context, () => onUserLater(context, true)),
      button(cupertino, messages.message(UpgraderMessage.buttonTitleUpdate),
          context, () => onUserUpdated(context, !_upgrader.blocked())),
    ];

    return cupertino
        ? CupertinoAlertDialog(
            title: textTitle, content: content, actions: actions)
        : AlertDialog(title: textTitle, content: content, actions: actions);
  }

  Widget button(bool cupertino, String? text, BuildContext context,
      VoidCallback? onPressed) {
    return cupertino
        ? CupertinoDialogAction(
            textStyle: widget.cupertinoButtonTextStyle,
            onPressed: onPressed,
            child: Text(text ?? ''))
        : TextButton(onPressed: onPressed, child: Text(text ?? ''));
  }
}
