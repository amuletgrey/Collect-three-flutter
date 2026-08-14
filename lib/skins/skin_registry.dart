import 'package:flutter/widgets.dart';

import 'skin.dart';

/// Every skin the game ships with. Palettes and the rules they must satisfy are
/// documented in docs/SKINS.md; `test/skins/skin_contract_test.dart` checks them.
class SkinRegistry {
  const SkinRegistry._();

  static const String classicArcadeId = 'classic_arcade';
  static const String treasureHuntId = 'treasure_hunt';
  static const String candyShopId = 'candy_shop';

  static const List<Skin> all = [classicArcade, treasureHunt, candyShop];

  static const Skin defaultSkin = classicArcade;

  static Skin byId(String? id) =>
      all.firstWhere((skin) => skin.id == id, orElse: () => defaultSkin);

  // ---------------------------------------------------------------- classic

  static const Skin classicArcade = Skin(
    id: classicArcadeId,
    name: 'Classic Arcade',
    tagline: 'Glossy balls in a dark cabinet.',
    supportsSymbols: true,
    palette: SkinPalette(
      backgroundTop: Color(0xFF0B0E1A),
      backgroundBottom: Color(0xFF161C33),
      boardFrame: Color(0xFF2A3350),
      boardCell: Color(0x14FFFFFF),
      accent: Color(0xFF21E6C1),
      textPrimary: Color(0xFFFFFFFF),
      textSecondary: Color(0xFFA7B0C8),
      danger: Color(0xFFFF4D4D),
      hint: Color(0xFF7CF9FF),
    ),
    kinds: [
      TileArt(
        name: 'Red',
        primary: Color(0xFFFF4D4D),
        secondary: Color(0xFFFF9B9B),
        family: TileFamily.sphere,
        shape: TileShape.sphere,
        symbol: TileSymbol.dot,
      ),
      TileArt(
        name: 'Blue',
        primary: Color(0xFF2E8BFF),
        secondary: Color(0xFF8FC4FF),
        family: TileFamily.sphere,
        shape: TileShape.sphere,
        symbol: TileSymbol.cross,
      ),
      TileArt(
        name: 'Green',
        primary: Color(0xFF3ED860),
        secondary: Color(0xFF9BF0AE),
        family: TileFamily.sphere,
        shape: TileShape.sphere,
        symbol: TileSymbol.triangle,
      ),
      TileArt(
        name: 'Yellow',
        primary: Color(0xFFFFD23F),
        secondary: Color(0xFFFFEBA3),
        family: TileFamily.sphere,
        shape: TileShape.sphere,
        symbol: TileSymbol.star,
      ),
      TileArt(
        name: 'Purple',
        primary: Color(0xFFA45DFF),
        secondary: Color(0xFFD3B0FF),
        family: TileFamily.sphere,
        shape: TileShape.sphere,
        symbol: TileSymbol.square,
      ),
      TileArt(
        name: 'Teal',
        primary: Color(0xFF21E6C1),
        secondary: Color(0xFF9BF5E5),
        family: TileFamily.sphere,
        shape: TileShape.sphere,
        symbol: TileSymbol.ring,
      ),
      TileArt(
        name: 'Orange',
        primary: Color(0xFFFF8A3D),
        secondary: Color(0xFFFFC49B),
        family: TileFamily.sphere,
        shape: TileShape.sphere,
        symbol: TileSymbol.diamond,
      ),
    ],
  );

  // --------------------------------------------------------------- treasure

