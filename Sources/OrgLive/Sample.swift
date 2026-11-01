/// Initial editor content: a tour of the org syntax the editor highlights and renders.
let sample = """
#+TITLE: org-live
#+AUTHOR: Your Name
#+DATE: <2026-11-01 Sun>

Type org-mode on this side; the HTML appears below. Replace this text with
your own, then save it as .org or .html.

* Text
Inline markup: *bold*, /italic/, _underline_, +strike-through+, =verbatim=
and ~code~. Superscripts like E = mc^2 work too.

Links: [[https://orgmode.org][the org-mode site]], a bare URL such as
https://orgmode.org/manual/, and a footnote reference.[fn:1]

Timestamps: <2026-11-02 Mon 10:00>, inactive [2026-10-31 Sat], and a range
<2026-11-03 Tue>--<2026-11-05 Thu>.

* TODO [#A] Lists :lists:
- Unordered items
  - nest by indenting
- [X] checkbox, done
- [ ] checkbox, open

1. Ordered items
2. count themselves

- Term :: a description list pairs a term with its definition

** DONE Sub-heading with a tag :done:
Headings go three levels deep here, and further in org.

*** Third level

* Tables
| Language | Year | Typing  |
|----------+------+---------|
| Swift    | 2014 | static  |
| Lisp     | 1958 | dynamic |

* Blocks
#+begin_src swift
let greeting = "Hello, *org*"
print(greeting)
#+end_src

#+begin_quote
Org mode is for keeping notes, maintaining TODO lists, planning projects,
and authoring documents with a fast and effective plain-text system.
#+end_quote

#+begin_example
Example blocks keep their text exactly as written.
#+end_example

#+begin_center
Centered text
#+end_center

-----

# A comment line: in the source, not in the output.

[fn:1] Footnotes are collected at the end of the document.
"""
