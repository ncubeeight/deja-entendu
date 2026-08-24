# Roadmap

Ideas worth exploring in future sessions — not committed to, just tracked.

## Full-transcript translation view

Alongside the existing word-by-word tooltip lookup (tap a term, see its
gloss), offer a toggle to see the *entire* transcript translated into the
user's native language at once — for when someone wants full comprehension
of a recording rather than looking up individual unfamiliar terms.

Open questions to resolve when this gets picked up:
- Where does this live in the UI — a toggle on the transcript view, a
  separate screen, both?
- Does it reuse `StudyNoteGenerator`'s on-device model session, or need its
  own (full-transcript translation is a bigger prompt than a single word's
  gloss, and the on-device model's context window is only ~4096 tokens per
  `StudyNoteGenerator.swift`, so long recordings may need chunking).
- Should it cache the full translation once generated, or regenerate each
  time the view appears?

## Vocabulary flashcards — done

Every vocabulary term (however it was added — transcript tap, manual entry,
or shared in from Translate) now opens a dedicated flashcard page showing
the original term, a plain-English pronunciation guide, a translation, and
an example sentence with the term highlighted within it. Tapping a term on
the Home screen's "Words to review" grid or in the Vocabulary list both
navigate to the same `VocabularyFlashcardView`. Generated on-device via
`FlashcardGenerator` (`FoundationModels`) and cached back into
`VocabularyEntry`/`VocabularyStore` so a card only regenerates once.

Not done: the `IrohaExplorerView` tap-to-define tooltip still only shows a
quick gloss popover — it doesn't yet offer an "Add to Vocabulary" action
the way the transcript view's word tokens do, so flashcards can't be
created directly from that screen. Worth revisiting if that gap matters.
