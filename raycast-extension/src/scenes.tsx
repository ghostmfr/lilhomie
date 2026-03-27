import { ActionPanel, Action, List, Icon, showToast, Toast } from "@raycast/api";
import { useEffect, useState } from "react";
import { Scene, getScenes, triggerScene } from "./api";

export default function Command() {
  const [scenes, setScenes] = useState<Scene[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  async function loadScenes() {
    setIsLoading(true);
    setError(null);
    try {
      const data = await getScenes();
      setScenes(data);
    } catch (err) {
      setError("Could not connect to lilhomie. Is the app running?");
      showToast({
        style: Toast.Style.Failure,
        title: "Failed to load scenes",
        message: "Is lilhomie running?",
      });
    } finally {
      setIsLoading(false);
    }
  }

  useEffect(() => {
    loadScenes();
  }, []);

  async function handleTrigger(scene: Scene) {
    try {
      await triggerScene(scene.id);
      showToast({
        style: Toast.Style.Success,
        title: `Scene "${scene.name}" triggered`,
      });
    } catch (err) {
      showToast({
        style: Toast.Style.Failure,
        title: "Failed to trigger scene",
        message: String(err),
      });
    }
  }

  return (
    <List isLoading={isLoading} searchBarPlaceholder="Search scenes...">
      {error ? (
        <List.EmptyView
          icon={Icon.ExclamationMark}
          title="lilhomie Not Reachable"
          description={error}
          actions={
            <ActionPanel>
              <Action title="Retry" icon={Icon.ArrowClockwise} onAction={loadScenes} />
            </ActionPanel>
          }
        />
      ) : !isLoading && scenes.length === 0 ? (
        <List.EmptyView
          icon={Icon.Play}
          title="No Scenes Found"
          description="No HomeKit scenes available"
        />
      ) : (
        scenes.map((scene) => (
          <List.Item
            key={scene.id}
            title={scene.name}
            subtitle={scene.home}
            accessories={[{ text: `${scene.actions} action${scene.actions !== 1 ? "s" : ""}` }]}
            icon={Icon.Play}
            actions={
              <ActionPanel>
                <Action
                  title="Trigger Scene"
                  icon={Icon.Play}
                  onAction={() => handleTrigger(scene)}
                />
                <Action
                  title="Refresh"
                  icon={Icon.ArrowClockwise}
                  shortcut={{ modifiers: ["cmd"], key: "r" }}
                  onAction={loadScenes}
                />
              </ActionPanel>
            }
          />
        ))
      )}
    </List>
  );
}
