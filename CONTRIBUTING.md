# Contributing to MacMermaid

Thanks for helping improve MacMermaid. Bug reports, feature requests, documentation, design feedback, and pull requests are welcome.

## Report a bug

Search [existing issues](https://github.com/opendream/macmermaid/issues) first. If the problem has not been reported, open an issue with:

- What you expected and what happened instead.
- Steps to reproduce, including a small Mermaid example when relevant.
- Your macOS version and the MacMermaid version or commit you built.
- A screenshot for visual problems, or the relevant error message for build failures.

Use sample diagrams and remove private information from screenshots and logs.

## Suggest an improvement

Describe the problem you want to solve and how the proposed change would help. Examples or sketches are useful. Discussion before a large feature or architectural change can help avoid work that needs substantial revision; small fixes can go straight to a pull request.

## Work on a change

1. Fork the repository and clone your fork.
2. Create a branch for the change: `git switch -c your-change`.
3. Follow the [development guide](docs/DEVELOPMENT.md) to build the app.
4. Keep the change focused and update any affected documentation.
5. Open a pull request against `main`.

Follow the surrounding Swift, JavaScript, and formatting conventions. Add or update regression coverage when it helps demonstrate a behavior change. Keep diagram rendering offline and preserve the separation between app/editor appearance and diagram themes.

## Check your work

For application changes, run:

```sh
./scripts/test.sh
./scripts/build.sh
```

For renderer, export, document, or theme changes, also run the [packaged smoke test](docs/DEVELOPMENT.md#packaged-smoke-test). For UI changes, inspect light and dark appearances at normal and minimum window sizes, and include before/after screenshots when useful. Automated snapshots do not replace checking the native app.

For documentation-only changes, check links, examples, and the rendered Markdown. An app rebuild is not needed unless the instructions or behavior being documented require verification.

If you change bundled dependencies or palettes, follow the [third-party license update procedure](third-party/README.md). Retain upstream notices and use dependencies compatible with the project's licensing.

## Submit a pull request

Explain the problem, the resulting behavior, and how you verified it. Link related issues and include any known limitations or checks you could not run. Avoid including build outputs, local preferences, or unrelated changes.

Keep discussion respectful and focused on the work. Maintainers may request changes before merging.

## License

MacMermaid's original code uses the [MIT License](LICENSE). Contributions should be compatible with it. Third-party code and assets retain their own licenses and must include the appropriate attribution; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
