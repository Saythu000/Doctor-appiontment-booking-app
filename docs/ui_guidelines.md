# DrGodly UI guidelines

Every screen must follow these rules before it is merged. They come from
Google's Material 3 and Android quality guidelines and from patterns used by
top consumer apps (Netflix, Airbnb, Google Fit, health apps like Practo).
Style direction: **calm medical**, meaning trustworthy, quiet, clear. It is
not a fitness or game app.

## 1. Structure of a screen

- **One main action per screen.** It is a full-width primary button
  (`AppButton`), at the bottom or right after the content it acts on.
  Any other actions are secondary (outlined or text buttons).
- **Clear title.** It says where you are in plain words ("Book a visit",
  not "Clinical Consultation Portal").
- **Content order:** most important first. Home starts with the next
  appointment, never with a decorative banner.
- **8-point spacing** (`AppSpacing`), 16dp side margins, 24dp between groups.
- **Back always works.** The back arrow and Android back go to the previous
  screen. On a tab other than Home, back goes to Home. Only Home exits.

## 2. Honesty (trust)

- **Never show fake or guessed data.** If a value is unknown, show "--" or
  "Not set", never 0, "Normal" or a default age.
- **Never claim something happened** unless the server confirmed it
  ("Synced", "Confirmed", "Saved").
- **Every screen that loads data has three distinct states:** loading
  (`LoadingView` or skeleton), empty (`EmptyView` with a next step), and
  error (`ErrorView` with "Try again"). An error must never look like
  "no data".
- **Destructive actions ask first** (`confirmAction`): cancel, delete,
  clear, discard.

## 3. Buttons and input

- **Touch targets of at least 48 x 48dp.**
- **A button that starts work shows a spinner and blocks a second tap**
  (`AppButton(isLoading: …)`).
- **Forms:** the right keyboard (number, phone, email), inline validation
  messages under the field, sensible limits, and fields that can be
  cleared.
- **Feedback after every action:** a short message (`showAppMessage`) or
  a visible change on the screen.

## 4. Motion (like Netflix: short, purposeful, branded)

- **Brand intro:** only on a cold start (the splash), about 4.5 s, played
  once from start to finish. The app never shows it when returning from the
  background.
- **Screen changes:** Material 3 page transitions (theme), about 300 ms.
- **Content entrance:** fade and lift (`FadeSlideIn`), with list items
  staggered 40–60 ms apart. No bouncing or spinning.
- **Motion explains something.** It shows where content came from or
  that work is happening. It is never just decoration that delays the user.
- **"Remove animations" (Android accessibility) is respected everywhere**
  (`AppMotion.reduced`).

## 5. Colour and text

- **Only theme tokens** (`context.colors`, `context.text`). No hex values
  in screens. Light and dark mode both come from the tokens.
- **Contrast of at least 4.5:1** for text (checked by a test for every token).
- **Status colour always comes with a word or icon** (never colour alone):
  CONFIRMED, PENDING, and so on, through `StatusBadge`.
- **Minimum text size 12sp.** Layouts must work at 200% text size.
- **Plain language.** "Heart rate", not "clinical telemetry". Use one name
  per thing across the app.

## 6. Accessibility

- **Every icon-only button has a tooltip** (a screen-reader label).
- **Charts and rings carry a `Semantics` label** that reads the value out.
- **Headings are marked as headers.** Changing messages use `liveRegion`.
- **Tested on a 320dp-wide phone with large text, in light and dark mode**
  (see `test/features/screens/`). Every screen test also calls
  `expectAccessible` (`test/helpers/accessibility.dart`), which checks
  Android's 48dp tap targets, labels on every tappable item, and text
  contrast measured on the rendered screen.
- **Forms use `validateForm`** (`core/widgets/form_feedback.dart`): it scrolls
  to the top wrong field, and Flutter reads that error aloud. Every text
  field sets `textInputAction` (Next, then Done on the last field).
- **Switches and toggles carry a label** that says what they control.

## 7. Performance

- **No network call blocks the first frame.**
- **Images are sized** (`cacheWidth`) and show a placeholder while loading.
- **Long lists use builders** (lazy loading).

## Checklist for each redesigned screen

- [ ] One clear primary action; secondary actions look secondary
- [ ] Loading, empty and error states, each different and honest
- [ ] No fake or default values; unknown shows "--" or "Not set"
- [ ] 48dp targets, tooltips on icon buttons, back works
- [ ] Theme tokens only; works in dark mode
- [ ] Fits a 320dp phone at 130% and 200% text (test)
- [ ] Passes `expectAccessible` in light and dark (test)
- [ ] Animations short and purposeful; respect "Remove animations"
