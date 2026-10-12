using System;
using UnityEngine;
using UnityEngine.UI;

public class ControlCancelUIImage : MonoBehaviour
{
	[SerializeField]
	private Image cancelImage;

	private void OnEnable()
	{
		InputDataStore instance = Singleton<InputDataStore>.Instance;
		instance.OnControlChanged = (Action)Delegate.Combine(instance.OnControlChanged, new Action(SetCancelImage));
		SetCancelImage();
	}

	private void OnDisable()
	{
		InputDataStore instance = Singleton<InputDataStore>.Instance;
		instance.OnControlChanged = (Action)Delegate.Remove(instance.OnControlChanged, new Action(SetCancelImage));
	}

	public void SetCancelImage()
	{
		string playerInputDeviceInputBinding = Singleton<InputDataStore>.Instance.GetDeviceCancelKeys()[0];
		cancelImage.sprite = Singleton<InputDataStore>.Instance.GetDeviceBindingIcon(playerInputDeviceInputBinding);
	}
}
