using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.InputSystem;

[CreateAssetMenu(fileName = "Device Display Configurator", menuName = "Scriptable Objects/Device Display Configurator", order = 1)]
public class DeviceDisplayConfigurator : ScriptableObject
{
	[Serializable]
	public struct DeviceSet
	{
		public string deviceRawPath;

		public DeviceDisplaySettings deviceDisplaySettings;
	}

	public List<DeviceSet> listDeviceSets = new List<DeviceSet>();

	private Color fallbackDisplayColor = Color.white;

	private Dictionary<string, DeviceSet> devicesSetDict;

	public List<string> GetDeviceBindingCancelKeys(PlayerInput playerInput)
	{
		if (devicesSetDict == null)
		{
			BuildDict();
		}
		string key = playerInput.devices[0].ToString();
		return devicesSetDict[key].deviceDisplaySettings.deviceRebindCancelKeys;
	}

	public List<string> GetDeviceBindingIgnoreKeys(PlayerInput playerInput)
	{
		if (devicesSetDict == null)
		{
			BuildDict();
		}
		string key = playerInput.devices[0].ToString();
		return devicesSetDict[key].deviceDisplaySettings.deviceIgnoredKeys;
	}

	public DeviceDisplaySettings GetDeviceSetting(InputDevice inputDevice)
	{
		if (devicesSetDict == null)
		{
			BuildDict();
		}
		string key = inputDevice.ToString();
		if (devicesSetDict.ContainsKey(key))
		{
			return devicesSetDict[key].deviceDisplaySettings;
		}
		return null;
	}

	public Sprite GetDeviceBindingIcon(PlayerInput playerInput, string playerInputDeviceInputBinding)
	{
		if (devicesSetDict == null)
		{
			BuildDict();
		}
		if (playerInput == null || playerInput.devices.Count == 0) return null;
        string key = playerInput.devices[0].ToString();
        DeviceSet deviceSet;
        return devicesSetDict.TryGetValue(key,out deviceSet) ? FilterForDeviceInputBinding(deviceSet, playerInputDeviceInputBinding) : null;
	}

	private Sprite FilterForDeviceInputBinding(DeviceSet targetDeviceSet, string inputBinding)
	{
		for (int i = 0; i < targetDeviceSet.deviceDisplaySettings.customContextIcons.Count; i++)
		{
			if (targetDeviceSet.deviceDisplaySettings.customContextIcons[i].customInputContextString == inputBinding)
			{
				return targetDeviceSet.deviceDisplaySettings.customContextIcons[i].customInputContextIcon;
			}
		}
		return null;
	}

	public void BuildDict()
	{
		devicesSetDict = new Dictionary<string, DeviceSet>();
		for (int i = 0; i < listDeviceSets.Count; i++)
		{
			devicesSetDict.Add(listDeviceSets[i].deviceRawPath, listDeviceSets[i]);
		}
	}
}
