using System.Collections.Generic;
using TMPro;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

public class GameOverMenuManager : MonoBehaviour
{
	[SerializeField]
	private GameObject SelectedButton;

	[SerializeField]
	private GameObject GameOverPanel;

	[SerializeField]
	private GameObject insideGameOverPanel;

	[SerializeField]
	private Image GameOverBlackPanel;

	[SerializeField]
	private List<SocrePanelController> socrePanelControllersList;

	[SerializeField]
	private SocrePanelController socreScorePanelController;

	[SerializeField]
	private SocrePanelController metaScorePanelController;

	[SerializeField]
	private TextMeshProUGUI ratingText;

	[SerializeField]
	private TextMeshProUGUI GameOverText;

	[Space]
	[SerializeField]
	private GameObject NewRankObject;

	[SerializeField]
	private TextMeshProUGUI rankText;

	public void ShowGameOverUI(bool isWon)
	{
		List<ScoreRatingContainer> scoreRatingContainers = SceneSingleton<RatingSystemManager>.Instance.GetScoreRatingContainers();
		ScoreRatingContainer scoreContainer = SceneSingleton<RatingSystemManager>.Instance.GetScoreContainer();
		LetterRating scoreRating = SceneSingleton<RatingSystemManager>.Instance.GetScoreRating();
		if (scoreRatingContainers.Count > socrePanelControllersList.Count)
		{
			Debug.LogError("Score Rating sent is bigger than the number of Score Game Over Panels");
		}
		foreach (SocrePanelController socrePanelControllers in socrePanelControllersList)
		{
			socrePanelControllers.gameObject.SetActive(value: false);
		}
		for (int i = 0; i < scoreRatingContainers.Count; i++)
		{
			socrePanelControllersList[i].gameObject.SetActive(value: true);
			socrePanelControllersList[i].SetPanel(scoreRatingContainers[i]);
		}
		socreScorePanelController.SetPanel(scoreContainer);
		metaScorePanelController.SetPanel(new ScoreRatingContainer("GameOver_Scraps", Singleton<RatingDataStore>.Instance.GetLetterMetaPoints(scoreRating)), addPts: false);
		ratingText.text = scoreRating.title;
		if (isWon)
		{
			GameOverText.text = Singleton<LocalizationSystem>.Instance.GetIDString("GameOver_Won");
		}
		else
		{
			GameOverText.text = Singleton<LocalizationSystem>.Instance.GetIDString("GameOver_Lost");
		}
		if (Singleton<DemoBuildManager>.Instance != null && Singleton<DemoBuildManager>.Instance.IsDemoEnabled())
		{
			GameOverText.text = Singleton<LocalizationSystem>.Instance.GetIDString("Demo_Thanks");
		}
		GameOverPanel.SetActive(value: true);
		GetComponent<CanvasGroup>().interactable = true;
		EventSystem.current.SetSelectedGameObject(SelectedButton);
		TweenPanel();
		Singleton<InputDataStore>.Instance.SetUIActionMap();
	}

	public void SetNewRank(int currentRank)
	{
		NewRankObject.SetActive(value: true);
		rankText.text = "#" + currentRank;
		TweenController.ScaleV3(NewRankObject.transform, 3f, 1f, TweenDuration.Very_Short, ignoreTimeScale: true, () =>
		{
			Singleton<AudioManager>.Instance.PlaySFX(AudioClipTypes.UI_Rate);
			TweenController.PunchScale(NewRankObject.transform, 0.5f, TweenDuration.Super_Short, ignoreTimeScale: true);
		});
	}

	private void TweenPanel()
	{
		foreach (SocrePanelController socrePanelControllers in socrePanelControllersList)
		{
			ObjectSystem.ReScale(socrePanelControllers.gameObject, 0f);
		}
		ObjectSystem.ReScale(metaScorePanelController.gameObject, 0f);
		ObjectSystem.ReScale(ratingText.gameObject, 0f);
		ObjectSystem.ReScale(socreScorePanelController.gameObject, 0f);
		TweenController.KillTweens(insideGameOverPanel.transform);
		TweenController.ScaleV3(insideGameOverPanel.transform, 0f, 0.75f, TweenDuration.Very_Short, ignoreTimeScale: true);
		TweenController.KillTweens(GameOverBlackPanel.transform);
		ImageSystem.Alphalizer(GameOverBlackPanel, 0.75f, TweenDuration.Very_Short, IgnoreTimeScale: true);
		TweenController.DelayedCall(TweenDuration.Very_Short, () =>
		{
			TweenPanelElemnets();
		}, ignoreTimeScale: true);
	}

	private void TweenPanelElemnets()
	{
		foreach (SocrePanelController socrePanelControllers in socrePanelControllersList)
		{
			TweenController.ScaleV3(socrePanelControllers.transform, 0f, 1f, TweenDuration.Very_Short, ignoreTimeScale: true);
		}
		TweenController.DelayedCall(TweenDuration.Short, () =>
		{
			TweenScore();
		}, ignoreTimeScale: true);
	}

	private void TweenScore()
	{
		TweenController.ScaleV3(metaScorePanelController.transform, 0f, 1f, TweenDuration.Very_Short, ignoreTimeScale: true);
		TweenController.ScaleV3(socreScorePanelController.transform, 0f, 1f, TweenDuration.Very_Short, ignoreTimeScale: true, () =>
		{
			TweenController.ScaleV3(ratingText.transform, 3f, 1f, TweenDuration.Very_Short, ignoreTimeScale: true, () =>
			{
				Singleton<AudioManager>.Instance.PlaySFX(AudioClipTypes.UI_Rate);
				TweenController.PunchScale(ratingText.transform, 0.5f, TweenDuration.Super_Short, ignoreTimeScale: true);
			});
		});
	}
}
