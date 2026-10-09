import { Action, ActionPanel, Detail, Icon, Keyboard } from "@raycast/api";
import { showFailureToast, usePromise } from "@raycast/utils";
import { artwork, maroctl, Snapshot } from "./maroctl";

function clock(seconds?: number) {
  if (seconds === undefined) return "–";
  const whole = Math.floor(seconds);
  return `${Math.floor(whole / 60)}:${String(whole % 60).padStart(2, "0")}`;
}

function markdown(snapshot?: Snapshot) {
  const loaded = snapshot?.loadedVideo;
  if (!loaded) return snapshot ? "Nothing is loaded in Maro." : "";
  const image = artwork(snapshot, loaded.video);
  return `${image ? `![](${encodeURI(image)})\n\n` : ""}# ${loaded.video.title}\n\n${loaded.video.creator}`;
}

export default function NowPlaying() {
  const { data, isLoading, mutate } = usePromise(() => maroctl("status"));
  const loaded = data?.loadedVideo;
  // ponytail: refreshes after each action, no polling; add an interval if live position matters.
  const run = (...args: string[]) =>
    mutate(maroctl(...args)).catch((error) => showFailureToast(error, { title: "Maro" }));

  return (
    <Detail
      isLoading={isLoading}
      markdown={markdown(data)}
      metadata={
        loaded && (
          <Detail.Metadata>
            <Detail.Metadata.Label title="State" text={data.playback} />
            <Detail.Metadata.Label
              title="Position"
              text={`${clock(loaded.positionSeconds)} / ${clock(loaded.video.durationSeconds)}`}
            />
            <Detail.Metadata.Label
              title="Favorite"
              text={data.favorites.some((favorite) => favorite.id === loaded.video.id) ? "Yes" : "No"}
            />
          </Detail.Metadata>
        )
      }
      actions={
        <ActionPanel>
          <Action title="Toggle Play" icon={Icon.Play} onAction={() => run("toggle")} />
          <Action
            title="Next Track"
            icon={Icon.Forward}
            shortcut={{ modifiers: ["cmd"], key: "arrowRight" }}
            onAction={() => run("next")}
          />
          <Action
            title="Previous Track"
            icon={Icon.Rewind}
            shortcut={{ modifiers: ["cmd"], key: "arrowLeft" }}
            onAction={() => run("previous")}
          />
          <Action
            title="Replay Track"
            icon={Icon.RotateAntiClockwise}
            shortcut={Keyboard.Shortcut.Common.Refresh}
            onAction={() => run("replay")}
          />
          {loaded && (
            <Action
              title="Toggle Favorite"
              icon={Icon.Heart}
              shortcut={{ modifiers: ["cmd"], key: "f" }}
              onAction={() => run("favorite", "toggle", loaded.video.id)}
            />
          )}
          <Action
            title="Show Player"
            icon={Icon.AppWindow}
            shortcut={Keyboard.Shortcut.Common.Open}
            onAction={() => run("player")}
          />
          <Action
            title="Show Search"
            icon={Icon.MagnifyingGlass}
            shortcut={{ modifiers: ["cmd"], key: "l" }}
            onAction={() => run("search")}
          />
        </ActionPanel>
      }
    />
  );
}
