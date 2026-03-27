import { showHUD, showToast, Toast } from "@raycast/api";
import { getDevices, toggleDevice } from "./api";

interface Arguments {
  device: string;
}

export default async function Command(props: { arguments: Arguments }) {
  const { device: searchTerm } = props.arguments;

  if (!searchTerm || !searchTerm.trim()) {
    await showToast({
      style: Toast.Style.Failure,
      title: "No device specified",
      message: "Enter a device name to toggle",
    });
    return;
  }

  try {
    const devices = await getDevices();

    // Prefer exact match, fall back to partial match
    const searchLower = searchTerm.toLowerCase().trim();
    const match =
      devices.find((d) => d.name.toLowerCase() === searchLower) ||
      devices.find((d) => d.name.toLowerCase().includes(searchLower));

    if (!match) {
      await showToast({
        style: Toast.Style.Failure,
        title: "Device not found",
        message: `No device matching "${searchTerm}"`,
      });
      return;
    }

    await toggleDevice(match.id);

    // match.isOn reflects state before toggle — show the resulting new state
    await showHUD(`${match.name} → ${match.isOn ? "OFF" : "ON"}`);
  } catch (err) {
    const isConnectionError =
      err instanceof Error && (err.message.includes("ECONNREFUSED") || err.message.includes("fetch"));
    await showToast({
      style: Toast.Style.Failure,
      title: isConnectionError ? "lilhomie not running" : "Failed to toggle",
      message: isConnectionError ? "Start the lilhomie app and try again" : String(err),
    });
  }
}
