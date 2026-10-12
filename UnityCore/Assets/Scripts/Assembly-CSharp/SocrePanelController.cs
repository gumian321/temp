using TMPro;
using UnityEngine;

public class SocrePanelController : MonoBehaviour
{
	[SerializeField]
	private TextMeshProUGUI scorePanelTitleText;

	[SerializeField]
	private TextMeshProUGUI scorePanelTitleBackground;

	[SerializeField]
	private TextMeshProUGUI scorePanelValueText;

	[SerializeField]
	private TextMeshProUGUI scorePanelValueBackground;

	public void SetPanel(ScoreRatingContainer scoreRating, bool addPts = true)
	{
		string text = scoreRating.title;
		if (Singleton<LocalizationSystem>.Instance.HasIDString(scoreRating.title))
		{
			text = Singleton<LocalizationSystem>.Instance.GetIDString(scoreRating.title);
		}
		scorePanelTitleText.text = text;
		scorePanelTitleBackground.text = "<mark=#ffffff>" + text + "</mark>";
		if (addPts)
		{
			scorePanelValueText.text = scoreRating.value + " pts.";
			scorePanelValueBackground.text = "<mark=#ffffff>" + scoreRating.value + " pts.</mark>";
		}
		else
		{
			scorePanelValueText.text = scoreRating.value.ToString();
			scorePanelValueBackground.text = "<mark=#ffffff>" + scoreRating.value + "</mark>";
		}
	}
}
