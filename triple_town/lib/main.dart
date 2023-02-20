import 'package:flame/game.dart' show FlameGame, GameWidget;
import 'package:flutter/material.dart' show MaterialApp;
import 'package:flutter/src/widgets/basic.dart';
import 'package:flutter/widgets.dart'
    show
        Color,
        Container,
        Positioned,
        Row,
        SafeArea,
        Stack,
        Text,
        TextStyle,
        runApp;
import 'package:triple_town/flipple-town-game.dart';

void main() {
  runApp(MaterialApp(
    home: SafeArea(
      child: Stack(
        children: [
          Positioned.fill(
            child: GameWidget(
              game: FlippleTownGame(),
              backgroundBuilder: (context) => Container(
                color: Color.fromARGB(255, 225, 236, 226),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(children: [
                Text("Flipple Town",
                    style: TextStyle(
                        fontSize: 30, color: Color.fromARGB(255, 27, 33, 27))),
              ]),
            ),
          ),
        ],
      ),
    ),
  ));
}
