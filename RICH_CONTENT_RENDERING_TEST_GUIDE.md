# Rich Content Rendering Test Guide

This guide provides comprehensive test cases for verifying that the frontend properly renders all rich content features (LaTeX, markdown, code blocks, tables, emojis).

## Test Cases to Verify in the App

### Test 1: LaTeX Inline Mathematics

**Expected:** Inline formulas should render with proper mathematical notation
**Test Query:** "What is the quadratic formula?"
**Expected Response Should Contain:**

- Inline formula: $ax^2 + bx + c = 0$
- Solution formula: $x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}$

### Test 2: LaTeX Display Equations

**Expected:** Display equations should be centered on their own line
**Test Query:** "Show me the integral of x^2 from 0 to 1"
**Expected Response Should Contain:**
$$\int_0^1 x^2 dx = \left[\frac{x^3}{3}\right]_0^1 = \frac{1}{3}$$

### Test 3: Scientific Notation with Greek Letters

**Expected:** Greek letters and scientific notation should render properly
**Test Query:** "Explain Einstein's equation"
**Expected Response Should Contain:**

- $E = mc^2$ (inline)
- Special characters: $\Delta$, $\mu$, $\sigma$, $\alpha$, $\beta$

### Test 4: Code Blocks with Language Specification

**Expected:** Code should display with proper syntax highlighting background
**Test Query:** "Write a hello world program in Python"
**Expected Response Should Contain:**

```python
def hello_world():
    print("Hello, World!")

if __name__ == "__main__":
    hello_world()
```

### Test 5: Multiple Code Languages

**Test Query:** "Show me a simple loop in JavaScript, Python, and Dart"
**Expected:** Should have properly labeled code blocks for each language:

```javascript
for (let i = 0; i < 5; i++) {
  console.log(i);
}
```

```python
for i in range(5):
    print(i)
```

```dart
for (int i = 0; i < 5; i++) {
    print(i);
}
```

### Test 6: Markdown Bold and Italic

**Expected:** Text formatting should be visually distinct
**Test Query:** "Define photosynthesis"
**Expected Response Should Contain:**

- **Bold terms** for key concepts
- _Italic text_ for emphasis or new terminology
- **_Bold and italic_** for critical important items

### Test 7: Heading Structure

**Expected:** Headings should have proper hierarchy and sizing
**Test Query:** "Explain the structure of an atom"
**Expected Response Should Start With:**

```
## Atomic Structure

### Overview
[explanation]

### Main Components
[components list]

### Electron Shells
[electron explanation]
```

### Test 8: Bulleted Lists

**Expected:** List items should display with proper bullet points
**Test Query:** "List the planets in our solar system"
**Expected Response Should Contain:**

- Mercury
- Venus
- Earth
- Mars
- Jupiter
- Saturn
- Uranus
- Neptune

### Test 9: Numbered Lists

**Expected:** Steps should display with proper numbering
**Test Query:** "How do I make a sandwich?"
**Expected Response Should Contain:**

1. Get two slices of bread
2. Spread your choice of condiment
3. Add fillings
4. Press together gently
5. Cut diagonally (optional)
6. Serve immediately

### Test 10: Markdown Tables

**Expected:** Table data should be properly aligned and readable
**Test Query:** "Compare the properties of solids, liquids, and gases"
**Expected Response Should Contain a Table Like:**
| State | Shape | Volume | Density |
|-------|-------|--------|---------|
| Solid | Fixed | Fixed | High |
| Liquid | Variable | Fixed | Medium |
| Gas | Variable | Variable | Low |

### Test 11: Blockquotes (Important Notes)

**Expected:** Blockquotes should be visually distinct
**Test Query:** "What's the most important thing about investing?"
**Expected Response Should Contain:**

> **Important:** Always diversify your investments to minimize risk.

### Test 12: Mathematical Fractions

**Expected:** Fractions should render with proper horizontal bars
**Test Query:** "What is 1/3 plus 1/4?"
**Expected Response Should Contain:**
$$\frac{1}{3} + \frac{1}{4} = \frac{4 + 3}{12} = \frac{7}{12}$$

### Test 13: Roots and Radicals

**Expected:** Square roots and nth roots should render properly
**Test Query:** "What is the square root of 16?"
**Expected Response Should Contain:**
$\sqrt{16} = 4$
$\sqrt[3]{27} = 3$

### Test 14: Summation and Integration

**Expected:** Mathematical operators should display correctly
**Test Query:** "Explain integration and summation"
**Expected Response Should Contain:**
$$\sum_{i=1}^n i = \frac{n(n+1)}{2}$$
$$\int_a^b f(x) dx$$

### Test 15: Emojis in Content

