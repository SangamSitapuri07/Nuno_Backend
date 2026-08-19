import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/titled_panel.dart';
import '../../data/models/enums.dart';
import '../../data/models/game_card.dart';
import '../game/widgets/playing_card.dart';

/// Screen 29 — Tutorial. Five paged rule explanations with sample cards.
class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = <_TutorialPage>[
    _TutorialPage(
      title: 'HOW TO PLAY',
      body: 'Match the colour, number or symbol of the card on the pile.',
      cards: [
        GameCard(cardId: 't1', color: CardColor.red, value: CardValue.six),
        GameCard(cardId: 't2', color: CardColor.green, value: CardValue.six),
        GameCard(cardId: 't3', color: CardColor.green, value: CardValue.two),
      ],
    ),
    _TutorialPage(
      title: 'ACTION CARDS',
      body: 'Skip ends the next turn, Reverse flips direction, '
          '+2 makes the next player draw two.',
      cards: [
        GameCard(cardId: 't4', color: CardColor.blue, value: CardValue.skip),
        GameCard(cardId: 't5', color: CardColor.red, value: CardValue.reverse),
        GameCard(
            cardId: 't6', color: CardColor.yellow, value: CardValue.drawTwo),
      ],
    ),
    _TutorialPage(
      title: 'WILD CARDS',
      body: 'A Wild lets you choose the next colour. '
          'Wild +4 also makes the next player draw four.',
      cards: [
        GameCard(cardId: 't7', color: CardColor.wild, value: CardValue.wild),
        GameCard(
            cardId: 't8',
            color: CardColor.wild,
            value: CardValue.wildDrawFour),
      ],
    ),
    _TutorialPage(
      title: 'CALL UNO',
      body: 'When you are down to one card, tap the UNO button '
          'before your turn ends.',
      cards: [
        GameCard(cardId: 't9', color: CardColor.red, value: CardValue.seven),
      ],
    ),
    _TutorialPage(
      title: 'WIN THE ROUND',
      body: 'Be the first to play every card in your hand. '
          'You have 20 seconds per turn.',
      cards: [],
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page >= _pages.length - 1) {
      context.pop();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PanelScreen(
      title: 'Tutorial',
      onBack: () => context.pop(),
      fillHeight: true,
      child: Column(
        children: [
          // The pager takes whatever height is left instead of a fixed 150px
          // strip with the rest of the panel empty below it.
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: _pages.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) {
                final p = _pages[i];
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(p.title, style: AppTextStyles.h3),
                    const SizedBox(height: AppDimens.md),
                    if (p.cards.isNotEmpty)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (final c in p.cards)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: PlayingCardView(card: c, width: 44),
                            ),
                        ],
                      ),
                    const SizedBox(height: AppDimens.md),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.xxl,
                      ),
                      child: Text(
                        p.body,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodySm,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: AppDimens.md),
          ClipRRect(
            borderRadius: AppDimens.brPill,
            child: LinearProgressIndicator(
              value: (_page + 1) / _pages.length,
              minHeight: 4,
              backgroundColor: AppColors.surfaceHigh,
              valueColor: const AlwaysStoppedAnimation(AppColors.green),
            ),
          ),
          const SizedBox(height: AppDimens.md),
          Row(
            children: [
              Text(
                '${_page + 1}/${_pages.length}',
                style: AppTextStyles.caption,
              ),
              const Spacer(),
              SizedBox(
                width: 130,
                child: AppButton(
                  label: _page >= _pages.length - 1 ? 'DONE' : 'NEXT',
                  size: AppButtonSize.small,
                  variant: AppButtonVariant.blue,
                  onPressed: _next,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TutorialPage {
  final String title;
  final String body;
  final List<GameCard> cards;

  const _TutorialPage({
    required this.title,
    required this.body,
    required this.cards,
  });
}
