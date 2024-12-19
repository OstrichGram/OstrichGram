import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/widgets.dart';

class SvgWrapper {
  final String rawSvg;

  SvgWrapper(this.rawSvg);

  // Return an SvgPicture widget instead of DrawableRoot
  Widget generateLogoSync() {
    return SvgPicture.string(rawSvg);
  }
}


