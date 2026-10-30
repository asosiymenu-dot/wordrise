import 'package:flutter/widgets.dart';

import '../../services/api_service.dart';
import '../localization/app_localizations.dart';

String userFacingError(BuildContext context, Object? error) {
  final l10n = context.l10n;
  if (error is ApiException) {
    if (error.isNetwork) return l10n.t('common.networkError');
    if (error.isUnauthorized) return l10n.t('common.sessionExpired');
    if (error.type == ApiExceptionType.badResponse) {
      return l10n.t('common.badResponse');
    }
    final status = error.statusCode ?? 0;
    final message = _clean(error.message);
    if (status >= 400 &&
        status < 500 &&
        !_looksTechnical(message) &&
        message.length <= 180) {
      return message;
    }
    return l10n.t('common.unexpectedError');
  }

  if (error is String) {
    final message = _clean(error);
    if (message.isEmpty) return l10n.t('common.unexpectedError');
    if (_looksLikeNetworkError(message)) return l10n.t('common.networkError');
    if (_looksTechnical(message)) return l10n.t('common.unexpectedError');
    return message;
  }

  return l10n.t('common.unexpectedError');
}

String _clean(String value) {
  return value
      .replaceFirst(RegExp(r'^ApiException:\s*'), '')
      .replaceFirst(RegExp(r'^Exception:\s*'), '')
      .trim();
}

bool _looksLikeNetworkError(String value) {
  final lower = value.toLowerCase();
  return lower.contains('socketexception') ||
      lower.contains('clientexception') ||
      lower.contains('failed host') ||
      lower.contains('network is unreachable') ||
      lower.contains('connection refused') ||
      lower.contains('xmlhttprequest');
}

bool _looksTechnical(String value) {
  final lower = value.toLowerCase();
  return _looksLikeNetworkError(value) ||
      lower.contains('stack trace') ||
      lower.contains('formatexception') ||
      lower.contains('typeerror') ||
      lower.contains('sqlexception') ||
      lower.contains('pdoexception') ||
      lower.contains('errno') ||
      lower.contains('uri=http') ||
      lower.contains('https://') ||
      lower.contains('/var/www/') ||
      lower.contains('package:');
}
