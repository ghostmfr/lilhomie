import { showHUD, showToast, Toast } from "@raycast/api";
import { getDevices, toggleDevice } from "./api";

interface Arguments {
  device: string;
}

export default async function Command(props: { arguments: Arguments }) {
  const { device: searchTerm } = props.arguments;

  if (!searchTerm) {
    await showToast({
      style: Toast.Style.Failure,
      title: "No device specified",
    });
    return;
  }

  try {
    const devices = await getDevices();

    // Find matching device (fuzzy)
    const searchLower = searchTerm.toLowerCase();
    const match = devices.find(
      (d) =>
        d.name.toLowerCase() === searchLower ||
        d.name.toLowerCase().includes(searchLower)
    );

    if (!match) {
      await showToast({
        style: Toast.Style.Failure,
        title: "Device not found",
        message: `No device matching "${searchTerm}"`,
      });
      return;
    }

    await toggleDevice(match.id);

    await showHUD(`${match.name} → ${match.isOn ? "OFF" : "ON"}`);
  } catch (error) {
    await showToast({
      style: Toast.Style.Failure,
      title: "Failed",
      message: "Is Homie running?",
    });
  }
}
