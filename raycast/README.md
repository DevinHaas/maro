# Maro for Raycast

Private Raycast extension that controls Maro by running `maroctl` (one JSON line per call; `maroctl` launches Maro if needed).

Uses **npm** (`ray publish` requires `package-lock.json`):

```sh
npm install
npm run dev      # import into Raycast and hot-reload
npm run build    # ray build -e dist
npm run lint     # owner check 404s locally for private orgs; publish authenticates
npm run publish  # private store of the maro-app organization
```

Commands: Now Playing, Favorites, Play/Pause, Next, Previous (the free Raycast team plan caps private extensions at 5).
Replay, Toggle Favorite, Show Player, and Show Search are actions inside Now Playing.
Published privately to the `maro-app` organization store with `npm run publish`.
Preference `maroctl Path` defaults to `~/Applications/Maro Local/bin/maroctl` (the `scripts/install.py` wrapper).
