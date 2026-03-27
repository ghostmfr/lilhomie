import { ActionPanel, Action, List, Icon, Color, showToast, Toast } from "@raycast/api";
import { useEffect, useState } from "react";
import { Device, getDevices, toggleDevice, setDevice } from "./api";

export default function Command() {
  const [devices, setDevices] = useState<Device[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [selectedRoom, setSelectedRoom] = useState<string | null>(null);

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

  const rooms = [...new Set(devices.map((d) => d.room).filter(Boolean))] as string[];

  const filteredDevices = selectedRoom ? devices.filter((d) => d.room === selectedRoom) : devices;

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

  async function handleSetBrightness(device: Device, brightness: number) {
    try {
      await setDevice(device.id, true, brightness);
      showToast({
        style: Toast.Style.Success,
        title: `${device.name} set to ${brightness}%`,
      });
      loadDevices();
    } catch (err) {
      showToast({
        style: Toast.Style.Failure,
        title: "Failed to set brightness",
        message: String(err),
      });
    }
  }

  function getAccessories(device: Device): List.Item.Accessory[] {
    return [
      device.brightness !== undefined && device.isOn ? { text: `${device.brightness}%` } : null,
      { text: device.isOn ? "ON" : "OFF" },
    ].filter((a): a is List.Item.Accessory => a !== null);
  }

  return (
    <List
      isLoading={isLoading}
      searchBarAccessory={
        rooms.length > 0 ? (
          <List.Dropdown
            tooltip="Filter by Room"
            onChange={(value) => setSelectedRoom(value === "all" ? null : value)}
          >
            <List.Dropdown.Item title="All Rooms" value="all" />
            {rooms.map((room) => (
              <List.Dropdown.Item key={room} title={room} value={room} />
            ))}
          </List.Dropdown>
        ) : undefined
      }
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
          icon={Icon.LightBulbOff}
          title="No Devices Found"
          description={selectedRoom ? `No devices in "${selectedRoom}"` : "No HomeKit devices available"}
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
            accessories={getAccessories(device)}
            actions={
              <ActionPanel>
                <Action
                  title={device.isOn ? "Turn Off" : "Turn On"}
                  icon={device.isOn ? Icon.LightBulbOff : Icon.LightBulbOn}
                  onAction={() => handleToggle(device)}
                />
                {device.type === "light" && (
                  <>
                    <Action
                      title="Set to 25%"
                      icon={Icon.CircleProgress25}
                      onAction={() => handleSetBrightness(device, 25)}
                    />
                    <Action
                      title="Set to 50%"
                      icon={Icon.CircleProgress50}
                      onAction={() => handleSetBrightness(device, 50)}
                    />
                    <Action
                      title="Set to 75%"
                      icon={Icon.CircleProgress75}
                      onAction={() => handleSetBrightness(device, 75)}
                    />
                    <Action
                      title="Set to 100%"
                      icon={Icon.CircleProgress100}
                      onAction={() => handleSetBrightness(device, 100)}
                    />
                  </>
                )}
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
