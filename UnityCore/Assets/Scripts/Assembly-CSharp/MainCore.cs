using UnityEngine;

[CreateAssetMenu(fileName = "New Main Core", menuName = "ScriptableObjects/New Core/Main Core")]
public class MainCore : Core
{
	public override void SpawnCoreObject(CoreController coreController)
	{
		TurretCore mainTurretCore = Singleton<PlayerDataStore>.Instance.GetMainTurretCore();
		coreController.SetCoreObject(Object.Instantiate(mainTurretCore.coreTurret.turretObject, coreController.transform));
	}

	public override void PreviewCore(CoreController coreController, bool showPreview = false)
	{
	}

	public override void BuildCore(CoreController coreController)
	{
		SceneSingleton<PlayerCoresManager>.Instance.SetMainCoreController(coreController);
		SceneSingleton<PlayerManager>.Instance.SetUpMainCore(coreController);
	}

	public override void DisableCoreArt(CoreController coreController)
	{
	}

	public override void StunCore(CoreController coreController, bool isStunned)
	{
		if (isStunned)
		{
			SceneSingleton<PlayerTurretManager>.Instance.DisableTurret();
			SceneSingleton<PlayerDronesManager>.Instance.DisableDrones();
		}
		else
		{
			SceneSingleton<PlayerTurretManager>.Instance.ActivateTurret();
			SceneSingleton<PlayerDronesManager>.Instance.ActivateDrones();
		}
	}

	public override void DisableCore(CoreController coreController)
	{
		SceneSingleton<PlayerTurretManager>.Instance.DisableTurret();
		SceneSingleton<PlayerDronesManager>.Instance.DisableDrones();
	}

	public override void ActivateCore(CoreController coreController)
	{
		SceneSingleton<PlayerTurretManager>.Instance.ActivateTurret();
		SceneSingleton<PlayerDronesManager>.Instance.ActivateDrones();
	}

	public override void DestroyCore(CoreController coreController)
	{
		base.DestroyCore(coreController);
		Singleton<PlayerDecorationManager>.Instance.RemoveAll();
		SceneSingleton<PlayerCoresManager>.Instance.DestroyAllCores();
		ParticlesSystem.PlayExplosionParticle(coreController.transform.position, 10f);
		SceneSingleton<GameManager>.Instance.EndGame(isPlayerWon: false);
	}

	public override Sprite GetCoreSprite()
	{
		return null;
	}
}