**Expected:** Emojis should render correctly within text
**Test Query:** "What are the main benefits of exercise?"
**Expected Response Should Use Approved Emojis:** 🙂 ✅ 🔬 📚 ✨ 🚀 📊 📈 💡 🎯

### Test 16: Mixed Content Response

**Expected:** All formatting elements should work together seamlessly
**Test Query:** "Explain photosynthesis in detail"
**Expected Response Should Include:**

- Proper heading structure (## ##)
- LaTeX formulas (e.g., $6CO_2 + 6H_2O \xrightarrow{light} C_6H_{12}O_6 + 6O_2$)
- Bulleted lists
- Code blocks (if showing equations/algorithms)
- Blockquotes for important notes
- **Bold** terms and _italic_ emphasis
- Relevant emojis (✅ 📚 ✨)

### Test 17: Error Handling - Malformed LaTeX

**Expected:** If LaTeX is invalid, should display gracefully (e.g., as raw text in monospace)
**Test Action:** Ask for something intentionally complex
**Verification:** Should not crash, should either render or show fallback

### Test 18: Long Formulas with Horizontal Scrolling

**Expected:** Wide formulas should scroll horizontally without breaking layout
**Test Query:** "Show me a complex physics equation"
**Expected Response Should Contain Long Formula Like:**
$$F = G\frac{m_1 m_2}{r^2} \text{ or } E = \frac{1}{2}mv^2 + mgh + \frac{1}{2}kx^2$$

### Test 19: Nested Lists

**Expected:** Nested bullet points should display with proper indentation
**Test Query:** "Outline the structure of the human body"
**Expected Response Should Contain:**

- Systems
  - Skeletal system
    - Bones
    - Joints
  - Muscular system
    - Smooth muscles
    - Skeletal muscles

### Test 20: Unicode and Special Characters

**Expected:** Unicode characters, accents, and special symbols should render
**Test Query:** "Write a greeting in multiple languages"
**Expected Response Should Contain:**

- café (accents)
- Ω (omega)
- ≈ (approximately equal)
- ∞ (infinity)
- × (multiplication)

## Automated Test Cases (For Dev Use)

You can create a test widget that pre-populates the chat with test messages:

```dart
// Comprehensive test message
const String RICH_CONTENT_TEST = '''
## LaTeX Math Test

Inline: \$E=mc^2\$ and \$\\frac{a}{b}\$

Display:
\$\$\\int_0^1 x^2 dx = \\frac{1}{3}\$\$

## Code Examples

\`\`\`python
def greet(name):
    print(f"Hello, {name}!")
\`\`\`

## Lists

- Item 1
- Item 2
  - Nested item
- Item 3

1. First
2. Second
3. Third

## Markdown

**Bold text** and *italic text*

### Subsection

Content here

## Table

| Column 1 | Column 2 |
|----------|----------|
| Value A  | Value B  |
| Value C  | Value D  |

> Important note in blockquote

Test complete! ✅ 📚 ✨
''';
```

## Manual Verification Checklist

- [ ] Inline LaTeX formulas render with proper mathematical notation
- [ ] Display math ($$) appears centered on own line
- [ ] Greek letters (α, β, γ, Δ, Σ) render correctly
- [ ] Code blocks show language label and copy button
- [ ] Multiple code languages display separately
- [ ] Bold text (**text**) displays with correct weight
- [ ] Italic text (_text_) displays with correct style
- [ ] # ## ### headings have proper size hierarchy
- [ ] Bullet lists display with proper bullet points
- [ ] Numbered lists preserve correct numbering
- [ ] Tables render with proper alignment
- [ ] Blockquotes display distinct styling
- [ ] URLs are clickable
- [ ] Emojis render in approved colors
- [ ] Layout doesn't break on wide formulas (horizontal scroll works)
- [ ] Nested lists show proper indentation
- [ ] No crashes with malformed input
- [ ] Copy button works for code blocks
- [ ] Reactions (👍👎) work on messages
- [ ] Detailed mode shows enhanced formatting

## Known Limitations

1. **LaTeX Complexity:** Very complex LaTeX may fail gracefully (shows raw text)
2. **Table Size:** Very large tables may require horizontal scrolling
3. **Emoji Limitations:** Only approved emojis from the whitelist render specially
4. **Nested Code:** Code blocks cannot be nested (markdown limitation)
5. **Display Width:** Content adapts to screen width, no horizontal scroll for text

## Quick Test Commands

Use these queries to quickly test specific features:

- "What is E=mc^2?" → Tests inline LaTeX
- "Solve: x^2 + 2x + 1 = 0" → Tests formula heavy content
- "Write Python code" → Tests code blocks
- "Compare A and B" → Tests tables
- "Explain in detail" → Triggers detailed mode with enhanced formatting
- "What are the steps?" → Tests numbered lists
- "List items" → Tests bullet lists
