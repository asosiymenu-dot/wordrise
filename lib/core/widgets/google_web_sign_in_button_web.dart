import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as google_web;

Widget buildGoogleWebSignInButton({
  required String locale,
  double minimumWidth = 320,
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth.isFinite
          ? constraints.maxWidth.clamp(120.0, 400.0)
          : minimumWidth.clamp(120.0, 400.0);
      return SizedBox(
        height: 44,
        child: Center(
          child: google_web.renderButton(
            configuration: google_web.GSIButtonConfiguration(
              type: google_web.GSIButtonType.standard,
              theme: google_web.GSIButtonTheme.outline,
              size: google_web.GSIButtonSize.large,
              text: google_web.GSIButtonText.continueWith,
              shape: google_web.GSIButtonShape.rectangular,
              logoAlignment: google_web.GSIButtonLogoAlignment.left,
              minimumWidth: width.toDouble(),
              locale: locale,
            ),
          ),
        ),
      );
    },
  );
}
