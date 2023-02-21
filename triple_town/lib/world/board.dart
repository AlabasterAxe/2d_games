import 'dart:developer';
import 'dart:math' show Random;
import 'dart:ui';
import "dart:collection" show Queue;

import 'package:flame/components.dart';
import 'package:flame/experimental.dart' show TapCallbacks, TapUpEvent, World;
import 'package:flame/flame.dart' show Flame;
import 'package:triple_town/world/state.dart';
import 'package:uuid/uuid.dart';

const TILE_SIZE = 100.0;
const TILE_SPACING = 5.0;
const BOARD_SIZE = GRID_SIZE * (TILE_SIZE + TILE_SPACING);

const TILE_TYPE_TO_IMAGE = {
  TileType.grass: 'grass.png',
  TileType.bush: 'bush.png',
  TileType.tree: 'tree.png',
  TileType.bear: 'bear.png',
};

abstract class GameAction {
  WorldState apply(WorldState worldState);
}

class LocatedTile {
  final GridLoc loc;
  final TileContents tileContents;

  LocatedTile(this.loc, this.tileContents);
}

class ApplyTripleAction implements GameAction {
  final List<LocatedTile> triple;
  final LocatedTile placedTile;

  ApplyTripleAction(this.triple, this.placedTile);

  @override
  WorldState apply(WorldState worldState) {
    for (final tile in triple) {
      worldState.tiles[tile.loc.y][tile.loc.x] = SimpleTile(TileType.none);
    }
    final newType = TRIPLE_MAPPING[placedTile.tileContents.type];
    if (newType == null) {
      throw Exception(
          'Triple mapping not found for ${placedTile.tileContents.type}');
    }
    worldState.tiles[placedTile.loc.y][placedTile.loc.x] = SimpleTile(newType);
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

void iterateNESWNeighbors(gridX, gridY, Function(int x, int y) callback) {
  for (var coord in [
    [gridX, gridY - 1],
    [gridX, gridY + 1],
    [gridX - 1, gridY],
    [gridX + 1, gridY]
  ]) {
    final x = coord[0];
    final y = coord[1];
    if (x < 0 || x >= GRID_SIZE || y < 0 || y >= GRID_SIZE) {
      continue;
    }
    callback(x, y);
  }
}

class HandleBears implements GameAction {
  @override
  WorldState apply(WorldState worldState) {
    final handledBears = <String>{};
    for (var y = 0; y < GRID_SIZE; y++) {
      for (var x = 0; x < GRID_SIZE; x++) {
        final tile = worldState.tiles[y][x];
        if (tile is! BearTile || handledBears.contains(tile.id)) {
          continue;
        }
        final List<List<int>> movementCandidates = [];
        iterateNESWNeighbors(x, y, (x, y) {
          final tile = worldState.tiles[y][x];
          if (tile.type == TileType.none) {
            movementCandidates.add([x, y]);
          }
        });

        if (movementCandidates.isEmpty) {
          worldState.tiles[y][x] = SimpleTile(TileType.tombstone);
        } else {
          final random = Random();
          final move =
              movementCandidates[random.nextInt(movementCandidates.length)];
          worldState.tiles[y][x] = SimpleTile(TileType.none);
          worldState.tiles[move[1]][move[0]] = tile;
          handledBears.add(tile.id);
        }
      }
    }
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

    final placedTile = LocatedTile(GridLoc(lastPlaceX, lastPlaceY),
        worldState.tiles[lastPlaceY][lastPlaceX]);
    final tripleTiles = <String, LocatedTile>{};
    final searchType = placedTile.tileContents.type;
    final searchTiles = Queue.from([placedTile]);

    while (searchTiles.isNotEmpty) {
      final tile = searchTiles.removeFirst();
      tripleTiles[coordKey(tile.gridX, tile.gridY)] = tile;
      iterateNESWNeighbors(tile.gridX, tile.gridY, (x, y) {
        final key = coordKey(x, y);
        final tile = worldState.tiles[y][x];
        if (tile.type == searchType && !tripleTiles.containsKey(key)) {
          searchTiles.add(LocatedTile(GridLoc(x, y), tile));
        }
      });
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
    if (worldState.tiles[gridY][gridX].type != TileType.none) {
      throw Exception('Tile already placed at $gridX, $gridY');
    }

    if (worldState.nextTileType == TileType.bear) {
      worldState.tiles[gridY][gridX] = BearTile(worldState.turn);
    } else {
      worldState.tiles[gridY][gridX] = SimpleTile(worldState.nextTileType);
    }
    worldState.turn++;
    worldState.lastPlaceX = gridX;
    worldState.lastPlaceY = gridY;
    return worldState;
  }
}

class TileTypeComponent extends PositionComponent {
  final TileType type;

  TileTypeComponent(Vector2 position, Vector2 size, this.type)
      : super(position: position, size: size);

  @override
  void render(Canvas canvas) {
    if (type == TileType.none) {
      return;
    }

    final String? imageName = TILE_TYPE_TO_IMAGE[type];

    if (imageName != null) {
      final image = Flame.images.fromCache(imageName);
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(position.x, position.y, size.x, size.y),
        Paint(),
      );
    } else {
      ParagraphBuilder p = ParagraphBuilder(ParagraphStyle(
        textAlign: TextAlign.center,
      ))
        ..addText(type.name);
      Paragraph pp = p.build()..layout(ParagraphConstraints(width: size.x));
      canvas.drawParagraph(pp, Offset(0, size.y / 2 - pp.height / 2));
    }
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
  ) : super(position: position, size: size) {
    add(TileTypeComponent(Vector2.zero(), size, contents.type));
  }

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
  }
}

class NextTileTypeComponent extends PositionComponent {
  final TileType type;

