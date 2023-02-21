import 'dart:developer';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/experimental.dart' show TapCallbacks, TapUpEvent, World;
import 'package:flame/flame.dart' show Flame;
import 'package:triple_town/world/state.dart';

import 'actions.dart';

const TILE_SIZE = 100.0;
const TILE_SPACING = 5.0;
const BOARD_SIZE = GRID_SIZE * (TILE_SIZE + TILE_SPACING);

const TILE_TYPE_TO_IMAGE = {
  TileType.grass: 'grass.png',
  TileType.bush: 'bush.png',
  TileType.tree: 'tree.png',
  TileType.bear: 'bear.png',
};

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
    this.add(TileTypeComponent(Vector2(0, 0), Vector2(size.x, size.y), type));
  }

  @override
  void onTapUp(TapUpEvent event) {
    this.onAction(SwapHoldingZone());
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
