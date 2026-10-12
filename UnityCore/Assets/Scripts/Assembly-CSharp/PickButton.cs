using UnityEngine;
using UnityEngine.UI;

public class PickButton : MonoBehaviour
{
	[SerializeField]
	private Button button;

	[SerializeField]
	private GameObject lockImage;

	public void SetLocked(bool x)
	{
		button.interactable = x;
		lockImage.SetActive(!x);
	}
}
