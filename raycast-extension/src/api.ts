const BASE_URL = "http://127.0.0.1:8420";

export interface Device {
  id: string;
  name: string;
  room?: string;
  type: string;
  isOn: boolean;
  brightness?: number;
}

export interface Scene {
  id: string;
  name: string;
  home: string;
  actions: number;
}

export interface DevicesResponse {
  devices: Device[];
}

export interface ScenesResponse {
  scenes: Scene[];
}

export interface ActionResponse {
  success?: boolean;
  device?: Device;
  error?: string;
}

async function request<T>(method: string, path: string, body?: object): Promise<T> {
  const options: RequestInit = {
    method,
    headers: {
      "Content-Type": "application/json",
    },
  };

  if (body) {
    options.body = JSON.stringify(body);
  }

  const response = await fetch(`${BASE_URL}${path}`, options);

  if (!response.ok) {
    const error = await response.json().catch(() => ({ error: "Unknown error" }));
    throw new Error(error.error || `HTTP ${response.status}`);
  }

  return response.json();
}

export async function getDevices(): Promise<Device[]> {
  const response = await request<DevicesResponse>("GET", "/devices");
  return response.devices;
}

export async function getScenes(): Promise<Scene[]> {
  const response = await request<ScenesResponse>("GET", "/scenes");
  return response.scenes;
}

export async function toggleDevice(deviceId: string): Promise<ActionResponse> {
  return request<ActionResponse>("POST", `/device/${encodeURIComponent(deviceId)}/toggle`);
}

export async function setDevice(
  deviceId: string,
  on: boolean,
  brightness?: number
): Promise<ActionResponse> {
  const body: { on: boolean; brightness?: number } = { on };
  if (brightness !== undefined) {
    body.brightness = brightness;
  }
  return request<ActionResponse>("POST", `/device/${encodeURIComponent(deviceId)}/set`, body);
}

export async function triggerScene(sceneId: string): Promise<ActionResponse> {
  return request<ActionResponse>("POST", `/scene/${encodeURIComponent(sceneId)}/trigger`);
}

export async function checkHealth(): Promise<boolean> {
  try {
    await request<{ status: string }>("GET", "/health");
    return true;
  } catch {
    return false;
  }
}
