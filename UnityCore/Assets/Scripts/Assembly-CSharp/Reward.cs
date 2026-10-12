using UnityEngine;
using UnityEngine.Video;

public abstract class Reward : ScriptableObject
{
	[Space]
	[Header("Upgrade Tree Values")]
	public int rewardOverrideCost = -1;

	public string rewardDesc;

	[Space]
	[Header("Reward Stats")]
	public RewardStats rewardStats;

	[Space]
	public VideoClip rewardVideoClip;

	[Space]
	[Space]
	public RarityTypes rarity;

	public Sprite rewardOverlaySprite;

	[Space]
	[Header("In Game Values")]
	[SerializeField]
	private int rewardHeat;

	public Sprite GetRewardOverlaySprite()
	{
		return rewardOverlaySprite;
	}

	public void ActivateReward()
	{
		if (rewardHeat > 0)
		{
			SceneSingleton<GameHeatManager>.Instance.ChangeHeat(rewardHeat);
		}
		SelectReward();
		AddRewardPopUpText();
		Singleton<AudioManager>.Instance.PlaySFX(AudioClipTypes.RewardPack_LevelUp);
	}

	public abstract void SelectReward();

	public virtual bool CanSelectReward()
	{
		if (IsRewardUnlocked())
		{
			return IsRewardToggled();
		}
		return false;
	}

	public virtual bool CanConflictReward(Reward reward)
	{
		return false;
	}

	public virtual int GetRewardLevel()
	{
		return 0;
	}

	public abstract string GetRewardTitle();

	public abstract Sprite GetRewardSprite();

	public abstract void AddRewardPopUpText();

	public void UnlockReward()
	{
		SaveSystem.UnlockReward(base.name);
	}

	public void LockReward()
	{
		SaveSystem.LockReward(base.name);
	}

	public bool IsRewardUnlocked()
	{
		if (SaveSystem.IsRewardUnlocked(base.name))
		{
			return CheckRewardDemo();
		}
		return false;
	}

	public void UnToggleReward()
	{
		SaveSystem.UnToggleReward(base.name);
	}

	public void ToggleReward()
	{
		SaveSystem.ToggleReward(base.name);
	}

	public bool IsRewardToggled()
	{
		return SaveSystem.IsRewardToggled(base.name);
	}

	protected bool CheckRewardDemo()
	{
		if (Singleton<DemoBuildManager>.Instance != null && Singleton<DemoBuildManager>.Instance.IsDemoEnabled() && !Singleton<DemoBuildManager>.Instance.IsRewardAvilable(this))
		{
			return false;
		}
		return true;
	}
}
