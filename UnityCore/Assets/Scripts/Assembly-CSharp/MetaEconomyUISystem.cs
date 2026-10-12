using System.Collections.Generic;
using TMPro;
using UnityEngine;

public class MetaEconomyUISystem : MonoBehaviour
{
	[SerializeField]
	private List<TextMeshProUGUI> metaTextsList;

	private void Awake()
	{
		Singleton<MetaEconomySystem>.Instance.OnMetaChange += OnMetaChange;
		OnMetaChange(Singleton<MetaEconomySystem>.Instance.GetCurrentMetaPoints());
	}

	private void OnDisable()
	{
		Singleton<MetaEconomySystem>.Instance.OnMetaChange -= OnMetaChange;
	}

	private void OnMetaChange(int metaPoints)
	{
		foreach (TextMeshProUGUI metaTexts in metaTextsList)
		{
			metaTexts.text = metaPoints.ToString();
		}
	}
}
