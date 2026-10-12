using System.Collections.Generic;
using UnityEngine;

[CreateAssetMenu(fileName = "Device Display Settings", menuName = "Scriptable Objects/Device Display Settings", order = 1)]
public class DeviceDisplaySettings : ScriptableObject
{
	public string deviceDisplayName;

	public Sprite deviceDisplayIcon;

	public List<string> deviceRebindCancelKeys = new List<string>();

	public List<string> deviceIgnoredKeys = new List<string>();

	public List<CustomInputContextIcon> customContextIcons = new List<CustomInputContextIcon>();
}
