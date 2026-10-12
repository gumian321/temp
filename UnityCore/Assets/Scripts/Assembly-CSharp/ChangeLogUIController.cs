using TMPro;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

public class ChangeLogUIController : MonoBehaviour
{
	[SerializeField]
	private GameObject selectedButton;

	[SerializeField]
	private Vector3 camPos;

	[SerializeField]
	private GameObject backButton;

	[SerializeField]
	private TextAsset textAsset;

	[SerializeField]
	private TextMeshProUGUI changeLogText;

	[SerializeField]
	private ScrollRect scrollRect;

	private void Awake()
	{
		changeLogText.text = textAsset.text;
	}

	public void ShowChangeLog()
	{
		SceneSingleton<MainMenuManager>.Instance.SetOnEscKeyPressed(SceneSingleton<MainMenuManager>.Instance.ShowMainMenu);
		SceneSingleton<MainMenuCameraManager>.Instance.SetCamTargetPos(camPos, () =>
		{
			GetComponent<CanvasGroup>().interactable = true;
			EventSystem.current.SetSelectedGameObject(selectedButton);
			backButton.SetActive(value: true);
			backButton.GetComponent<Button>().interactable = true;
		});
		SceneSingleton<MainMenuCameraManager>.Instance.SetCamTargetZoom();
		scrollRect.verticalScrollbar.value = 1f;
	}

	public void BackButton()
	{
		GetComponent<CanvasGroup>().interactable = false;
		backButton.SetActive(value: false);
		backButton.GetComponent<Button>().interactable = false;
		SceneSingleton<MainMenuManager>.Instance.ShowMainMenu();
	}
}
