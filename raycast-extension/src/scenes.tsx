import { ActionPanel, Action, List, Icon, showToast, Toast } from "@raycast/api";
import { useEffect, useState } from "react";
import { Scene, getScenes, triggerScene } from "./api";

export default function Command() {
  const [scenes, setScenes] = useState<Scene[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  async function loadScenes() {
    try {
      const data = await getScenes();
      setScenes(data);
    } catch (error) {
      showToast({
        style: Toast.Style.Failure,
        title: "Failed to load scenes",
        message: "Is Homie running?",
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
    } catch (error) {
      showToast({
        style: Toast.Style.Failure,
        title: "Failed to trigger scene",
        message: String(error),
      });
    }
  }

  return (
    <List isLoading={isLoading}>
      {scenes.map((scene) => (
        <List.Item
          key={scene.id}
          title={scene.name}
          subtitle={`${scene.actions} actions`}
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
      ))}
    </List>
  );
}
