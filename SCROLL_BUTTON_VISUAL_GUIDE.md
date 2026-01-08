# Floating Button - Visual & Behavior Reference

## Button Appearance

```
┌─────────────────────────────┐
│                             │
│  Chat Messages Area         │
│                             │
│  [User Message]             │
│  [AI Response]              │
│  [User Message]             │
│                    ┌───┐    │
│                    │ ↓ │ ← Button appears here
│                    └───┘    │
│                             │
└─────────────────────────────┘
```

## State Flow Diagram

```
START: User at bottom
       ↓
User scrolls up
       ↓
Detection: not at bottom
       ↓
Button Opacity: 0 → 1
       ↓
Button Visible
       ↓
User clicks button
       ↓
Scroll Animation: current → bottom
       ↓
Detection: at bottom
       ↓
Button Opacity: 1 → 0
       ↓
Button Hidden
       ↓
(Back to START)
```

## Scroll Position Detection

```
┌────────────────────────────────┐
│ Viewport Height: clientHeight  │
├────────────────────────────────┤  ← scrollTop + clientHeight
│                                │
│ Visible Messages               │  ← Show button when:
│ (can see on screen)            │     scrollTop + clientHeight
│                                │     < scrollHeight - 100
├────────────────────────────────┤  ← scrollTop (current position)
│ Hidden Above Messages          │
│ (scrolled past)                │
└────────────────────────────────┘
     ↑
     │
  maxScrollExtent (scrollHeight)
```

## Button Component Breakdown

```
┌─────────────────────────┐
│ Positioned Widget       │ ← Overlays on Stack
│  bottom: 20px           │
│  right: 20px            │
│                         │
│ GestureDetector         │ ← Detects tap
│  ┌─────────────────────┐│
│  │ Container           ││ ← Circular shape
│  │ shape: circle       ││
│  │ color: primaryBlue  ││
│  │ shadow: 8px blur    ││
│  │                     ││
│  │   ↓ (expand_more)   ││ ← Icon
│  │                     ││
│  └─────────────────────┘│
└─────────────────────────┘
```

## Animation Timeline

### Button Appearance (300ms)

```
Time:  0ms        150ms        300ms
       ├──────────┼──────────┤
Opacity: 0%  →   50%   →    100%
        Hidden   Fading    Visible
```

### Scroll Animation (400ms)

```
Time:  0ms        200ms        400ms
       ├──────────┼──────────┤
Scroll: Start → Middle (faster) → Bottom (slowing)
        (Curves.easeOutCubic)
```

## Threshold Behavior

```
Bottom of screen
     ↓
scrollHeight - 100px ← Threshold (show button here)
     ↓
scrollHeight - 90px
scrollHeight - 80px
...
scrollHeight - 10px
scrollHeight ← At bottom (hide button)

Buffer zone: 100px prevents flickering
```

## Message Streaming Behavior

```
User scrolled up at message 50
                    ↓
New messages arrive (51, 52, 53...)
                    ↓
Button remains visible ← NO AUTO-SCROLL
                    ↓
User clicks button
                    ↓
Smooth scroll to message 53 (latest)
                    ↓
Button hides
```

## Touch Interaction

```
User finger down on button
          ↓
GestureDetector triggers
          ↓
_scrollToLatestMessage() called
          ↓
AnimatedOpacity starts fade out
          ↓
Scroll animation begins
          ↓
ScrollController animates to maxExtent
          ↓
(400ms) Scroll complete
          ↓
Opacity fade completes
          ↓
Button fully hidden
```

## Memory & Performance Profile

```
State Variables:
  _messageScrollController        ≈ 1KB
  _showScrollButton (bool)        ≈ 1 byte
  _scrollThreshold (const)        ≈ 8 bytes
  Total overhead:                 ≈ 1-2KB

Event Listeners:
  Scroll listener:                triggered only on scroll
  setState callbacks:             triggered only on visibility change
  Animation frames:               only when animating

No re-renders of chat messages ✅
No re-builds of ListView ✅
```

## Responsive Design

### Portrait Mode (Mobile)

```
┌─────────────────┐
│                 │
│  Messages       │
│  Content        │
│        ┌───┐    │
│        │ ↓ │    │ ← 20px from edges
│        └───┘    │
│                 │
│ [Input Area]    │
└─────────────────┘
```

### Landscape Mode

```
┌──────────────────────────────────────┐
│ Messages Content Area                │
│                        ┌───┐         │
│                        │ ↓ │ ← Same positioning
│                        └───┘         │
│                                      │
│ [Input Area]                         │
└──────────────────────────────────────┘
```

### With Keyboard Open

```
┌─────────────────┐
│                 │
│  Messages       │
│        ┌───┐    │ ← Button repositions
│        │ ↓ │    │   above keyboard
│        └───┘    │
├─────────────────┤
│ Keyboard        │ ← System keyboard
│ (system)        │
└─────────────────┘
```

## Icon Reference

**Current Icon**: `Icons.expand_more`

```
  ↓
  ↓
```

Alternative icons that work well:

- `Icons.arrow_downward` - Direct downward arrow
- `Icons.south` - Material 3 downward
- `Icons.keyboard_arrow_down` - Compact arrow
- `Icons.expand_circle_down` - Alternative style

## Color Integration

From AppTheme:

```
primaryBlue:        Button background
primaryBlue@0.4:    Shadow color (40% opacity)
white:              Icon color
surfaceElevated:    For potential background variant
```

## Testing Scenarios

### Scenario 1: Normal Scroll

```
1. Load chat with 50 messages
2. User at bottom → Button hidden ✓
3. User scrolls up 200px
4. Button appears with fade ✓
5. User scrolls further up
6. Button stays visible ✓
7. User taps button
8. Smooth scroll to latest ✓
9. Button fades out ✓
```

### Scenario 2: Rapid Scrolling

```
1. User rapid scroll up/down
2. Button toggling is smooth ✓
3. No lag or stuttering ✓
4. Button fades at threshold ✓
```

### Scenario 3: New Messages

```
1. User scrolled up 300px
2. 5 new messages arrive
3. Button still visible ✓
4. Chat doesn't auto-scroll ✓
5. User can click button ✓
6. Jumps to latest ✓
```

## Accessibility Features

- Large tap target (48px+ recommended)
- Clear visual indicator (icon + color)
- Fade animation respects motion preferences
- Position doesn't block critical content
- Works without colors (icons clear)

---

**This reference enables intuitive understanding of the complete floating button behavior and integration.**
