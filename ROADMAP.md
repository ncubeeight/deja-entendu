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

## Flashcards from tooltip lookups

After the full-transcript translation toggle above: let a user turn any
word-lookup tooltip (the tap-to-define feature, e.g. in `IrohaExplorerView`)
into a flashcard. Each flashcard is a dedicated page for one term showing:
- The original term
- Its translation
- A pronunciation guide
- An example sentence using the term, with the term highlighted within it

Open questions to resolve when this gets picked up:
- Storage: likely the same on-device-only pattern as `VocabularyStore`
  (JSON in the app container), possibly reusing/extending `VocabularyEntry`
  rather than inventing a fully separate model.
- Generation: the on-device LLM (`WordGlossGenerator`'s session, or a new
  one) would need to produce the pronunciation guide + example sentence,
  not just the short gloss it does today — a bigger prompt/response than
  the current single-word lookup.
- Review flow: is this just a browsable list of cards, or does it grow into
  spaced-repetition-style review later?
