import 'dart:collection';
import 'dart:math';

import 'state.dart'
    show
        BearTile,
        GRID_SIZE,
        GridLoc,
        LocatedTile,
        SimpleTile,
        TRIPLE_MAPPING,
        TileType,
        WorldState,
        getNextTileType,
        iterateNESWNeighbors,
        locKey;

abstract class GameAction {
  WorldState apply(WorldState worldState);
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
      tripleTiles[locKey(tile.gridX, tile.gridY)] = tile;
      iterateNESWNeighbors(tile.gridX, tile.gridY, (x, y) {
        final key = locKey(x, y);
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
