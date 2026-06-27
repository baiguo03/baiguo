# Yunti V10 UI Design

## Goal

V10 should feel calmer and more native on iOS 16. The quiz flow should read like a focused study app rather than a stack of large tool buttons. The visual direction should borrow from iOS system spacing, Codex-style quiet typography, and WeChat-like bottom navigation hierarchy.

## User-Facing Changes

- The answer page uses softer hierarchy: compact title, progress line, question surface, then option rows.
- Auto-next no longer performs a large slide. Correct answers use a short confirmation hold, then a low-motion fade change into the next question.
- Auto-next enabled means selecting a correct answer immediately advances without a separate submit tap. Wrong answers stay on the question and show analysis.
- Option rows use iOS Settings-like selected feedback: gentle press state, subtle background, clear correct/wrong colors only after validation.
- The bottom tab bar uses a WeChat-like structure with four stable tabs: Home, Library, Wrong, Profile. It avoids oversized filled blocks.
- Library becomes the main path for practice. Imported papers appear as list rows; tapping one opens the first or current question group.
- The parser fix is included in the next package so answer summaries and the next question's options do not leak into the current question.

## Visual Prototype

Before changing native code further, create a browser preview with:

- One practice screen showing the calmer answer layout and motion notes.
- One library screen showing imported papers as list rows.
- One bottom tab comparison based on the WeChat reference, adapted for this app.

The user reviews this preview first. After approval, the same structure is implemented in UIKit.

## Implementation Notes

- Keep native UIKit. Do not switch frameworks for V10.
- Keep iOS 16 compatibility.
- Avoid heavy animations, gradients, decorative blobs, or large movement.
- Prefer `UIViewPropertyAnimator` or short `UIView.transition` fades over manual large transforms.
- Keep the existing Codemagic build pipeline and existing bundle identifier.

## Verification

- Run parser checks for answer-summary leakage.
- Run native project sanity checks.
- Push to GitHub only after checks pass.
- The resulting IPA name/version should clearly identify V10 so the user can distinguish builds.
