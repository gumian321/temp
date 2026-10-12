using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

public class PauseMenuManager : MonoBehaviour
{
	[SerializeField]
	private GameObject SelectedButton;

	[SerializeField]
	private GameObject PausePanel;

	[SerializeField]
	private GameObject insidePausePanel;

	[SerializeField]
	private Image PauseBlackPanel;

	[Space]
	[SerializeField]
	private Slider MasterAudioSlider;

	[SerializeField]
	private Slider MusicAudioSlider;

	[SerializeField]
	private Slider SFXAudioSlider;

	public void ShowPauseUI()
	{
		GetComponent<CanvasGroup>().interactable = true;
		EventSystem.current.SetSelectedGameObject(SelectedButton);
		PausePanel.SetActive(value: true);
		Singleton<InputDataStore>.Instance.SetUIActionMap();
		MasterAudioSlider.value = AudioSlidersController.GetMasterSlider();
		MusicAudioSlider.value = AudioSlidersController.GetMusicSlider();
		SFXAudioSlider.value = AudioSlidersController.GetSFXSlider();
		TweenController.KillTweens(insidePausePanel.transform);
		TweenController.ScaleV3(insidePausePanel.transform, 0f, 0.75f, TweenDuration.Very_Short, ignoreTimeScale: true);
		TweenController.KillTweens(PauseBlackPanel.transform);
		ImageSystem.Alphalizer(PauseBlackPanel, 0.75f, TweenDuration.Very_Short, IgnoreTimeScale: true);
	}

	public void HidePauseUI()
	{
		GetComponent<CanvasGroup>().interactable = false;
		TweenController.KillTweens(insidePausePanel.transform);
		TweenController.ScaleV3(insidePausePanel.transform, 0.75f, 0f, TweenDuration.Very_Short, ignoreTimeScale: true, () =>
		{
			PausePanel.SetActive(value: false);
		});
		TweenController.KillTweens(PauseBlackPanel.transform);
		ImageSystem.Alphalizer(PauseBlackPanel, 0f, TweenDuration.Very_Short, IgnoreTimeScale: true);
		SaveSystem.SaveGame();
	}

	public void MasterAudioSliderChanged()
	{
		AudioSlidersController.SetMasterSlider(MasterAudioSlider.value);
		Singleton<AudioSlidersController>.Instance.OnSlidersChange();
	}

	public void MusicAudioSliderChanged()
	{
		AudioSlidersController.SetMusicSlider(MusicAudioSlider.value);
		Singleton<AudioSlidersController>.Instance.OnSlidersChange();
	}

	public void SFXAudioSliderChanged()
	{
		AudioSlidersController.SetSFXSlider(SFXAudioSlider.value);
		Singleton<AudioSlidersController>.Instance.OnSlidersChange();
	}
}
