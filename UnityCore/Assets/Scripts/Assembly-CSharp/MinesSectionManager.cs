using System.Collections.Generic;
using UnityEngine;

public class MinesSectionManager : MonoBehaviour
{
	private Mine currentMine;

	private MinesTurretController minesTurretController;

	private DetectionType mineTargetDetectionType;

	private ChipsContainer chipsContainer;

	private List<MineController> minesList;

	private AudioManager audioManager;

	public int GetMinesCount()
	{
		return minesList.Count;
	}

	public void SetMinesSection(MinesTurretController minesTurretController, Mine currentMine, DetectionType mineTargetDetectionType, ChipsContainer chipsContainer)
	{
		audioManager = Singleton<AudioManager>.Instance;
		minesList = new List<MineController>();
		this.mineTargetDetectionType = mineTargetDetectionType;
		this.minesTurretController = minesTurretController;
		this.currentMine = currentMine;
		this.chipsContainer = chipsContainer;
	}

	public void UpdateMinesChipsContainer(ChipsContainer chipsContainer)
	{
		this.chipsContainer = chipsContainer;
		foreach (MineController mines in minesList)
		{
			mines.UpdateMineChipsContainer(chipsContainer);
		}
	}

	public void SpawnMine()
	{
		Vector2 vector = Random.insideUnitCircle * 0.4f;
		GameObject obj = MasterPool.Get(currentMine.minePrefab, base.transform);
		obj.transform.localPosition = vector;
		MineController component = obj.GetComponent<MineController>();
		component.SetMine(currentMine, mineTargetDetectionType, chipsContainer, MineDestroyed);
		minesList.Add(component);
		audioManager.PlaySFX(AudioClipTypes.Gun_Mine);
	}

	public void RemoveMines()
	{
		minesTurretController.MineDestroyed(minesList.Count);
		foreach (MineController mines in minesList)
		{
			mines.DisableMine();
		}
		Object.Destroy(base.gameObject);
	}

	public void MineDestroyed(MineController mineController)
	{
		minesList.Remove(mineController);
		minesTurretController.MineDestroyed();
	}
}
