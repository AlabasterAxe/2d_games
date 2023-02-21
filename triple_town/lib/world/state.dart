import 'dart:math';

import 'package:uuid/uuid.dart';

const GRID_SIZE = 6;

class GridLoc {
  final int x;
  final int y;
  GridLoc(this.x, this.y);
}

enum TileType {
  none,
  grass,
  bush,
  tree,
  hut,
  rock,
  house,
  bear,
  church,
  cathedral,
  tombstone,
}

const PLACE_PROBABILITIES = {
  TileType.grass: 20,
  TileType.bush: 4,
  TileType.tree: 2,
  TileType.hut: 1,
  TileType.bear: 2,
};

TileType getNextTileType() {
  final random = Random();
  final roll =
      random.nextInt(PLACE_PROBABILITIES.values.reduce((a, b) => a + b));
  var total = 0;
  for (final entry in PLACE_PROBABILITIES.entries) {
    total += entry.value;
    if (roll < total) {
      return entry.key;
    }
  }
  return TileType.grass;
}

const TRIPLE_MAPPING = {
  TileType.grass: TileType.bush,
  TileType.bush: TileType.tree,
  TileType.tree: TileType.hut,
  TileType.hut: TileType.house,
  TileType.tombstone: TileType.church,
  TileType.church: TileType.cathedral,
};

abstract class TileContents {
  TileType get type;
}

class SimpleTile implements TileContents {
  @override
  final TileType type;
  SimpleTile(this.type);
}

class BearTile implements TileContents {
  @override
  final TileType type = TileType.bear;
  final int placeTurn;
  final String id = Uuid().v4();
  BearTile(this.placeTurn);
}

class WorldState {
  List<List<TileContents>> tiles = List.generate(
    GRID_SIZE,
    (i) => List.generate(
      GRID_SIZE,
      (j) => SimpleTile(TileType.none),
    ),
  );

  TileType nextTileType = TileType.grass;
  TileType holdingZoneTileType = TileType.none;

  int turn = 0;

  int? lastPlaceX;
  int? lastPlaceY;
}
