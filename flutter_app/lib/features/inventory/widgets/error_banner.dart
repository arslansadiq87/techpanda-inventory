import 'package:flutter/material.dart';

/// Error banner widget that displays an error message container at the top of a page.
class ErrorBanner extends StatelessWidget {
  final String errorMessage;
  final VoidCallback? onDismiss;

  const ErrorBanner({
    super.key,
    required this.errorMessage,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.onErrorContainer,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  errorMessage,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
              if (onDismiss != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: Theme.of(context).colorScheme.onErrorContainer,
                  onPressed: onDismiss,
                  tooltip: 'Dismiss error',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

