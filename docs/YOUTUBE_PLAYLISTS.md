# Personal YouTube playlists

Maro's library window has Search and Playlists tabs. Playlists belong to your
YouTube account; local favorites remain separate. No server or additional package
is required. The YouTube Data API manages playlists; the existing player continues
to resolve and play audio.

## Connect your account once

1. In [Google Cloud Console](https://console.cloud.google.com/), create or choose
   a project and enable **YouTube Data API v3** under APIs & Services.
2. Configure Google Auth Platform: enter an app name (Maro) and your contact email.
   Choose an External audience for a personal Google account. While the app is in
   Testing, add your Google account as a test user.
3. Configure Data Access with
   `https://www.googleapis.com/auth/youtube.force-ssl`. Google has no playlist-only
   editing permission; its consent wording covers other YouTube operations too.
   Maro uses this permission only for reading and editing playlists.
4. Create an OAuth client with application type **Desktop app** and download its
   JSON configuration. A web-app client or an API key alone will not work.
5. Open Maro's library window, open the **YouTube account** menu, then **Import Google
   credentials…**, and choose that JSON file. It is saved in macOS Keychain, not
   in the project or player-state file. Do not commit the downloaded credentials.
6. Select **Connect YouTube**, sign in to the Google account/channel whose
   playlists you want, and grant access. Maro opens your normal browser and listens
   briefly on a random localhost port. Return to Maro after consent completes.

For ongoing personal use, change the Google Auth audience's publishing status to
**In production**. Testing authorizations for YouTube expire after seven days.
Google permits a personal-use app with fewer than 100 users to remain unverified;
you may see an unverified-app warning. Production status removes the testing-specific
expiry, but tokens can still be revoked or expire for other reasons. Reconnect
from the Account menu when necessary.

References: [desktop OAuth setup](https://developers.google.com/youtube/v3/guides/auth/installed-apps),
[native authorization flow](https://developers.google.com/identity/protocols/oauth2/native-app),
[publishing status](https://support.google.com/cloud/answer/15549945?hl=en),
[personal-use verification exemption](https://support.google.com/cloud/answer/13464323?hl=en).

## Use playlists

- The persistent library shows all your owned playlists. Use **Refresh library**
  to refresh it manually. Select a playlist to load all its videos, including beyond
  YouTube's first results page.
- Create playlist makes a private playlist and immediately adds it to the list while
  refreshing from YouTube. Rename changes its name while preserving its description.
  Open a playlist's actions sheet and choose Delete playlist… to permanently delete it from YouTube
  after confirmation. This leaves the videos themselves intact. Change visibility
  directly on YouTube.
- Open a search result's actions menu and choose **Add to playlist…**, or use the plus-list button
  beside the current video's title. Choose a destination playlist and select Add.
- Within a playlist, drag an entry's handle to a new position, or open its ellipsis
  actions sheet to move it to a chosen position or remove it. Removing a
  video removes only that occurrence from the YouTube playlist; it does not delete
  the video or another occurrence. Some playlists need Manual ordering enabled on
  YouTube before reordering through the API.
- Confirmed video removal updates Maro immediately even if the
  next YouTube list response lags. Add checks every playlist page by video ID and
  refuses an existing video; titles are not used for identity. Existing duplicate
  occurrences are preserved and can still be removed individually.
- The green playlist Play button starts at the beginning. Each row's Play button starts there. Playback
  advances in saved order, skips entries it cannot play, and stops at the end.
  Previous/next use the active playlist, even if you search for something else.
- Playback takes a snapshot of the order when you press Play. Edits and refreshes
  affect the next playlist playback, not the queue already playing. Selecting a
  search result or favorite leaves the playlist queue. The queue is session-only;
  reopening Maro restores the last video paused, as before.
- Unavailable entries remain on YouTube until you explicitly remove them. No shuffle,
  repeat, offline editing, or background synchronization is implemented.

## Failed requests and disconnecting

Failed refreshes keep previously loaded data visible with an outdated-data label.
No edits are queued. A write timeout can mean YouTube saved the change but its reply
was lost: choose **Refresh YouTube** and inspect the list before submitting that edit again.
Maro never automatically repeats a failed write. If a write succeeded but its
following refresh failed, the status explicitly says it was saved.

During a reorder, Maro shows the optimistic order and serializes the save. A definite
rejection restores the confirmed order and offers **Retry move**. An uncertain reply
blocks further edits until you refresh; it never automatically repeats the write.
Confirmed moves remain visible if the following refresh is unavailable or still
returns the previous order.

Account → Disconnect on this Mac removes Maro's saved tokens and visible library,
retaining only the desktop-client configuration so you can reconnect. It leaves
your playlists untouched. To revoke Google's grant too, remove Maro from your
[Google account connections](https://myaccount.google.com/connections).

## Verification

Run `swift test --no-parallel`. `PlaylistTests.swift` exercises pagination, owned-list
requests, duplicate occurrences, private creation, metadata-preserving rename,
item-specific edits, API failures, playback order/end/skip/cancellation, and the
loopback callback's state validation. The callback test needs permission to listen
on localhost. No test uses a real Google account or modifies a YouTube playlist.

Live acceptance requires your OAuth configuration and consent: connect, create a
private test playlist, add/reorder/remove a video, confirm the results on YouTube,
make a change on YouTube, refresh Maro, and play the playlist through its end.
