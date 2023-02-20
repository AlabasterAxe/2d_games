import 'dart:math' show Random;
import 'dart:ui';
import "dart:collection" show Queue;

import 'package:flame/components.dart';
import 'package:flame/experimental.dart' show TapCallbacks, TapUpEvent, World;

const GRID_SIZE = 6;
const TILE_SIZE = 100.0;
const TILE_SPACING = 5.0;
const BOARD_SIZE = GRID_SIZE * (TILE_SIZE + TILE_SPACING);

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

abstract class GameAction {
  WorldState apply(WorldState worldState);
}

class LocatedTile {
  final int gridX;
  final int gridY;
  final TileContents tileContents;

  LocatedTile(this.gridX, this.gridY, this.tileContents);
}

class ApplyTripleAction implements GameAction {
  final List<LocatedTile> triple;
  final LocatedTile placedTile;

  ApplyTripleAction(this.triple, this.placedTile);

  @override
  WorldState apply(WorldState worldState) {
    for (final tile in triple) {
      worldState.tiles[tile.gridY][tile.gridX] = SimpleTile(TileType.none);
    }
    final newType = TRIPLE_MAPPING[placedTile.tileContents.type];
    if (newType == null) {
      throw Exception(
          'Triple mapping not found for ${placedTile.tileContents.type}');
    }
    worldState.tiles[placedTile.gridY][placedTile.gridX] = SimpleTile(newType);
    return worldState;
  }
}

class ChooseNextTileType implements GameAction {
  @override
  WorldState apply(WorldState worldState) {
    worldState.nextTileType = getNextTileType();
    return worldState;
  }
}

String coordKey(int x, int y) => "$x,$y";

class ApplyTriplesAction implements GameAction {
  ApplyTripleAction? findTriple(WorldState worldState) {
    final lastPlaceX = worldState.lastPlaceX;
    final lastPlaceY = worldState.lastPlaceY;

    if (lastPlaceX == null || lastPlaceY == null) {
      return null;
    }

    final placedTile = LocatedTile(
        lastPlaceX, lastPlaceY, worldState.tiles[lastPlaceY][lastPlaceX]);
    final tripleTiles = <String, LocatedTile>{};
    final searchType = placedTile.tileContents.type;
    final searchTiles = Queue.from([placedTile]);

    while (searchTiles.isNotEmpty) {
      final tile = searchTiles.removeFirst();
      tripleTiles[coordKey(tile.gridX, tile.gridY)] = tile;
      for (var coord in [
        [tile.gridX, tile.gridY - 1],
        [tile.gridX, tile.gridY + 1],
        [tile.gridX - 1, tile.gridY],
        [tile.gridX + 1, tile.gridY],
      ]) {
        final x = coord[0];
        final y = coord[1];
        final key = coordKey(x, y);
        if (x < 0 || x >= GRID_SIZE || y < 0 || y >= GRID_SIZE) {
          continue;
        }
        final tile = worldState.tiles[y][x];
        if (tile.type == searchType && !tripleTiles.containsKey(key)) {
          searchTiles.add(LocatedTile(x, y, tile));
        }
      }
    }

    if (tripleTiles.length < 3) {
      return null;
    }

    return ApplyTripleAction(
        tripleTiles.values.toList(growable: false), placedTile);
  }

  @override
  WorldState apply(WorldState worldState) {
    while (true) {
      final tripleAction = findTriple(worldState);
      if (tripleAction == null) {
        return worldState;
      }
      worldState = tripleAction.apply(worldState);
    }
  }
}

class PlaceTileAction implements GameAction {
  final int gridX;
  final int gridY;

  PlaceTileAction(this.gridX, this.gridY);

  @override
  WorldState apply(WorldState worldState) {
    worldState.tiles[gridY][gridX] = SimpleTile(worldState.nextTileType);
    worldState.turn++;
    worldState.lastPlaceX = gridX;
    worldState.lastPlaceY = gridY;
    return worldState;
  }
}

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

  int turn = 0;

  int? lastPlaceX;
  int? lastPlaceY;
}

class TileTypeComponent extends PositionComponent {
  final TileType type;

  TileTypeComponent(Vector2 position, Vector2 size, this.type)
      : super(position: position, size: size);

  @override
  void render(Canvas canvas) {
    ParagraphBuilder p = ParagraphBuilder(ParagraphStyle(
      textAlign: TextAlign.center,
    ))
      ..addText(type.name);
    Paragraph pp = p.build()..layout(ParagraphConstraints(width: size.x));
    canvas.drawParagraph(pp, Offset(0, size.y / 2 - pp.height / 2));
  }
}

class TileComponent extends PositionComponent with TapCallbacks {
  final TileContents contents;
  final int gridX;
  final int gridY;
  final Function(GameAction action) onAction;

  TileComponent(
    Vector2 position,
    Vector2 size,
    this.contents,
    this.gridX,
    this.gridY,
    this.onAction,
  ) : super(position: position, size: size);

  @override
  void onTapUp(TapUpEvent event) {
    if (contents.type == TileType.none) {
      onAction(PlaceTileAction(gridX, gridY));
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(0, 0, size.x, size.y), const Radius.circular(10)),
        Paint()..color = Color.fromARGB(255, 0, 131, 7));
    TileTypeComponent(position, size, contents.type).render(canvas);
  }
}

class NextTileTypeComponent extends PositionComponent {
  final TileType type;

  NextTileTypeComponent(
    position,
    size,
    this.type,
  ) : super(position: position, size: size);

  @override
  void render(Canvas canvas) {
    canvas.drawOval(Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..color = Color.fromARGB(255, 0, 131, 7));
    TileTypeComponent(position, size, type).render(canvas);
  }
}

class FlippleWorld extends World {
  WorldState state;

  FlippleWorld(this.state) : super() {
    this._updateState(state);
  }

  void _onAction(GameAction action) {
    state = action.apply(state);
    state = ApplyTriplesAction().apply(state);
    state = ChooseNextTileType().apply(state);
    this._updateState(state);
  }

  _updateState(WorldState newState) {
    this.removeAll(children.query());
    state = newState;
    for (var i = 0; i < state.tiles.length; i++) {
      for (var j = 0; j < state.tiles[0].length; j++) {
        this.add(
          TileComponent(
            Vector2((j - GRID_SIZE / 2) * (TILE_SIZE + TILE_SPACING),
                (i - GRID_SIZE / 2) * (TILE_SIZE + TILE_SPACING)),
            Vector2(TILE_SIZE, TILE_SIZE),
            state.tiles[i][j],
            j,
            i,
            _onAction,
          ),
        );
      }
    }

    this.add(
      NextTileTypeComponent(
        Vector2(-(BOARD_SIZE * .7) / 2, 450),
        Vector2(BOARD_SIZE * .7, BOARD_SIZE * .2),
        state.nextTileType,
      ),
    );
  }
}
