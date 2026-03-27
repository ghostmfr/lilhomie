import { ActionPanel, Action, List, Icon, Color, showToast, Toast } from "@raycast/api";
import { useEffect, useState } from "react";
import { Device, getDevices, toggleDevice } from "./api";

interface Arguments {
  device?: string;
}

export default function Command(props: { arguments: Arguments }) {
  const [devices, setDevices] = useState<Device[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [searchText, setSearchText] = useState(props.arguments.device || "");

  async function loadDevices() {
    setIsLoading(true);
    setError(null);
    try {
      const data = await getDevices();
      setDevices(data);
    } catch (err) {
      setError("Could not connect to lilhomie. Is the app running?");
      showToast({
        style: Toast.Style.Failure,
        title: "Failed to load devices",
        message: "Is lilhomie running?",
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
    } catch (err) {
      showToast({
        style: Toast.Style.Failure,
        title: "Failed to toggle",
        message: String(err),
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
      {error ? (
        <List.EmptyView
          icon={Icon.ExclamationMark}
          title="lilhomie Not Reachable"
          description={error}
          actions={
            <ActionPanel>
              <Action title="Retry" icon={Icon.ArrowClockwise} onAction={loadDevices} />
            </ActionPanel>
          }
        />
      ) : !isLoading && filteredDevices.length === 0 ? (
        <List.EmptyView
          icon={Icon.MagnifyingGlass}
          title="No Matching Devices"
          description={searchText ? `No devices matching "${searchText}"` : "No HomeKit devices available"}
        />
      ) : (
        filteredDevices.map((device) => (
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
                <Action
                  title="Refresh"
                  icon={Icon.ArrowClockwise}
                  shortcut={{ modifiers: ["cmd"], key: "r" }}
                  onAction={loadDevices}
                />
              </ActionPanel>
            }
          />
        ))
      )}
    </List>
  );
}
