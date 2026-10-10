# Maro

- The Raycast extension in `raycast/` uses **npm** (`npm install`, `npm run <script>`) and commits `package-lock.json`: `ray publish` rejects any other lockfile (bun, pnpm, yarn). Don't add `bun.lock` or `pnpm-lock.yaml`.
- The Raycast extension only shells out to `maroctl`; new controls start as a `CommandName` in `Sources/MaroCore/CommandProtocol.swift`, not as extension-side logic.
