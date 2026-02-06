# Markdown All in One (VS Code) – Features and How to Use Them

This guide summarises the **Markdown All in One** extension features and practical ways to use them in day-to-day writing in Visual Studio Code.
Source: Visual Studio Marketplace listing (Markdown All in One by Yu Zhang).

## Table of contents
1. [Keyboard shortcuts](#keyboard-shortcuts)
2. [Table of contents tools](#table-of-contents-tools)
3. [List editing](#list-editing)
4. [Print Markdown to HTML](#print-markdown-to-html)
5. [GitHub Flavoured Markdown helpers](#github-flavoured-markdown-helpers)
6. [Math](#math)
7. [Auto completions](#auto-completions)
8. [Other productivity features](#other-productivity-features)
9. [Key commands you will use most](#key-commands-you-will-use-most)
10. [Useful settings](#useful-settings)

## Keyboard shortcuts

The extension adds shortcuts to speed up common Markdown editing. You can trigger these via the keyboard or via the **Command Palette**.

How to use
1. Place the cursor on a word, or select text.
2. Use the shortcut to apply or toggle formatting.

Common shortcuts
- **Toggle bold**: `Ctrl/Cmd + B`
- **Toggle italic**: `Ctrl/Cmd + I`
- **Toggle strikethrough**: `Alt + S` (Windows)
- **Toggle heading level up**: `Ctrl + Shift + ]`
- **Toggle heading level down**: `Ctrl + Shift + [`
- **Toggle math environment**: `Ctrl/Cmd + M`
- **Check/Uncheck task list item**: `Alt + C`
- **Toggle preview**: `Ctrl/Cmd + Shift + V`
- **Preview to side**: `Ctrl/Cmd + K` then `V`

Tip: If your organisation has standardised keybinds, you can adjust these in **Keyboard Shortcuts** (`File` > `Preferences` > `Keyboard Shortcuts`) by searching for commands prefixed with `markdown.extension`.

## Table of contents tools

Create and maintain a Table of Contents (TOC) in your Markdown file.

How to use
- Open the **Command Palette** (`Ctrl/Cmd + Shift + P`).
- Run **Markdown All in One: Create Table of Contents** to insert a TOC at the cursor position.
- Run **Markdown All in One: Update Table of Contents** to refresh an existing TOC.

Auto-update on save
- By default, the TOC updates whenever you save the file.
- To disable this behaviour, set:
  - `markdown.extension.toc.updateOnSave` to `false`

Making the TOC play nicely with GitHub, GitLab, or other renderers
- Set `markdown.extension.toc.slugifyMode` to match the platform you publish to (for example `github` or `gitlab`).

Controlling which headings appear
- Omit a heading by adding `<!-- omit from toc -->` to the end of the heading line, or place the comment above the heading.
- Restrict heading depth via `markdown.extension.toc.levels` (for example `2..4`).
- Omit named headings via `markdown.extension.toc.omittedFromToc` (per file path in settings).

Section numbering
- Use **Markdown All in One: Add/Update section numbers** to number headings (useful for internal documentation and governance packs).
- Use **Markdown All in One: Remove section numbers** to remove numbering.

## List editing

Improves list behaviour so Markdown lists feel more like a proper editor experience.

What it does (typical behaviours)
- Smarter handling of `Enter` to continue or end a list item.
- Better indentation/outdent behaviour with `Tab` and `Backspace`.
- Auto-fix ordered list numbering while you edit.

How to use
- Just edit lists normally; the behaviour kicks in as you type.
- If you want consistent indentation rather than “adaptive” behaviour, set:
  - `markdown.extension.list.indentationSize` (for example `2` or `4`)

## Print Markdown to HTML

Export Markdown to HTML for sharing, publishing, or converting to PDF.

How to use (single file)
- Command Palette: **Markdown: Print current document to HTML**

How to use (batch export)
- Command Palette: **Markdown: Print documents to HTML**

Handy notes
- Add a title to the exported HTML by placing this comment on the first line of the Markdown file:
  - `<!-- title: Your Title -->`
- Links to `.md` files are converted to `.html` during export.
- For PDF delivery, it is usually easier to export to HTML then print to PDF from a browser (for consistent layouts and margins).

## GitHub Flavoured Markdown helpers

Includes helpers commonly used in GitHub Flavoured Markdown (GFM).

Table formatter
- Formats and aligns Markdown tables for readability.
- Run via Command Palette or use the default keybinding (varies by OS; often `Ctrl + Shift + I` on Linux).

Task lists
- Works with task list syntax:
  - `- [ ] Not started`
  - `- [x] Done`
- Toggle checkboxes using `Alt + C` when the cursor is on the item.

## Math

Provides KaTeX-based math support, including toggling a math environment.

How to use
- Use `Ctrl/Cmd + M` to toggle a math environment.
- If you need more specialised maths features, consider using a dedicated maths extension and disable this extension’s math support:
  - Set `math.enabled` to `false` (in this extension’s settings namespace, if applicable in your environment)

## Auto completions

Adds smart completions while writing Markdown.

Images and files
- Auto-completes file paths for images and links.
- Respects VS Code’s `search.exclude` by default, so you do not get noise from excluded folders.
- Settings to know:
  - `markdown.extension.completion.respectVscodeSearchExclude`
  - `markdown.extension.completion.root` (sets a root folder when paths start with `/`)

Math functions
- Offers completions for common maths functions.
- Supports KaTeX macros via `markdown.extension.katex.macros`.

Reference links
- Helps complete reference-style links, improving consistency in long documents.

## Other productivity features

Paste link on selected text
- Select text then paste a URL; the extension converts it into a Markdown link.
- Example result: `[Selected text](https://example.com)`

Close Preview keybinding
- Adds a **Close Preview** keybinding so you can close the preview tab using the same keystroke pattern as opening preview.

## Key commands you will use most

From the Command Palette, search for:
- **Markdown All in One: Create Table of Contents**
- **Markdown All in One: Update Table of Contents**
- **Markdown All in One: Add/Update section numbers**
- **Markdown All in One: Remove section numbers**
- **Markdown All in One: Toggle code span**
- **Markdown All in One: Toggle code block**
- **Markdown All in One: Print current document to HTML**
- **Markdown All in One: Print documents to HTML**
- **Markdown All in One: Toggle math environment**
- **Markdown All in One: Toggle list** (cycles list markers; can be configured)

## Useful settings

These are the settings most teams adjust when standardising Markdown across a repo.

TOC
- `markdown.extension.toc.updateOnSave`: automatically update TOC
- `markdown.extension.toc.levels`: heading levels included in TOC
- `markdown.extension.toc.slugifyMode`: link style for target platforms
- `markdown.extension.toc.orderedList`: ordered vs unordered TOC list
- `markdown.extension.toc.unorderedList.marker`: `-`, `*`, or `+`
- `markdown.extension.toc.omittedFromToc`: omit selected headings by file

Lists
- `markdown.extension.list.indentationSize`: `adaptive` or fixed number
- `markdown.extension.list.toggle.candidate-markers`: list markers to cycle through
- `markdown.extension.orderedList.autoRenumber`: auto-fix numbering
- `markdown.extension.orderedList.marker`: `ordered` or `one`

Printing
- `markdown.extension.print.theme`: exported HTML theme
- `markdown.extension.print.onFileSave`: export on save
- `markdown.extension.print.imgToBase64`: embed images
- `markdown.extension.print.validateUrls`: URL validation

Formatting indicators
- `markdown.extension.bold.indicator`: `**` or `__`
- `markdown.extension.italic.indicator`: `*` or `_`

If you want this guide tailored to your team’s repo conventions (for example, doc templates, consistent TOC depth, and table styles), you can standardise these settings in a workspace `.vscode/settings.json` file.
