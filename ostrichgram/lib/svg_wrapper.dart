import 'package:flutter_svg/flutter_svg.dart';

// basic SVG wrapper

class SvgWrapper {
  final String rawSvg;

  SvgWrapper(this.rawSvg);

  Future<DrawableRoot> generateLogoSync() async {
    DrawableRoot svgRoot = await svg.fromSvgString(rawSvg, rawSvg);
    return svgRoot;
  }
}
