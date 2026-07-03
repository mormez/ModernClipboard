# Modern Clipboard — Quick Start Guide

**Version 1.2**

---

## Step 1 — The Menu Bar Icon

Modern Clipboard runs as a menu bar application. After it launches, its icon appears in the menu bar at the top-right of the screen. The app has no Dock icon; all functions are accessed from the menu bar icon and the keyboard shortcuts described in this guide.

> **Note:** Modern Clipboard is configured to launch automatically at login. To disable this, open **Preferences → General** and turn off **Launch Modern Clipboard at login**.

---

## Step 2 — Grant Accessibility Permission

Modern Clipboard needs Accessibility permission to paste on your behalf.

When prompted, click **Open Accessibility Settings** → find **Modern Clipboard** → toggle it **on**.

> Missed the prompt? Open the menu bar icon → **Preferences** → **General** → click **Open Accessibility Settings**.

---

## Step 3 — Copy Something

Copy any text as you normally would (⌘C, i.e. Command-C). Modern Clipboard captures it automatically — no action needed.

---

## Step 4 — Paste from History

Press **⇧⌘V** (Shift-Command-V) from anywhere to open the history popup.

| Key | What it does |
|-----|-------------|
| ↓ / ↑ | Move between items |
| → / ← | Open a folder · go back |
| ⏎ (Return) | Paste the selected item |
| 1 – 9, 0 | Instantly paste items 1–10 (0 = the 10th) |
| Esc (Escape) | Close without pasting |

The popup closes and pastes into whatever app you were using.

> **Tip:** Copied formatting (bold, links, colors) is always preserved and pasted back by default. Want it to match the destination's existing style instead? Hold **⌥ Option** (configurable) while pasting from the popup — this pastes plain text that takes on the formatting already in place where you're pasting.

### Step 4.5 — Clear Your History

Want to wipe everything you've copied? Open **Preferences → General**, then click **Clear Clipboard History…** in the Clipboard History section to remove all saved items at once.

---
<!-- page-break -->

## Step 5 — Create a Snippet

Snippets are text blocks you save once and reuse forever — great for signatures, templates, or common replies.

1. Press **⇧⌘S** (Shift-Command-S) to open the snippets popup.
2. Click **Edit Snippets…** below the folder list to open the snippet editor.
3. Click **+** in the left column to create a folder.
4. Select your folder, then click **+** in the middle column to add a snippet.
5. Enter a title and your text, then click **Save**.

Press **⇧⌘S** (Shift-Command-S) anywhere to open your snippets and paste one.

---

## Step 6 — Quick Snippets (Paste with One Key)

At the top of your snippets you'll find a special **⚡ Quick Snippets** folder. It holds up to **10** snippets, each mapped to a number key so you can paste it the instant the popup opens — no arrow keys, no clicking.

When you press **⇧⌘S**, the Quick Snippets folder opens automatically. Just press the number next to a snippet to paste it:

| Key | Pastes |
|-----|--------|
| 1 – 9, 0 | Paste Quick Snippet 1–10 (0 = the 10th) |
| ⏎ (Return) | The selected snippet |
| Esc (Escape) | Close without pasting |

To set them up, open **Edit Snippets…** and select the **⚡ Quick Snippets** folder. It comes pre-filled with a few examples — replace them with your own most-used text. Add up to 10; the folder can't be deleted, and slot **10** is always the **0** key.

> **Tip:** Prefer that the Quick Snippets folder not open automatically? Turn off **Auto-open Quick Snippets folder** in **Preferences → General** (Snippets section). Your other folders are always one arrow-key away.

---

## Step 7 — Exclude Sensitive Apps

Keep clipboard contents from password managers and other sensitive apps out of your history entirely.

1. Open **Preferences → Exclude Apps**.
2. Click **+** and choose an app, or click **Auto-exclude known password managers** to add common ones (1Password, Bitwarden, LastPass, and more) automatically.
3. Anything copied in an excluded app never enters the clipboard history.

---

## That's it!

| Action | Shortcut | |
|--------|----------|--------------|
| Open clipboard history | **⇧⌘V** | Shift-Command-V |
| Open snippets | **⇧⌘S** | Shift-Command-S |

Ran into a problem or have an idea? Open **Preferences → Help** to report a bug, request a feature, or export diagnostics.
