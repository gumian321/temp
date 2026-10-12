using UnityEngine;

public class AIMapIconController : MonoBehaviour
{
	private SpriteRenderer spriteRenderer;

	public void SetUpAIMapIconController(AIFaction aIFaction, AIThreatLevel aIThreatLevel)
	{
		if (spriteRenderer == null)
		{
			spriteRenderer = MasterPool.CreateNew(PrefabTypes.MapIcon, base.transform).GetComponent<SpriteRenderer>();
		}
		spriteRenderer.sprite = Singleton<AIDataStore>.Instance.GetThreatLevelSprite(aIThreatLevel);
		spriteRenderer.color = Singleton<AIDataStore>.Instance.GetFactionColor(aIFaction);
	}

	public void SetUpAIMapIconController(Sprite sprite, Color color)
	{
		if (spriteRenderer == null)
		{
			spriteRenderer = MasterPool.CreateNew(PrefabTypes.MapIcon, base.transform).GetComponent<SpriteRenderer>();
		}
		spriteRenderer.sprite = sprite;
		spriteRenderer.color = color;
	}
}
