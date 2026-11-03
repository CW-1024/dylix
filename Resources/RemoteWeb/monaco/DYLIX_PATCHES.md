# Dylix local patches to Monaco Editor 0.52.2

2026-11-03 · Build 158 · Word-highlighter cancellation

The bundled `vs/editor/editor.main.js` is modified at the two word-highlighter `runDelayer.trigger(...)` calls (cursor-position and editor-focus listeners). Each now attaches `.catch(y.onUnexpectedError)` using that module's existing errors import. Monaco's existing handler ignores `CancellationError` and continues reporting other errors. This observes the rejected promise when a pending word-highlighter Delayer is disposed during a model switch; highlighting remains enabled.

Reproduction: start text input (including an IME composition), finish editing, then switch models quickly enough to dispose the pending 50 ms highlighter Delayer. The former unobserved promise produces `Canceled: Canceled` at `Delayer.cancel → Delayer.dispose → WordHighlighter.dispose`.

Upstream source, version and MIT license remain recorded in SOURCE.json and LICENSE. The patch changes exception observation only, not the highlighter result or cancellation behavior. The served `.gz` copy is regenerated from the modified JS by scripts/build.py.
