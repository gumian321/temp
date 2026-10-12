using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

public class ControlUIManager : SceneSingleton<ControlUIManager>
{
	[SerializeField]
	private GameObject selectedButton;

	[SerializeField]
	private CanvasGroup managerCG;

	[SerializeField]
	private Vector3 OptionCamPos;

	[Space]
	[SerializeField]
	private GameObject backButton;

	[SerializeField]
	private GameObject ControlsContainerParent;

	[SerializeField]
	private GameObject controlsContainerObject;

	[SerializeField]
	private List<ControlUIContainer> controlUIContainersList;

	public bool isRebinding;

	public bool canRebind = true;

	[SerializeField]
	private GameObject InvertAimXButton;

	[SerializeField]
	private GameObject deInvertAimXButton;

	[SerializeField]
	private GameObject InvertAimYButton;

	[SerializeField]
	private GameObject deInvertAimYButton;

	[SerializeField]
	private GameObject SwitchAimButton;

	[SerializeField]
	private GameObject deSwitchAimButton;

	public void ShowControlsMenu()
	{
		SceneSingleton<MainMenuManager>.Instance.SetOnEscKeyPressed(BackButton);
		LoadControlsValues();
		SceneSingleton<MainMenuCameraManager>.Instance.SetCamTargetPos(OptionCamPos, () =>
		{
			GetComponent<CanvasGroup>().interactable = true;
			EventSystem.current.SetSelectedGameObject(selectedButton);
			backButton.SetActive(value: true);
			backButton.GetComponent<Button>().interactable = true;
		});
		SceneSingleton<MainMenuCameraManager>.Instance.SetCamTargetZoom();
		RefreshUI();
	}

	public void LoadControlsValues()
	{
		RefreshUI();
	}

	public void ResetButton()
	{
		SaveSystem.ResetPlayerInput();
		RefreshUI();
	}

	public void RefreshUI()
	{
		SaveSystem.LoadPlayerInput();
		foreach (ControlUIContainer controlUIContainers in controlUIContainersList)
		{
			controlUIContainers.UpdateContainerUI();
		}
		RefreshControllerSetting();
	}

	public void BackButton()
	{
		GetComponent<CanvasGroup>().interactable = false;
		backButton.SetActive(value: false);
		backButton.GetComponent<Button>().interactable = false;
		LoadControlsValues();
		SaveSystem.SaveGame();
		Object.FindObjectOfType<OptionMenuManager>().ShowOptionMenu();
	}

	public void ApplyNewRebind()
	{
		SaveSystem.SavePlayerInput();
		StartCoroutine(RefreshControlsUI());
	}

	private IEnumerator RefreshControlsUI()
	{
		yield return new WaitForSecondsRealtime(0.5f);
		Singleton<InputDataStore>.Instance.OnControlApplied?.Invoke();
		RefreshUI();
	}

	public void OnRebindStarted()
	{
		isRebinding = true;
		managerCG.interactable = false;
	}

	public void OnRebindEnded()
	{
		StopAllCoroutines();
		StartCoroutine(WaitAtLeastAFrameAndSave());
	}

	private IEnumerator WaitAtLeastAFrameAndSave()
	{
		yield return new WaitForEndOfFrame();
		yield return new WaitForEndOfFrame();
		isRebinding = false;
		managerCG.interactable = true;
	}

	public void RefreshControllerSetting()
	{
		InvertAimXButton.SetActive(!SaveSystem.GetInvertAimXSetting());
		deInvertAimXButton.SetActive(SaveSystem.GetInvertAimXSetting());
		InvertAimYButton.SetActive(!SaveSystem.GetInvertAimYSetting());
		deInvertAimYButton.SetActive(SaveSystem.GetInvertAimYSetting());
		SwitchAimButton.SetActive(!SaveSystem.GetSwitchAimSetting());
		deSwitchAimButton.SetActive(SaveSystem.GetSwitchAimSetting());
	}

	public void InvertAimX(bool flag)
	{
		SaveSystem.SaveInvertAimXSetting(flag);
		RefreshControllerSetting();
		if (!flag)
		{
			EventSystem.current.SetSelectedGameObject(InvertAimXButton);
		}
		else
		{
			EventSystem.current.SetSelectedGameObject(deInvertAimXButton);
		}
	}

	public void InvertAimY(bool flag)
	{
		SaveSystem.SaveInvertAimYSetting(flag);
		RefreshControllerSetting();
		if (!flag)
		{
			EventSystem.current.SetSelectedGameObject(InvertAimYButton);
		}
		else
		{
			EventSystem.current.SetSelectedGameObject(deInvertAimYButton);
		}
	}

	public void SwitchAim(bool flag)
	{
		SaveSystem.SaveSwitchAimSetting(flag);
		RefreshControllerSetting();
		if (!flag)
		{
			EventSystem.current.SetSelectedGameObject(SwitchAimButton);
		}
		else
		{
			EventSystem.current.SetSelectedGameObject(deSwitchAimButton);
		}
	}
}
