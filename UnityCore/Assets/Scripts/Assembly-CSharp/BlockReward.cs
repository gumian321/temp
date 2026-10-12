using UnityEngine;

[CreateAssetMenu(fileName = "New Block Reward", menuName = "ScriptableObjects/Rewards/New Block Reward")]
public class BlockReward : Reward
{
	[Space]
	[Space]
	[Header("Block Reward Data")]
	public Core blockCore;

	public int coresCount = 1;

	public override int GetRewardLevel()
	{
		return Singleton<PlayerDataStore>.Instance.GetLevelUpRewardsCount(blockCore);
	}

	public override void SelectReward()
	{
		for (int i = 0; i < coresCount; i++)
		{
			SceneSingleton<PlayerBuildingManager>.Instance.SpawnShipPiece(blockCore);
		}
		Singleton<CurserManager>.Instance.SetCurser(CurserTypes.Hand, coresCount);
	}

	public override bool CanSelectReward()
	{
		if (SceneSingleton<PlayerCoresManager>.Instance.CanAddCore(coresCount))
		{
			return base.CanSelectReward();
		}
		return false;
	}

	public override bool CanConflictReward(Reward reward)
	{
		if (!(reward is BlockReward))
		{
			return false;
		}
		return ((BlockReward)reward).blockCore == blockCore;
	}

	public override string GetRewardTitle()
	{
		if (coresCount == 1)
		{
			return blockCore.GetCoreTitle();
		}
		return "x" + coresCount + " " + blockCore.GetCoreTitle();
	}

	public override Sprite GetRewardSprite()
	{
		return blockCore.GetCoreSprite();
	}

	public override void AddRewardPopUpText()
	{
	}
}
