import { getPreferenceValues, showHUD } from "@raycast/api";
import { execFile } from "node:child_process";
import { homedir } from "node:os";

// Mirrors the camelCase Codable output of MaroCore's CommandResponse (protocol version 1).
export type Video = { id: string; title: string; creator: string; durationSeconds?: number; thumbnailURL?: string };
export type Snapshot = {
  loadedVideo?: { video: Video; positionSeconds: number };
  favorites: Video[];
  playback: "idle" | "paused" | "buffering" | "playing" | "ended";
  localThumbnailPaths?: Record<string, string>;
};

type Response = { version: number; ok: boolean; snapshot?: Snapshot; error?: { code: string; message: string } };

export function maroctl(...args: string[]): Promise<Snapshot> {
  const { maroctlPath } = getPreferenceValues<{ maroctlPath: string }>();
  return new Promise((resolve, reject) => {
    execFile(maroctlPath.replace(/^~(?=\/)/, homedir()), args, { timeout: 15_000 }, (failure, stdout, stderr) => {
      // A failed command still prints its JSON error line on stdout and exits 1.
      let response: Response | undefined;
      try {
        response = JSON.parse(stdout);
      } catch {
        response = undefined;
      }
      if (response?.ok && response.snapshot) return resolve(response.snapshot);
      const message = response?.error?.message ?? (stderr.trim() || failure?.message || "maroctl returned no response");
      reject(new Error(message));
    });
  });
}

export function artwork(snapshot: Snapshot, video: Video): string | undefined {
  return snapshot.localThumbnailPaths?.[video.id] ?? video.thumbnailURL;
}

// Shared body for every no-view command.
export function runHUD(...args: string[]) {
  return async () => {
    try {
      const snapshot = await maroctl(...args);
      const title = snapshot.loadedVideo?.video.title;
      await showHUD(title ? `${snapshot.playback === "playing" ? "▶" : "⏸"} ${title}` : "Maro: done");
    } catch (error) {
      await showHUD(`Maro: ${(error as Error).message}`);
    }
  };
}
