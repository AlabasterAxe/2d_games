import 'dart:developer';
import 'dart:ui';

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

abstract class GameAction {
  WorldState apply(WorldState worldState);
}

class PlaceTileAction implements GameAction {
  final int gridX;
  final int gridY;

  PlaceTileAction(this.gridX, this.gridY);

  @override
  WorldState apply(WorldState worldState) {
    worldState.tiles[gridY][gridX] = SimpleTile(worldState.nextTileType);
    worldState.turn++;
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
    onAction(PlaceTileAction(gridX, gridY));
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
