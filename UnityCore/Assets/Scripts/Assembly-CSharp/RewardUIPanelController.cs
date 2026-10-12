using System.Collections.Generic;
using TMPro;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

public class RewardUIPanelController : MonoBehaviour
{
	[SerializeField]
	private RewardSystemUIManager rewardSystemUIManager;

	[SerializeField]
	private TextMeshProUGUI rewardTitle;

	[Space]
	[SerializeField]
	private Image rewardButtonImage;

	[SerializeField]
	public Button rewardSelectButton;

	[SerializeField]
	private GameObject rewardLock;

	[SerializeField]
	private List<GameObject> starsList;

	[Space]
	[Header("Single Reward")]
	[SerializeField]
	private Image rewardSprite;

	[SerializeField]
	private Image rewardOverlay;

	[Space]
	[Header("Multi Reward")]
	[SerializeField]
	private Image rewardSprite1;

	[SerializeField]
	private Image rewardOverlay1;

	[SerializeField]
	private Image rewardSprite2;

	[SerializeField]
	private Image rewardOverlay2;

	private Reward reward;

	public void SetPanel(RewardSystemUIManager rewardSystemUIManager)
	{
		this.rewardSystemUIManager = rewardSystemUIManager;
	}

	private void ResetPanel()
	{
		rewardSprite1.gameObject.SetActive(value: false);
		rewardSprite2.gameObject.SetActive(value: false);
		rewardOverlay1.gameObject.SetActive(value: false);
		rewardOverlay2.gameObject.SetActive(value: false);
		rewardOverlay.gameObject.SetActive(value: false);
		rewardSprite.gameObject.SetActive(value: false);
		for (int i = 0; i < starsList.Count; i++)
		{
			starsList[i].SetActive(value: false);
		}
		rewardButtonImage.color = Color.white;
		rewardTitle.text = "";
		rewardLock.SetActive(value: false);
	}

	public void SetPanelReward(Reward reward)
	{
		ResetPanel();
		if (reward == null)
		{
			SetNullPanel();
			return;
		}
		this.reward = reward;
		rewardTitle.text = reward.GetRewardTitle();
		if (reward is CrusedReward)
		{
			rewardSprite1.gameObject.SetActive(value: true);
			rewardSprite2.gameObject.SetActive(value: true);
			rewardOverlay1.gameObject.SetActive(value: true);
			rewardOverlay2.gameObject.SetActive(value: true);
			CrusedReward crusedReward = (CrusedReward)reward;
			rewardSprite1.sprite = crusedReward.GetBuffRewardSprite();
			rewardOverlay1.sprite = crusedReward.GetBuffRewardOverlaySprite();
			rewardOverlay1.gameObject.SetActive(rewardOverlay1.sprite != null);
			rewardSprite2.sprite = crusedReward.GetDebuffRewardSprite();
			rewardOverlay2.sprite = crusedReward.GetDebuffRewardOverlaySprite();
			rewardOverlay2.gameObject.SetActive(rewardOverlay2.sprite != null);
		}
		else
		{
			rewardOverlay.gameObject.SetActive(value: true);
			rewardSprite.gameObject.SetActive(value: true);
			rewardSprite.sprite = reward.GetRewardSprite();
			rewardOverlay.sprite = reward.GetRewardOverlaySprite();
			rewardOverlay.gameObject.SetActive(rewardOverlay.sprite != null);
		}
		rewardButtonImage.color = Singleton<RewardDataStore>.Instance.GetRarityColor(reward.rarity);
		rewardSelectButton.onClick.RemoveAllListeners();
		rewardSelectButton.onClick.AddListener(() =>
		{
			rewardSystemUIManager.HideUI();
		});
		rewardSelectButton.onClick.AddListener(() =>
		{
			reward.ActivateReward();
		});
		rewardSelectButton.onClick.AddListener(() =>
		{
			Singleton<InputDataStore>.Instance.SetGameplayActionMap();
		});
		rewardSelectButton.onClick.AddListener(() =>
		{
			SceneSingleton<PointerManager>.Instance.StartPointer();
		});
		rewardSelectButton.interactable = reward.IsRewardUnlocked();
		rewardLock.SetActive(!reward.IsRewardUnlocked());
		for (int num = 0; num < reward.GetRewardLevel(); num++)
		{
			if (num < starsList.Count)
			{
				starsList[num].SetActive(value: true);
			}
		}
	}

	public void SetNullPanel()
	{
		rewardSelectButton.interactable = false;
		GetComponent<EventTrigger>().enabled = false;
	}

	public void DisableButton()
	{
		rewardSelectButton.interactable = false;
	}

	public void PointerEnter()
	{
		if (reward.IsRewardUnlocked() && rewardSelectButton.interactable)
		{
			Singleton<CurserManager>.Instance.SetCurser(CurserTypes.Hand);
			if (reward is BlockReward)
			{
				BlockReward blockReward = (BlockReward)reward;
				SceneSingleton<PlayerCoresManager>.Instance.HighLightCores(blockReward.blockCore);
			}
		}
	}

	public void PointerExit()
	{
		if (rewardSelectButton.interactable)
		{
			Singleton<CurserManager>.Instance.SetCurser(CurserTypes.Normal);
			if (reward is BlockReward)
			{
				SceneSingleton<PlayerCoresManager>.Instance.DisableHighLightCores();
			}
		}
	}
}
