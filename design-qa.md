# Design QA

- Source visual truth: the user's paper sketch and the previously verified
  narrow-layout implementation, supported by the structural Edge Rail
  exploration at
  `/home/jl/.codex/generated_images/01a04c66-4006-7842-ac91-f7c9d5698356/exec-ae7b76ba-77b9-4b73-a202-87ae1e139efa.png`.
- Overview screenshot: `/tmp/trace-no-rail-overview.png`.
- Focused implementation screenshot: `/tmp/trace-no-rail-focused.png`.
- Mid-drag screenshot: `/tmp/trace-no-rail-mid-drag.png`.
- Desktop split-view screenshot: `/tmp/trace-desktop-split.png`.
- Desktop before/after comparison: `/tmp/trace-desktop-split-comparison.png`.
- Viewport: 1061 x 1386 logical compositor pixels in the Linux Flutter window;
  the 60-pixel window title bar was excluded from the comparison.
- Desktop source and implementation pixels: 1414 x 1768 app-owned crops,
  normalized to 720 x 900 each.
- State: Maya focused in the desktop split view, full chat list visible on the
  left, conversation on the right, Chats page selected.

## Full-view comparison evidence

The desktop implementation removes the old centered 600-pixel cap. At the same
wide viewport, the before/after comparison shows the chat list expanded on the
left and the selected conversation using every remaining pixel on the right.
Window chrome was removed before the side-by-side comparison.

In the overview, every avatar now sits visually inside its conversation card.
Time is left-aligned while the name and message preview lead into the avatar on
the right, matching the user's latest layout direction.

## Focused-region comparison evidence

No separate crop was required for this low-fidelity pass. The desktop capture
keeps list cards, unread counts, conversation header, messages, composer, list
toggle, and bottom toolbar readable at the same time. The narrow swipe layout
remains unchanged below the desktop breakpoint.

## Required fidelity surfaces

- Fonts and typography: system sans-serif with a clear low-fidelity hierarchy;
  no brand typography has been selected yet.
- Spacing and layout rhythm: chat list, header, messages, composer, and toolbar
  do not overlap at the target viewport. Touch targets remain practical.
- Colors and visual tokens: intentionally grayscale; selected and unread states
  retain sufficient contrast without deciding the final palette.
- Image quality and asset fidelity: no custom imagery is part of this structural
  prototype. Initials are deliberate profile fallbacks; icons use Flutter's
  Material icon set.
- Copy and content: concise mock chat data exercises names, unread counts,
  encryption state, and message composition without adding product marketing.

## Findings

No actionable P0, P1, or P2 mismatch remains for the agreed low-fidelity scope.

## Interaction evidence

Widget tests cover the wide split view, selecting a chat without leaving that
view, collapsing the list so the conversation reaches the window edge, restoring
the list, page-toolbar navigation, opening and closing a conversation,
opening the exact row where a swipe begins, following the drag before settling,
moving the card ends from the overview's right edge to the focused chat's left
edge, switching chats by tapping those card ends, snapping back after a short
drag, keeping avatars inside overview card bounds, verifying the requested
time/name ordering, staggering the selected row behind its neighbors, keeping
the selected avatar at a fixed offset within its moving card, painting that
avatar above the incoming conversation page throughout the drag, and sending a
mock message.
The Linux app started with vodozemac loaded and was inspected in overview and
focused-chat states. No Flutter rendering exceptions were observed. Browser
console checks do not apply to this native Flutter implementation.

## Comparison history

- Initial native run was blocked by vodozemac resolving its Linux library from
  the process working directory. The loader now resolves `lib/` relative to the
  executable, and the next run started successfully.
- Initial visual capture used a colored default navigation indicator and made
  unselected rail avatars blend into the rail. Both were changed to explicit
  grayscale surfaces and the revised focused-chat capture was reviewed.
- The first interaction pass mistakenly added a second horizontal pager between
  individual conversations. That pager was removed: horizontal swiping now
  moves only between All Chats and the selected chat, while the rail switches
  conversations by tap.
- A subsequent pass still opened the previously active conversation and treated
  the overview and focused rails as separate layouts. The interaction now locks
  onto the row where the drag begins, uses one shared rail as the seam between
  both pages, and promotes only the selected avatar into the focused header.
- The first shared-seam layout left avatars floating in a separate gray strip
  and used flat divider rows. Cards now extend behind the seam so profiles are
  contained by their chat cards; rounded surfaces, clearer spacing, swapped
  information alignment, and selected-row motion delay were added and visually
  inspected in overview, mid-drag, and focused states.
- The next pass still animated avatars independently inside a dedicated gray
  rail. The rail has been removed: each avatar now inherits its card's horizontal
  transform, and the visible right-hand peek is the actual conversation page.
- The initial desktop build constrained the entire app to a mobile-width column.
  Wide windows now use a responsive list-and-conversation split, while the
  conversation header can collapse and restore the list at any desktop width.

## Follow-up polish

- Final color, typography, avatar imagery, and message density remain open by
  design and should be chosen page by page with the user.

final result: passed
