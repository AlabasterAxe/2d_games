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
    canvas.drawParagraph(
        pp, position.toOffset().translate(0, size.y / 2 - pp.height / 2));
  }
}

class TileComponent extends PositionComponent with TapCallbacks {
  final TileContents contents;

  TileComponent(
    Vector2 position,
    Vector2 size,
    this.contents,
  ) : super(position: position, size: size);

  @override
  void onTapUp(TapUpEvent event) {
    log("Tapped tile");
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(position.x, position.y, size.x, size.y),
            const Radius.circular(10)),
        Paint()..color = Color.fromARGB(255, 0, 131, 7));
    TileTypeComponent(position, size, contents.type).render(canvas);
  }
}

class NextTileTypeComponent extends Component {
  final Vector2 position;
  final Vector2 size;
  final TileType type;

  NextTileTypeComponent(
    this.position,
    this.size,
    this.type,
  );

  @override
  void render(Canvas canvas) {
    canvas.drawOval(Rect.fromLTWH(position.x, position.y, size.x, size.y),
        Paint()..color = Color.fromARGB(255, 0, 131, 7));
    TileTypeComponent(position, size, type).render(canvas);
  }
}

World getWorld(WorldState worldState) {
  final world = World();

  for (var i = 0; i < worldState.tiles.length; i++) {
    for (var j = 0; j < worldState.tiles[0].length; j++) {
      world.add(
        TileComponent(
          Vector2((i - GRID_SIZE / 2) * (TILE_SIZE + TILE_SPACING),
              (j - GRID_SIZE / 2) * (TILE_SIZE + TILE_SPACING)),
          Vector2(TILE_SIZE, TILE_SIZE),
          worldState.tiles[i][j],
        ),
      );
    }
  }

  world.add(
    NextTileTypeComponent(
      Vector2(-(BOARD_SIZE * .7) / 2, 450),
      Vector2(BOARD_SIZE * .7, BOARD_SIZE * .2),
      worldState.nextTileType,
    ),
  );

  return world;
}
