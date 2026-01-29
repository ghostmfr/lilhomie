import { ActionPanel, Action, List, Icon, Color, showToast, Toast } from "@raycast/api";
import { useEffect, useState } from "react";
import { Device, getDevices, toggleDevice } from "./api";

interface Arguments {
  device?: string;
}

export default function Command(props: { arguments: Arguments }) {
  const [devices, setDevices] = useState<Device[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchText, setSearchText] = useState(props.arguments.device || "");

  async function loadDevices() {
    try {
      const data = await getDevices();
      setDevices(data);
    } catch (error) {
      showToast({
        style: Toast.Style.Failure,
        title: "Failed to load devices",
        message: "Is Homie running?",
      });
    } finally {
      setIsLoading(false);
    }
  }

  useEffect(() => {
    loadDevices();
  }, []);

  const filteredDevices = searchText
    ? devices.filter(
        (d) =>
          d.name.toLowerCase().includes(searchText.toLowerCase()) ||
          d.room?.toLowerCase().includes(searchText.toLowerCase())
      )
    : devices;

  async function handleToggle(device: Device) {
    try {
      await toggleDevice(device.id);
      showToast({
        style: Toast.Style.Success,
        title: `${device.name} → ${device.isOn ? "OFF" : "ON"}`,
      });
      loadDevices();
    } catch (error) {
      showToast({
        style: Toast.Style.Failure,
        title: "Failed to toggle",
        message: String(error),
      });
    }
  }

  return (
    <List
      isLoading={isLoading}
      searchText={searchText}
      onSearchTextChange={setSearchText}
      searchBarPlaceholder="Search devices..."
    >
      {filteredDevices.map((device) => (
        <List.Item
          key={device.id}
          title={device.name}
          subtitle={device.room}
          icon={{
            source: device.isOn ? Icon.LightBulbOn : Icon.LightBulbOff,
            tintColor: device.isOn ? Color.Yellow : Color.SecondaryText,
          }}
          accessories={[{ text: device.isOn ? "ON" : "OFF" }]}
          actions={
            <ActionPanel>
              <Action
                title="Toggle"
                icon={Icon.Switch}
                onAction={() => handleToggle(device)}
              />
            </ActionPanel>
          }
        />
      ))}
    </List>
  );
}
