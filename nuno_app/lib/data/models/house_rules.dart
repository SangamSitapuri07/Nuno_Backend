import 'package:equatable/equatable.dart';

import 'json.dart';

/// Mirrors src/gameplay/house.rules.ts.
///
/// Everything is off by default, and off means the official Mattel game.
/// Mattel has stated plainly that stacking is not part of UNO; jump-in,
/// seven-zero and draw-to-match are likewise variants rather than rules. So a
/// player who touches nothing gets the game printed on the box.
///
/// These are only offered in a private room, where everyone at the table can
/// see the choice before the game starts. Quick Match is always official.
class HouseRules extends Equatable {
  /// Answer a Draw Two with another Draw Two, passing the growing penalty on.
  /// Same type only - a Draw Two cannot be answered with a Draw Four.
  final bool stackDrawTwo;

  /// The same, for Draw Four onto Draw Four.
  final bool stackDrawFour;

  /// Play an identical card (same colour AND value) out of turn. Numbers
  /// only; play then continues from whoever jumped in.
  final bool jumpIn;

  /// A 7 swaps hands with a chosen player; a 0 rotates every hand one seat.
  final bool sevenZero;

  /// Keep drawing until something playable turns up.
  final bool drawToMatch;

  /// Miss the call on your second-to-last card and draw two automatically.
  final bool forceUnoPenalty;

  const HouseRules({
    this.stackDrawTwo = false,
    this.stackDrawFour = false,
    this.jumpIn = false,
    this.sevenZero = false,
    this.drawToMatch = false,
    this.forceUnoPenalty = false,
  });

  /// The official game.
  static const official = HouseRules();

  factory HouseRules.fromJson(Map<String, dynamic>? json) {
    if (json == null) return official;
    return HouseRules(
      stackDrawTwo: J.bool_(json['stackDrawTwo']),
      stackDrawFour: J.bool_(json['stackDrawFour']),
      jumpIn: J.bool_(json['jumpIn']),
      sevenZero: J.bool_(json['sevenZero']),
      drawToMatch: J.bool_(json['drawToMatch']),
      forceUnoPenalty: J.bool_(json['forceUnoPenalty']),
    );
  }

  Map<String, dynamic> toJson() => {
        'stackDrawTwo': stackDrawTwo,
        'stackDrawFour': stackDrawFour,
        'jumpIn': jumpIn,
        'sevenZero': sevenZero,
        'drawToMatch': drawToMatch,
        'forceUnoPenalty': forceUnoPenalty,
      };

  HouseRules copyWith({
    bool? stackDrawTwo,
    bool? stackDrawFour,
    bool? jumpIn,
    bool? sevenZero,
    bool? drawToMatch,
    bool? forceUnoPenalty,
  }) =>
      HouseRules(
        stackDrawTwo: stackDrawTwo ?? this.stackDrawTwo,
        stackDrawFour: stackDrawFour ?? this.stackDrawFour,
        jumpIn: jumpIn ?? this.jumpIn,
        sevenZero: sevenZero ?? this.sevenZero,
        drawToMatch: drawToMatch ?? this.drawToMatch,
        forceUnoPenalty: forceUnoPenalty ?? this.forceUnoPenalty,
      );

  /// True when nothing is enabled, i.e. this is the official game.
  bool get isOfficial => enabledCount == 0;

  int get enabledCount => [
        stackDrawTwo,
        stackDrawFour,
        jumpIn,
        sevenZero,
        drawToMatch,
        forceUnoPenalty,
      ].where((e) => e).length;

  /// One-line summary for the lobby header.
  String get summary =>
      isOfficial ? 'Official rules' : '$enabledCount house rules';

  @override
  List<Object?> get props => [
        stackDrawTwo,
        stackDrawFour,
        jumpIn,
        sevenZero,
        drawToMatch,
        forceUnoPenalty,
      ];
}

/// One toggle, as shown in the lobby.
class HouseRuleSpec {
  final String title;
  final String description;
  final bool Function(HouseRules) get;
  final HouseRules Function(HouseRules, bool) set;

  const HouseRuleSpec({
    required this.title,
    required this.description,
    required this.get,
    required this.set,
  });
}

/// The list the lobby renders. Ordered most to least commonly played, so the
/// rule nearly everybody wants is the first one they see.
const houseRuleSpecs = <HouseRuleSpec>[
  HouseRuleSpec(
    title: 'Stack +2',
    description: 'Answer a +2 with your own +2 and pass it on',
    get: _getStack2,
    set: _setStack2,
  ),
  HouseRuleSpec(
    title: 'Stack +4',
    description: 'Answer a +4 with your own +4. Cannot mix with +2',
    get: _getStack4,
    set: _setStack4,
  ),
  HouseRuleSpec(
    title: 'Jump-in',
    description: 'Play an identical number out of turn. Numbers only',
    get: _getJumpIn,
    set: _setJumpIn,
  ),
  HouseRuleSpec(
    title: 'Seven-Zero',
    description: 'A 7 swaps hands with a player, a 0 rotates every hand',
    get: _getSevenZero,
    set: _setSevenZero,
  ),
  HouseRuleSpec(
    title: 'Draw to match',
    description: 'Keep drawing until you get a card you can play',
    get: _getDrawToMatch,
    set: _setDrawToMatch,
  ),
  HouseRuleSpec(
    title: 'Forced UNO',
    description: 'Forget to call UNO and draw two automatically',
    get: _getForceUno,
    set: _setForceUno,
  ),
];

// Top-level functions rather than closures: the list is const, and a const
// list cannot hold a closure.
bool _getStack2(HouseRules r) => r.stackDrawTwo;
HouseRules _setStack2(HouseRules r, bool v) => r.copyWith(stackDrawTwo: v);

bool _getStack4(HouseRules r) => r.stackDrawFour;
HouseRules _setStack4(HouseRules r, bool v) => r.copyWith(stackDrawFour: v);

bool _getJumpIn(HouseRules r) => r.jumpIn;
HouseRules _setJumpIn(HouseRules r, bool v) => r.copyWith(jumpIn: v);

bool _getSevenZero(HouseRules r) => r.sevenZero;
HouseRules _setSevenZero(HouseRules r, bool v) => r.copyWith(sevenZero: v);

bool _getDrawToMatch(HouseRules r) => r.drawToMatch;
HouseRules _setDrawToMatch(HouseRules r, bool v) => r.copyWith(drawToMatch: v);

bool _getForceUno(HouseRules r) => r.forceUnoPenalty;
HouseRules _setForceUno(HouseRules r, bool v) =>
    r.copyWith(forceUnoPenalty: v);
