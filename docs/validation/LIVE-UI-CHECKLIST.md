# Final alpha live UI review

Record the tested commit, app path, executable SHA-256, OS version, reviewer/method, date, and evidence filenames. Use the isolated review app and non-private test documents. Preserve any existing user documents. These checks require visible interaction; automated document APIs and cached view images are insufficient.

## Inspector (#10)

- [ ] At a normal window size, select theme cards and confirm the selected card, source frontmatter and preview agree.
- [ ] Collapse and expand Theme previews. Confirm there is no theme dropdown and selection is retained.
- [ ] Confirm Look precedes Layout. Collapse/expand Look previews and select Neo, Classic and Hand-drawn; confirm cards and drawing style change together.
- [ ] Use default theme/look controls; confirm each removes its own override while preserving unrelated source settings. Undo and redo an appearance change.
- [ ] Manually set a custom appearance value in a test document; confirm Custom is shown without overwriting the value.
- [ ] Choose ELK and Dagre in a flowchart; confirm Connections appears only for Dagre and its choices change paths. Confirm dedicated swimlane layout is retained.
- [ ] Repeat essential selections, scrolling and collapse/expand in light and dark app appearances, at 1260×820 and the inspector-visible minimum 960×540. Check the inspector-closed 820-wide window too.
- [ ] Use keyboard navigation and activation on the visible theme/look controls, disclosure controls, layout picker, export and Fit. Record any required macOS keyboard-navigation setting.
- [ ] Inspect accessibility names and selected/expanded/value states; ensure default theme and default look controls are distinguishable, zoom/Fit/close have names, and text size has a meaningful label/value.
- [ ] Confirm interface selection/toggles follow the configured macOS accent. Record the observed accent; diagram palettes remain document-owned. Restore any temporary system/app preference changes.

## Gallery (#11)

Create a new unsaved test document with a distinctive non-private comment and record its source. For each action below, use the gallery itself and confirm an independent document opens, renders with the correct diagram type, and leaves the original source unchanged:

- [ ] Horizontal swimlanes.
- [ ] Vertical swimlanes.
- [ ] UML use cases.

Switch between all four documents and confirm their source/appearance remain independent. Close only test documents created for this review, handling their save prompts deliberately.

## Final evidence (#12–#13)

- [ ] Inspect native live diagram output and representative SVG/PNG/PDF exports for missing text, clipped content and disconnected arrows. Distinguish documented upstream limitations from a new regression.
- [ ] Save normal/minimum and light/dark screenshots of non-private samples from the tested app. Replace the README image only with a verified current capture.
- [ ] Add factual results and evidence hashes to the release report. Keep failed/unperformed checks open; do not mark a test passed from source inspection alone.
- [ ] Review the final documentation, relative links and GitHub-rendered Markdown. Update issue checklists only for completed criteria.
