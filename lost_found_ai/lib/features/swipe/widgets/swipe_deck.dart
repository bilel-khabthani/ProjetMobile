import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/models/swipe_candidate.dart';
import 'swipe_card.dart';

/// Petit controleur imperatif pour que les boutons d'action puissent declencher
/// exactement la meme animation qu'un glissement.
class SwipeDeckController {
  _SwipeDeckState? _state;

  void _attach(_SwipeDeckState state) => _state = state;

  void _detach(_SwipeDeckState state) {
    if (identical(_state, state)) _state = null;
  }

  void swipe(SwipeDirection direction) => _state?.swipe(direction);
}

/// Pile de cartes avec geste de glissement, rotation et animation de sortie.
///
/// Le deck ne modifie jamais la liste : il signale la decision apres la fin de
/// l'animation, puis le parent retire la carte. Cela evite que la carte
/// disparaisse pendant le fly-out.
class SwipeDeck extends StatefulWidget {
  const SwipeDeck({
    super.key,
    required this.candidates,
    required this.onDecide,
    this.controller,
    this.onOpenInsight,
  });

  final List<SwipeCandidate> candidates;
  final void Function(SwipeCandidate candidate, SwipeDirection direction)
  onDecide;
  final SwipeDeckController? controller;
  final VoidCallback? onOpenInsight;

  @override
  State<SwipeDeck> createState() => _SwipeDeckState();
}

class _SwipeDeckState extends State<SwipeDeck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fly;
  Animation<Offset>? _animation;
  Offset _drag = Offset.zero;
  bool _flying = false;
  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
    _fly =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 260),
        )..addListener(() {
          final animation = _animation;
          if (animation == null || !mounted) return;
          setState(() => _drag = animation.value);
        });
  }

  @override
  void didUpdateWidget(covariant SwipeDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _fly.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_flying || widget.candidates.isEmpty) return;
    setState(() => _drag += details.delta);
  }

  void _onPanEnd(DragEndDetails details) {
    if (_flying || widget.candidates.isEmpty) return;
    final width = _size.width == 0 ? 360.0 : _size.width;
    final velocity = details.velocity.pixelsPerSecond.dx;
    final threshold = width * 0.26;

    if (_drag.dx.abs() > threshold || velocity.abs() > 700) {
      swipe(_drag.dx >= 0 ? SwipeDirection.like : SwipeDirection.pass);
    } else {
      _animateTo(Offset.zero);
    }
  }

  /// Declenche le fly-out. Public au sein de la bibliotheque via le controleur.
  void swipe(SwipeDirection direction) {
    if (_flying || widget.candidates.isEmpty) return;
    final width = _size.width == 0 ? 360.0 : _size.width;
    final target = direction == SwipeDirection.like
        ? Offset(width * 1.3, _drag.dy - 40)
        : Offset(-width * 1.3, _drag.dy - 40);

    _flying = true;
    _animateTo(
      target,
      curve: Curves.easeIn,
      onComplete: () {
        final candidate = widget.candidates.first;
        if (!mounted) return;
        setState(() {
          _drag = Offset.zero;
          _flying = false;
        });
        HapticFeedback.mediumImpact();
        widget.onDecide(candidate, direction);
      },
    );
  }

  void _animateTo(
    Offset target, {
    Curve curve = Curves.easeOutBack,
    VoidCallback? onComplete,
  }) {
    _animation = Tween<Offset>(
      begin: _drag,
      end: target,
    ).animate(CurvedAnimation(parent: _fly, curve: curve));
    _fly.forward(from: 0).whenComplete(() {
      onComplete?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = Size(constraints.maxWidth, constraints.maxHeight);

        if (widget.candidates.isEmpty) {
          return const SizedBox.shrink();
        }

        final progress = (_drag.dx.abs() / (constraints.maxWidth * 0.45)).clamp(
          0.0,
          1.0,
        );
        final visible = math.min(3, widget.candidates.length);
        final cards = <Widget>[];

        // Les cartes du dessous sont ajoutees en premier pour que la carte
        // active soit au sommet de la pile.
        for (var index = visible - 1; index >= 0; index--) {
          final candidate = widget.candidates[index];
          final isTop = index == 0;
          Widget card = SwipeCard(
            key: ValueKey(candidate.matchId),
            candidate: candidate,
            drag: isTop ? _drag : Offset.zero,
            onOpenInsight: isTop ? widget.onOpenInsight : null,
          );

          if (isTop) {
            card = Transform.translate(
              offset: _drag,
              child: Transform.rotate(
                angle: _drag.dx / constraints.maxWidth * 0.24,
                child: card,
              ),
            );
          } else {
            final depth = index.toDouble();
            card = Transform.translate(
              offset: Offset(0, depth * 14 - progress * 14),
              child: Transform.scale(
                scale: 1 - depth * 0.045 + progress * 0.045,
                child: card,
              ),
            );
          }

          cards.add(card);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: Stack(alignment: Alignment.center, children: cards),
        );
      },
    );
  }
}
