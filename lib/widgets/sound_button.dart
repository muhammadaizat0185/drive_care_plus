import 'package:flutter/material.dart';
import '../services/audio_service.dart';
export '../services/audio_service.dart';

/// Drop-in replacement for ElevatedButton that plays the button sound before triggering onPressed.
class SoundButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;
  final ButtonSoundType soundType;
  final FocusNode? focusNode;
  final bool autofocus;
  final Clip clipBehavior;

  const SoundButton({
    Key? key,
    required this.onPressed,
    required this.child,
    this.style,
    this.soundType = ButtonSoundType.primary,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
  }) : super(key: key);

  const SoundButton.save({
    Key? key,
    required this.onPressed,
    required this.child,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
  })  : soundType = ButtonSoundType.save,
        super(key: key);

  const SoundButton.error({
    Key? key,
    required this.onPressed,
    required this.child,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
  })  : soundType = ButtonSoundType.error,
        super(key: key);

  const SoundButton.toggle({
    Key? key,
    required this.onPressed,
    required this.child,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
  })  : soundType = ButtonSoundType.toggle,
        super(key: key);

  const SoundButton.destructive({
    Key? key,
    required this.onPressed,
    required this.child,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
  })  : soundType = ButtonSoundType.destructive,
        super(key: key);

  const SoundButton.navigation({
    Key? key,
    required this.onPressed,
    required this.child,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
  })  : soundType = ButtonSoundType.navigation,
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed == null
          ? null
          : () {
              AudioService.instance.button(soundType);
              onPressed!();
            },
      style: style,
      focusNode: focusNode,
      autofocus: autofocus,
      clipBehavior: clipBehavior,
      child: child,
    );
  }
}

/// Drop-in replacement for TextButton that plays the button sound before triggering onPressed.
class SoundTextButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;
  final ButtonSoundType soundType;
  final FocusNode? focusNode;
  final bool autofocus;
  final Clip clipBehavior;

  const SoundTextButton({
    Key? key,
    required this.onPressed,
    required this.child,
    this.style,
    this.soundType = ButtonSoundType.primary,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
  }) : super(key: key);

  const SoundTextButton.save({
    Key? key,
    required this.onPressed,
    required this.child,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
  })  : soundType = ButtonSoundType.save,
        super(key: key);

  const SoundTextButton.error({
    Key? key,
    required this.onPressed,
    required this.child,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
  })  : soundType = ButtonSoundType.error,
        super(key: key);

  const SoundTextButton.toggle({
    Key? key,
    required this.onPressed,
    required this.child,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
  })  : soundType = ButtonSoundType.toggle,
        super(key: key);

  const SoundTextButton.destructive({
    Key? key,
    required this.onPressed,
    required this.child,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
  })  : soundType = ButtonSoundType.destructive,
        super(key: key);

  const SoundTextButton.navigation({
    Key? key,
    required this.onPressed,
    required this.child,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.clipBehavior = Clip.none,
  })  : soundType = ButtonSoundType.navigation,
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed == null
          ? null
          : () {
              AudioService.instance.button(soundType);
              onPressed!();
            },
      style: style,
      focusNode: focusNode,
      autofocus: autofocus,
      clipBehavior: clipBehavior,
      child: child,
    );
  }
}