  static const Skin treasureHunt = Skin(
    id: treasureHuntId,
    name: 'Treasure Hunt',
    tagline: 'Cut gemstones by torchlight.',
    palette: SkinPalette(
      backgroundTop: Color(0xFF221A14),
      backgroundBottom: Color(0xFF3B2A1C),
      boardFrame: Color(0xFF4A3722),
      boardCell: Color(0x33000000),
      accent: Color(0xFFE8C36B),
      textPrimary: Color(0xFFF5E8D0),
      textSecondary: Color(0xFFC2A882),
      danger: Color(0xFFE0553C),
      hint: Color(0xFFFFE9A3),
    ),
    kinds: [
      TileArt(
        name: 'Ruby',
        primary: Color(0xFFE03050),
        secondary: Color(0xFFFF7A90),
        family: TileFamily.gem,
        shape: TileShape.roundBrilliant,
      ),
      TileArt(
        name: 'Sapphire',
        primary: Color(0xFF2B6CE8),
        secondary: Color(0xFF7FA8FF),
        family: TileFamily.gem,
        shape: TileShape.emeraldCut,
      ),
      TileArt(
        name: 'Emerald',
        primary: Color(0xFF22A85A),
        secondary: Color(0xFF74E3A2),
        family: TileFamily.gem,
        shape: TileShape.marquise,
      ),
      TileArt(
        name: 'Topaz',
        primary: Color(0xFFF2B23A),
        secondary: Color(0xFFFFD98A),
        family: TileFamily.gem,
        shape: TileShape.trillion,
      ),
      TileArt(
        name: 'Amethyst',
        primary: Color(0xFF9450D8),
        secondary: Color(0xFFC99BFF),
        family: TileFamily.gem,
        shape: TileShape.pear,
      ),
      TileArt(
        name: 'Diamond',
        primary: Color(0xFFA8E6F0),
        secondary: Color(0xFFEAFBFF),
        family: TileFamily.gem,
        shape: TileShape.heart,
      ),
      TileArt(
        name: 'Onyx',
        primary: Color(0xFF4A4458),
        secondary: Color(0xFF8A80A0),
        family: TileFamily.gem,
        shape: TileShape.kite,
      ),
    ],
  );

  // ------------------------------------------------------------------ candy

  static const Skin candyShop = Skin(
    id: candyShopId,
    name: 'Candy Shop',
    tagline: 'Sweets on a pastel counter.',
    palette: SkinPalette(
      backgroundTop: Color(0xFFFFF3F8),
      backgroundBottom: Color(0xFFFFE0EE),
      boardFrame: Color(0xFF7FD8B0),
      boardCell: Color(0x66FFFFFF),
      accent: Color(0xFFFF5C8A),
      textPrimary: Color(0xFF4A3346),
      textSecondary: Color(0xFF8C7286),
      danger: Color(0xFFFF5C5C),
      hint: Color(0xFF6A2B7A),
    ),
    kinds: [
      TileArt(
        name: 'Strawberry',
        primary: Color(0xFFFF5C8A),
        secondary: Color(0xFFFFFFFF),
        family: TileFamily.candy,
        shape: TileShape.lollipop,
      ),
      TileArt(
        name: 'Blueberry',
        primary: Color(0xFF4C7DF0),
        secondary: Color(0xFFBFD4FF),
        family: TileFamily.candy,
        shape: TileShape.wrapped,
      ),
      TileArt(
        name: 'Lime',
        primary: Color(0xFF6BD44A),
        secondary: Color(0xFFD2F5C4),
        family: TileFamily.candy,
        shape: TileShape.jellyBean,
      ),
      TileArt(
        name: 'Lemon',
        // Deeper than a true lemon on purpose: the pale counter background
        // washes out anything lighter. See the contrast rule in docs/SKINS.md.
        primary: Color(0xFFF5B31E),
        secondary: Color(0xFFFFF0BF),
        family: TileFamily.candy,
        shape: TileShape.gumdrop,
      ),
      TileArt(
        name: 'Grape',
        primary: Color(0xFFB15CFF),
        secondary: Color(0xFFFFFFFF),
        family: TileFamily.candy,
        shape: TileShape.peppermint,
      ),
      TileArt(
        name: 'Chocolate',
        primary: Color(0xFF8A5A3C),
        secondary: Color(0xFFC08A63),
        family: TileFamily.candy,
        shape: TileShape.chocolate,
      ),
      TileArt(
        name: 'Liquorice',
        primary: Color(0xFF3D3A46),
        secondary: Color(0xFFF0EDF5),
        family: TileFamily.candy,
        shape: TileShape.liquorice,
      ),
    ],
  );
}
