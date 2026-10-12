using UnityEngine;

public class RewardPackObjectController : RewardPackController
{
	[SerializeField]
	private SpriteRenderer packColor;

	[SerializeField]
	private SpriteRenderer packIcon;

	[Space]
	[SerializeField]
	private SpriteRenderer packColorMapIcon;

	[SerializeField]
	private SpriteRenderer packIconMapIcon;

	public override void SetRewardPack(RewardPack rewardPack, RarityTypes rarityType = RarityTypes.None)
	{
		base.SetRewardPack(rewardPack, rarityType);
		SpriteRenderer spriteRenderer = packColorMapIcon;
		Color color = (packColor.color = Singleton<RewardDataStore>.Instance.GetRarityColor(packRarityType));
		spriteRenderer.color = color;
		SpriteRenderer spriteRenderer2 = packIconMapIcon;
		Sprite sprite = (packIcon.sprite = rewardPack.packSprite);
		spriteRenderer2.sprite = sprite;
	}
}
