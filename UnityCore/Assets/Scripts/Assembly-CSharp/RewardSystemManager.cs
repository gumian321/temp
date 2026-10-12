using System.Collections.Generic;
using UnityEngine;

public class RewardSystemManager : SceneSingleton<RewardSystemManager>, IPickable
{
	private RewardSystemUIManager rewardSystemUIManager;

	private InputManager inputManager;

	private List<Transform> rewardPacksList = new List<Transform>();

	[SerializeField]
	private RadarConfiguration radarConfiguration;

	private bool isCollecting = true;

	private bool isGettingPickable;

	private Queue<RewardPackController> avilableRewardPacks = new Queue<RewardPackController>();

	public int GetAvilableRewardsCount()
	{
		return avilableRewardPacks.Count;
	}

	private void Start()
	{
		rewardSystemUIManager = Object.FindObjectOfType<RewardSystemUIManager>();
		avilableRewardPacks = new Queue<RewardPackController>();
		SceneSingleton<InGameEconomySystem>.Instance.OnLevelUp += OnLevelUp;
		inputManager = Singleton<InputManager>.Instance;
	}

	private void Update()
	{
		if (SceneSingleton<GameManager>.Instance.IsBuildingMode() && IsRewardAvilable() && CanShowNextReward())
		{
			ActivateNextRewardPack();
		}
	}

	private bool CanShowNextReward()
	{
		if (SceneSingleton<PlayerBuildingManager>.Instance.CanShowNextReward())
		{
			return !rewardSystemUIManager.IsPanelShown();
		}
		return false;
	}

	public void OnLevelUp()
	{
		RewardPack levelUpRewardPack = Singleton<RewardDataStore>.Instance.GetLevelUpRewardPack();
		RewardPackController rewardPackController = new RewardPackController();
		rewardPackController.SetRewardPack(levelUpRewardPack);
		AddRewardPackToUI(rewardPackController);
	}

	public bool CanEndBuildMode()
	{
		if (IsRewardShown())
		{
			return false;
		}
		if (IsRewardAvilable())
		{
			return false;
		}
		return true;
	}

	public bool IsRewardAvilable()
	{
		return GetAvilableRewardsCount() > 0;
	}

	public bool IsRewardShown()
	{
		return rewardSystemUIManager.IsPanelShown();
	}

	public void SpawnRewardPack(Vector2 pos, RewardPack rewardPack, RarityTypes packRarity = RarityTypes.None)
	{
		if (!rewardPack.CanSpawnRewardPack())
		{
			rewardPack = Singleton<RewardDataStore>.Instance.GetLevelUpRewardPack();
		}
		packRarity = ((packRarity != RarityTypes.None) ? rewardPack.CheckRarityTypeAvilablity(packRarity) : rewardPack.GetRandomRarityType());
		Transform transform = MasterPool.Get(PrefabTypes.Object_RewardPack).transform;
		transform.GetComponent<RewardPackController>().SetRewardPack(rewardPack, packRarity);
		TweenController.ScatterItem(pos, transform, (Transform pack) =>
		{
			rewardPacksList.Add(pack);
		});
	}

	public void SetCollectingState(bool flag)
	{
		isCollecting = flag;
	}

	public Transform GetPickable(Vector2 pos, float range)
	{
		if (!isCollecting)
		{
			return null;
		}
		if (isGettingPickable)
		{
			return null;
		}
		isGettingPickable = true;
		Transform target = radarConfiguration.GetTarget(rewardPacksList, pos, range);
		rewardPacksList.Remove(target);
		isGettingPickable = false;
		return target;
	}

	public void ReturnPickable(Transform pickable)
	{
		ObjectSystem.ReScale(pickable, 1f);
		rewardPacksList.Add(pickable);
		MasterPool.ReturnToPoolTransform(pickable.gameObject, PrefabTypes.Object_RewardPack, setActive: true);
	}

	public void CollectPickable(Transform pickable)
	{
		AddRewardPackToUI(pickable.GetComponent<RewardPackController>());
		MasterPool.ReturnToPoolTransform(pickable.gameObject, PrefabTypes.Object_RewardPack);
	}

	public void AddRewardPackToUI(RewardPackController rewardPackController)
	{
		SceneSingleton<TutorialMenuController>.Instance.ShowBuildTutorial();
		avilableRewardPacks.Enqueue(rewardPackController);
		rewardSystemUIManager.AddRewardPack(rewardPackController);
		Singleton<AudioManager>.Instance.PlaySFX(AudioClipTypes.RewardPack_PickUp);
		if (IsQueueFull())
		{
			SceneSingleton<GameManager>.Instance.OpenBuildMode();
		}
	}

	public void ActivateNextRewardPack()
	{
		Singleton<InputDataStore>.Instance.SetUIActionMap();
		SceneSingleton<PointerManager>.Instance.DisablePointer();
		Singleton<GameAchievementsManager>.Instance?.Add_PacksOpened();
		SceneSingleton<RatingSystemManager>.Instance.AddRating(RatingTypes.PacksOpened);
		Singleton<CurserManager>.Instance.SetCurser(CurserTypes.Normal);
		RewardPackController rewardPackController = avilableRewardPacks.Dequeue();
		if (!rewardPackController.GetRewardPack().CanSelectRewardPack())
		{
			RewardPack levelUpRewardPack = Singleton<RewardDataStore>.Instance.GetLevelUpRewardPack();
			rewardPackController = new RewardPackController();
			rewardPackController.SetRewardPack(levelUpRewardPack);
		}
		rewardSystemUIManager.ActivateNextRewardPack(rewardPackController.GetRandomRewardList());
	}

	private bool IsQueueFull()
	{
		return avilableRewardPacks.Count >= RewardDataStore.PacksInventoryCount;
	}

	public void RecyclePack()
	{
		rewardSystemUIManager.HideUI();
		float num = (float)SceneSingleton<InGameEconomySystem>.Instance.GetCurrentPackCost() * Singleton<RewardDataStore>.Instance.GetScrapsRecyclePercent();
		if (num < 1f)
		{
			num = 1f;
		}
		MasterPool.Get(PrefabTypes.Object_ScrapPack).GetComponent<RewardScrapPackController>().StartRewardPack(Mathf.RoundToInt(num));
	}
}
