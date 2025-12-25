// Connectivity Wrapper - Shows no internet dialog when offline
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/connectivity_provider.dart';
import 'no_internet_dialog.dart';

class ConnectivityWrapper extends StatefulWidget {
  final Widget child;

  const ConnectivityWrapper({
    super.key,
    required this.child,
  });

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper> {
  bool _dialogShown = false;

  @override
  void initState() {
    super.initState();
    // Wait a bit for connectivity provider to initialize
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkConnectivity();
    });
  }

  void _checkConnectivity() {
    final connectivityProvider = Provider.of<ConnectivityProvider>(
      context,
      listen: false,
    );

    // Check if initialized
    if (!connectivityProvider.isInitialized) {
      // Retry after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _checkConnectivity();
        }
      });
      return;
    }

    // Show dialog if disconnected
    if (!connectivityProvider.isConnected && !_dialogShown) {
      _showDialog();
    } else if (connectivityProvider.isConnected && _dialogShown) {
      // Hide dialog if reconnected
      _hideDialog();
    }
  }

  void _showDialog() {
    if (!mounted || _dialogShown) return;
    
    setState(() {
      _dialogShown = true;
    });

    NoInternetDialog.show(
      context,
      onRetry: () {
        // Check connectivity again
        Provider.of<ConnectivityProvider>(context, listen: false)
            .checkConnectivity();
        Navigator.of(context).pop();
        setState(() {
          _dialogShown = false;
        });
      },
      onExit: () {
        // Exit app
        SystemNavigator.pop();
      },
    ).then((_) {
      // Dialog dismissed
      if (mounted) {
        setState(() {
          _dialogShown = false;
        });
      }
    });
  }

  void _hideDialog() {
    if (_dialogShown && mounted) {
      Navigator.of(context).pop();
      setState(() {
        _dialogShown = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityProvider>(
      builder: (context, connectivityProvider, child) {
        // Listen to connectivity changes
        if (connectivityProvider.isInitialized) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!connectivityProvider.isConnected && !_dialogShown) {
              _showDialog();
            } else if (connectivityProvider.isConnected && _dialogShown) {
              _hideDialog();
            }
          });
        }

        return widget.child;
      },
    );
  }
}

