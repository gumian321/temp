using UnityEngine;

public class ChipController : MonoBehaviour
{
	private SpriteRenderer chipBodySprite;

	private CoreController coreController;

	private ChipTypes chipType;

	private GameObject chipRange;

	private bool isDisabled;

	private void OnEnable()
	{
		chipBodySprite = GetComponent<SpriteRenderer>();
	}

	public void DisableChipArt()
	{
		chipBodySprite.sprite = null;
	}

	public void DisableCore()
	{
		isDisabled = true;
		SceneSingleton<PlayerBuildingManager>.Instance.RefershCores();
	}

	public void ActivateCore()
	{
		isDisabled = false;
		SceneSingleton<PlayerBuildingManager>.Instance.RefershCores();
	}

	public bool IsDisabled()
	{
		return isDisabled;
	}

	public void PreviewChip(Core core, bool showPreview = false)
	{
		chipBodySprite.sprite = core.GetCoreSprite();
		if (chipRange == null)
		{
			chipRange = MasterPool.CreateNew(PrefabTypes.Range_Chip, base.transform);
		}
		chipRange.SetActive(showPreview);
	}

	public void SetChipRangeState(bool state)
	{
		chipRange.SetActive(state);
	}

	public void BuildChip(CoreController coreController, Core core)
	{
		this.coreController = coreController;
		ChipCore chipCore = (ChipCore)core;
		chipBodySprite.sprite = chipCore.GetCoreSprite();
		chipType = chipCore.coreChip.chipType;
	}
}
