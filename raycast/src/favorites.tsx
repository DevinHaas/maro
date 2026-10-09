import { Action, ActionPanel, Icon, List, showHUD } from "@raycast/api";
import { showFailureToast, usePromise } from "@raycast/utils";
import { artwork, maroctl } from "./maroctl";

export default function Favorites() {
  const { data, isLoading, mutate } = usePromise(() => maroctl("status"));

  return (
    <List isLoading={isLoading}>
      <List.EmptyView title="No favorites yet" icon={Icon.Heart} />
      {data?.favorites.map((video) => (
        <List.Item
          key={video.id}
          title={video.title}
          subtitle={video.creator}
          icon={artwork(data, video) ?? Icon.Music}
          accessories={data.loadedVideo?.video.id === video.id ? [{ icon: Icon.SpeakerOn, tooltip: "Loaded" }] : []}
          actions={
            <ActionPanel>
              <Action
                title="Play"
                icon={Icon.Play}
                onAction={() =>
                  maroctl("select", video.id)
                    .then(() => showHUD(`▶ ${video.title}`))
                    .catch((error) => showFailureToast(error, { title: "Maro" }))
                }
              />
              <Action
                title="Remove Favorite"
                icon={Icon.HeartDisabled}
                style={Action.Style.Destructive}
                shortcut={{ modifiers: ["cmd"], key: "backspace" }}
                onAction={() =>
                  mutate(maroctl("favorite", "remove", video.id)).catch((error) =>
                    showFailureToast(error, { title: "Maro" }),
                  )
                }
              />
            </ActionPanel>
          }
        />
      ))}
    </List>
  );
}
