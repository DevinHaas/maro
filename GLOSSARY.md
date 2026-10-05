# Maro

Language for navigating Maro's music interface with the keyboard.

## Language

**Vim navigation**:
Maro's optional directional keyboard navigation: `h` moves left, `j` down, `k` up, and `l` right. Moving to a control does not activate it.
_Avoid_: Vim editor mode

**Navigation target**:
An enabled control eligible to receive focus through Vim navigation in the current interface.
_Avoid_: Clickable element, node

**Navigation region**:
A coherent area of Maro's interface, such as the sidebar, track list, or bottom player, through which directional navigation proceeds.
_Avoid_: Graph