  NextTileTypeComponent(
    position,
    size,
    this.type,
  ) : super(position: position, size: size) {
    this.add(TileTypeComponent(
        Vector2(size.x / 12, 0), Vector2(size.x * 2 / 3, size.y), type));
  }

  @override
  void render(Canvas canvas) {
    canvas.drawOval(Rect.fromLTWH(0, size.y / 2, size.x, size.y / 2),
        Paint()..color = Color.fromARGB(255, 0, 131, 7));
  }
}

class HoldingZone extends PositionComponent with TapCallbacks {
  final TileType type;
  final Function(GameAction action) onAction;

  HoldingZone(
    position,
    size,
    this.type,
    this.onAction,
  ) : super(position: position, size: size) {
    this.add(TileTypeComponent(
        Vector2(size.x / 12, 0), Vector2(size.x * 2 / 3, size.y), type));
  }

  @override
  void onTapUp(TapUpEvent event) {
    log("Tapped holding zone");
  }

  @override
  void render(Canvas canvas) {
    canvas.drawOval(Rect.fromLTWH(0, size.y / 2, size.x, size.y / 2),
        Paint()..color = Color.fromARGB(255, 179, 110, 0));
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
    state = HandleBears().apply(state);
    this._updateState(state);
  }

  _updateState(WorldState newState) {
    this.removeAll(children.query());
    state = newState;
    for (var i = 0; i < state.tiles.length; i++) {
      for (var j = 0; j < state.tiles[0].length; j++) {
        if (j == 0 && i == 0) {
          this.add(
            HoldingZone(
              Vector2((j - GRID_SIZE / 2) * (TILE_SIZE + TILE_SPACING),
                  (i - GRID_SIZE / 2) * (TILE_SIZE + TILE_SPACING)),
              Vector2(TILE_SIZE, TILE_SIZE),
              state.holdingZoneTileType,
              _onAction,
            ),
          );
        } else {
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
    }

    this.add(
      NextTileTypeComponent(
        Vector2(-(BOARD_SIZE * .7) / 2, 400),
        Vector2(BOARD_SIZE * .7, BOARD_SIZE * .4),
        state.nextTileType,
      ),
    );
  }
}
