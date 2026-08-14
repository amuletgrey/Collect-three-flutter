/// Board dimensions and how many tile kinds are in play.
class GridConfig {
  const GridConfig({
    required this.rows,
    required this.cols,
    required this.kindCount,
  }) : assert(rows >= 3 && cols >= 3, 'a board smaller than 3x3 cannot match'),
       assert(
         kindCount >= 3 && kindCount <= 7,
         'skins ship artwork for 3..7 kinds',
       );

  final int rows;
  final int cols;
  final int kindCount;

  int get cellCount => rows * cols;

  GridConfig copyWith({int? rows, int? cols, int? kindCount}) => GridConfig(
    rows: rows ?? this.rows,
    cols: cols ?? this.cols,
    kindCount: kindCount ?? this.kindCount,
  );

  @override
  bool operator ==(Object other) =>
      other is GridConfig &&
      other.rows == rows &&
      other.cols == cols &&
      other.kindCount == kindCount;

  @override
  int get hashCode => Object.hash(rows, cols, kindCount);

  @override
  String toString() => 'GridConfig(${rows}x$cols, $kindCount kinds)';
}
