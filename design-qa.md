# Design QA

- Source visual truth: the user's paper sketch in this conversation, supported
  by the structural Edge Rail exploration at
  `/home/jl/.codex/generated_images/01a04c66-4006-7842-ac91-f7c9d5698356/exec-ae7b76ba-77b9-4b73-a202-87ae1e139efa.png`.
- Implementation screenshot: `/tmp/trace-shared-seam-focused-latest.png`.
- Combined comparison: `/tmp/trace-shared-seam-comparison-latest.png`.
- Viewport: 1059 x 1384 compositor pixels in the Linux Flutter window;
  the 60-pixel window title bar was excluded from the comparison.
- Source pixels: 853 x 1844, normalized to 555 x 1200.
- Implementation pixels: 1059 x 1324 app-owned crop, normalized to
  960 x 1200.
- State: Maya focused, shared avatar seam on the left, selected avatar
  promoted into the header, Chats page selected.

## Full-view comparison evidence

The implementation preserves the reference's main proportions: a narrow,
persistent neighboring-chat rail and a readable focused conversation. It adds
the user-requested bottom page toolbar. Window chrome was removed before the
side-by-side comparison.

## Focused-region comparison evidence

No separate crop was required for this low-fidelity pass. The combined image
keeps the rail avatars, unread counts, conversation header, message bubbles,
composer, and bottom toolbar readable at the same time.

## Required fidelity surfaces

- Fonts and typography: system sans-serif with a clear low-fidelity hierarchy;
  no brand typography has been selected yet.
- Spacing and layout rhythm: rail, header, messages, composer, and toolbar do
  not overlap at the target viewport. Touch targets remain practical.
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

Widget tests cover page-toolbar navigation, opening and closing a conversation,
opening the exact row where a swipe begins, following the drag before settling,
moving the shared avatar seam from the overview's right edge to the focused
chat's left edge, switching chats by tapping the rail, snapping back after a
short drag, and sending a mock message.
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

## Follow-up polish

- Final color, typography, avatar imagery, and message density remain open by
  design and should be chosen page by page with the user.

final result: passed
