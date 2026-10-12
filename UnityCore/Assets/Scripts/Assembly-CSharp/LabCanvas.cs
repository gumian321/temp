using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class LabCanvas : MonoBehaviour
{
	[SerializeField]
	private MenuBuildingManager menuBuildingManager;

	[SerializeField]
	private CanvasGroup categoryPanelCG;

	[SerializeField]
	private CanvasGroup picksPanelCG;

	[Space]
	[SerializeField]
	private List<GameObject> turretsButtonsObj;

	[SerializeField]
	private List<GameObject> effectsButtonsObj;

	[Space]
	[SerializeField]
	private bool deleteMode;

	[SerializeField]
	private Button deleteButton;

	[SerializeField]
	private Button resetButton;

	[Space]
	[SerializeField]
	private bool IsPlayMode;

	[SerializeField]
	private Button playStopButton;

	[SerializeField]
	private Image playStopImage;

	[SerializeField]
	private Sprite playSprite;

	[SerializeField]
	private Sprite stopSprite;

	public void ShowTurrets()
	{
		foreach (GameObject item in turretsButtonsObj)
		{
			item.SetActive(value: true);
		}
		foreach (GameObject item2 in effectsButtonsObj)
		{
			item2.SetActive(value: false);
		}
	}

	public void ShowEffects()
	{
		foreach (GameObject item in turretsButtonsObj)
		{
			item.SetActive(value: false);
		}
		foreach (GameObject item2 in effectsButtonsObj)
		{
			item2.SetActive(value: true);
		}
	}

	public void ToggleDeleteMode()
	{
		deleteMode = !deleteMode;
		menuBuildingManager.SetDeleteMode(deleteMode);
		if (deleteMode)
		{
			deleteButton.image.enabled = false;
			resetButton.gameObject.SetActive(value: false);
			playStopButton.gameObject.SetActive(value: false);
		}
		else
		{
			deleteButton.image.enabled = true;
			resetButton.gameObject.SetActive(value: true);
			playStopButton.gameObject.SetActive(value: true);
		}
	}

	public void EndDeleteMode()
	{
		deleteMode = false;
		menuBuildingManager.SetDeleteMode(deleteMode);
		deleteButton.image.enabled = true;
		resetButton.gameObject.SetActive(value: true);
		playStopButton.gameObject.SetActive(value: true);
	}

	public void TogglePlayStop()
	{
		IsPlayMode = !IsPlayMode;
		if (IsPlayMode)
		{
			playStopImage.sprite = stopSprite;
			deleteButton.interactable = false;
			resetButton.interactable = false;
			picksPanelCG.interactable = false;
			categoryPanelCG.interactable = false;
			menuBuildingManager.SaveCores();
		}
		else
		{
			playStopImage.sprite = playSprite;
			deleteButton.interactable = true;
			resetButton.interactable = true;
			picksPanelCG.interactable = true;
			categoryPanelCG.interactable = true;
			menuBuildingManager.ResetCores();
		}
	}

	public void DeleteAll()
	{
		menuBuildingManager.DestroyAllCores();
	}
}
